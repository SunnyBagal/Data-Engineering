-- =============================================================================
-- 03_hard/06 · Advanced Indexing — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT setseed(0.12);


-- Q1.
CREATE TABLE lab.jobs (
    job_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    queue       TEXT      NOT NULL,
    state       TEXT      NOT NULL,
    run_after   TIMESTAMP NOT NULL,
    payload     JSONB     NOT NULL,
    worker_note TEXT
);

INSERT INTO lab.jobs (queue, state, run_after, payload, worker_note)
SELECT (ARRAY['emails','reports','billing'])[1 + (g % 3)],
       CASE WHEN r < 0.95 THEN 'done' WHEN r < 0.99 THEN 'queued' ELSE 'failed' END,
       TIMESTAMP '2024-01-01' + g * INTERVAL '1 minute',
       jsonb_build_object('customer_id', 1 + (g % 5000),
                          'priority', CASE WHEN random() < 0.2 THEN 'high' ELSE 'low' END),
       (ARRAY['ok','ok','ok','retry after timeout','smtp error 550'])[1 + (random() * 4)::int]
FROM (SELECT g, random() AS r FROM generate_series(1, 400000) g) s;

ANALYZE lab.jobs;


-- Q2. Partial index: only queued rows (~4%) are indexed; (queue, run_after)
--     gives equality then order -> rows come out sorted, LIMIT stops early.
CREATE INDEX idx_jobs_queued ON lab.jobs (queue, run_after) WHERE state = 'queued';

EXPLAIN
SELECT job_id FROM lab.jobs
WHERE state = 'queued' AND queue = 'emails'
ORDER BY run_after
LIMIT 10;                                    -- Limit -> Index Scan using idx_jobs_queued

CREATE INDEX idx_jobs_full ON lab.jobs (queue, state, run_after);
SELECT indexrelid::regclass AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_index
WHERE indexrelid IN ('lab.idx_jobs_queued'::regclass, 'lab.idx_jobs_full'::regclass);
DROP INDEX lab.idx_jobs_full;


-- Q3. Find violations first: a unique index can't be built while duplicates exist.
SELECT payload ->> 'customer_id' AS customer_id, COUNT(*) AS queued_billing_jobs
FROM lab.jobs
WHERE state = 'queued' AND queue = 'billing'
GROUP BY 1
HAVING COUNT(*) > 1;

-- Fix: keep the earliest queued job per customer, mark the others 'failed'
-- (window function picks the survivors).
UPDATE lab.jobs j
SET state = 'failed'
FROM (SELECT job_id,
             ROW_NUMBER() OVER (PARTITION BY payload ->> 'customer_id' ORDER BY run_after) AS rn
      FROM lab.jobs
      WHERE state = 'queued' AND queue = 'billing') d
WHERE d.job_id = j.job_id AND d.rn > 1;

-- Partial UNIQUE expression index = the business rule, enforced forever.
CREATE UNIQUE INDEX uq_one_queued_billing_per_customer
    ON lab.jobs ((payload ->> 'customer_id'))
    WHERE state = 'queued' AND queue = 'billing';


-- Q4. B-tree can't do leading-wildcard searches -> Seq Scan. Trigram GIN can.
EXPLAIN SELECT COUNT(*) FROM lab.jobs WHERE worker_note ILIKE '%smtp%';     -- Seq Scan
CREATE INDEX idx_jobs_note_trgm ON lab.jobs USING gin (worker_note gin_trgm_ops);
ANALYZE lab.jobs;
EXPLAIN SELECT COUNT(*) FROM lab.jobs WHERE worker_note ILIKE '%smtp%';     -- Bitmap Index Scan (trgm)
-- (For a value matching a large share of rows the planner may still prefer a
--  Seq Scan — the index pays off most for selective search terms.)


-- Q5. GIN (jsonb_path_ops) supports containment @>.
CREATE INDEX idx_jobs_payload_gin ON lab.jobs USING gin (payload jsonb_path_ops);
EXPLAIN SELECT COUNT(*) FROM lab.jobs WHERE payload @> '{"priority": "high"}';   -- Bitmap Index Scan

-- ->> extracts text and compares with = : that's a B-tree-style predicate on an
-- expression; GIN doesn't support it. An expression B-tree does:
EXPLAIN SELECT COUNT(*) FROM lab.jobs WHERE payload ->> 'priority' = 'high';     -- not the GIN index
CREATE INDEX idx_jobs_priority ON lab.jobs ((payload ->> 'priority'));
ANALYZE lab.jobs;
EXPLAIN SELECT COUNT(*) FROM lab.jobs WHERE payload ->> 'priority' = 'high';     -- uses idx_jobs_priority (or seq scan if not selective)


-- Q6.
CREATE INDEX idx_jobs_run_brin  ON lab.jobs USING brin (run_after);
CREATE INDEX idx_jobs_run_btree ON lab.jobs (run_after);
SELECT indexrelid::regclass AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_index
WHERE indexrelid IN ('lab.idx_jobs_run_brin'::regclass, 'lab.idx_jobs_run_btree'::regclass);

DROP INDEX lab.idx_jobs_run_btree;
EXPLAIN ANALYZE SELECT COUNT(*) FROM lab.jobs
WHERE run_after >= '2024-03-01' AND run_after < '2024-03-02';   -- Bitmap Index Scan on BRIN, few blocks

-- Random physical order: every block range now spans the whole year, so the
-- min/max summaries exclude nothing and BRIN must read (almost) every block.
CREATE TABLE lab.jobs_shuffled AS SELECT * FROM lab.jobs ORDER BY random();
CREATE INDEX idx_shuffled_brin ON lab.jobs_shuffled USING brin (run_after);
ANALYZE lab.jobs_shuffled;
EXPLAIN ANALYZE SELECT COUNT(*) FROM lab.jobs_shuffled
WHERE run_after >= '2024-03-01' AND run_after < '2024-03-02';
-- Look at "Heap Blocks: lossy=…" / "Rows Removed by Index Recheck": huge -> BRIN is useless here
-- (the planner usually just picks a Seq Scan instead).


-- Q7. A second UNIQUE index on job_id that carries the needed columns.
CREATE UNIQUE INDEX idx_jobs_id_cover ON lab.jobs (job_id) INCLUDE (queue, state);
VACUUM ANALYZE lab.jobs;
EXPLAIN SELECT queue, state FROM lab.jobs WHERE job_id BETWEEN 1000 AND 2000;
-- Index Only Scan using idx_jobs_id_cover. (Trade-off: one more index to
-- maintain on every write — worth it only for hot queries.)

DROP SCHEMA lab CASCADE;
