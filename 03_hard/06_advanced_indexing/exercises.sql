-- =============================================================================
-- 03_hard/06 · Advanced Indexing — EXERCISES
-- Uses: index types + EXPLAIN (05) + JSON operators + constraints (easy/04)
--       + window functions (01) + DML (medium/08)
-- Work in schema "lab"; drop it at the end.
-- =============================================================================


-- Q1. Setup: lab.jobs (400,000 rows): job_id identity PK, queue
--     ('emails','reports','billing'), state ('done' 95%, 'queued' 4%,
--     'failed' 1%), run_after timestamp increasing with job_id (one per minute
--     from 2024-01-01), payload JSONB {"customer_id": n, "priority": "high"/"low"},
--     worker_note TEXT like 'retry after timeout' / 'ok' / 'smtp error 550'.
--     ANALYZE it.



-- Q2. Workers poll:  SELECT job_id FROM lab.jobs
--                    WHERE state = 'queued' AND queue = 'emails'
--                    ORDER BY run_after LIMIT 10;
--     Create the smallest index that serves this query with no Sort node.
--     Compare its size with a full (queue, state, run_after) index.
--     Expected: a partial index … WHERE state = 'queued' — a few hundred kB vs MBs



-- Q3. Rule: a customer may have at most ONE 'queued' billing job at a time.
--     Enforce it with an index (find and fix existing violations first!).
--     Hint: payload ->> 'customer_id'.



-- Q4. Support searches notes with  worker_note ILIKE '%smtp%'. Show the plan
--     before and after adding a trigram GIN index.



-- Q5. Analytics filters on payload @> '{"priority": "high"}'. Add a suitable
--     GIN index and show it's used. Then explain why a query using
--     payload ->> 'priority' = 'high' does NOT use it, and add the index that would.



-- Q6. Compare a BRIN and a B-tree index on run_after: sizes, and the plan for
--     one day of jobs. When would BRIN become useless? (Demonstrate by
--     creating a copy of the table with rows in random physical order.)



-- Q7. Covering index: the dashboard runs
--       SELECT queue, state FROM lab.jobs WHERE job_id BETWEEN 1000 AND 2000;
--     Make it an Index Only Scan without adding a new index on job_id
--     (hint: the PK index can't INCLUDE columns after the fact — create a new
--     unique index with INCLUDE). Check with EXPLAIN after VACUUM.
--     Drop the schema at the end.
