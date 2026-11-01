-- =============================================================================
-- 03_hard/05 · Query Execution & EXPLAIN — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;
SELECT setseed(0.33);


-- Q1.
CREATE TABLE lab.accounts AS
SELECT g AS account_id,
       (ARRAY['north','south','east','west','central'])[1 + (random() * 4)::int] AS region,
       DATE '2018-01-01' + (random() * 2500)::int AS created_on
FROM generate_series(1, 30000) g;
ALTER TABLE lab.accounts ADD PRIMARY KEY (account_id);

CREATE TABLE lab.txns AS
SELECT g AS txn_id,
       1 + (random() * 29999)::int                                AS account_id,
       TIMESTAMP '2025-01-01' + random() * INTERVAL '365 days'    AS txn_time,
       round((random() * 1000 - 500)::numeric, 2)                 AS amount,
       (ARRAY['card','card','transfer','fee'])[1 + (random() * 3)::int] AS kind
FROM generate_series(1, 600000) g;
ALTER TABLE lab.txns ADD PRIMARY KEY (txn_id);

ANALYZE lab.accounts;
ANALYZE lab.txns;


-- Q2. Before: Parallel Seq Scan reading all 600k rows ("Rows Removed by Filter").
EXPLAIN ANALYZE SELECT * FROM lab.txns WHERE account_id = 4242;

CREATE INDEX idx_txns_account ON lab.txns (account_id);

-- After: Bitmap Index Scan + Bitmap Heap Scan; estimate ≈ actual ≈ 20 rows;
-- execution time drops from tens of ms to well under 1 ms.
EXPLAIN ANALYZE SELECT * FROM lab.txns WHERE account_id = 4242;


-- Q3. Full join: every txn needs its account. Hashing the 30k accounts once and
--     probing with 600k txns is far cheaper than 600k index lookups -> Hash Join.
EXPLAIN
SELECT a.region, SUM(t.amount)
FROM lab.txns t JOIN lab.accounts a ON a.account_id = t.account_id
GROUP BY a.region;

-- 10 accounts: the outer side is tiny, and idx_txns_account makes each inner
-- lookup cheap -> Nested Loop (10 index probes beat hashing 600k rows).
EXPLAIN
SELECT a.region, SUM(t.amount)
FROM lab.accounts a JOIN lab.txns t ON t.account_id = a.account_id
WHERE a.account_id BETWEEN 1 AND 10
GROUP BY a.region;


-- Q4.
INSERT INTO lab.txns (txn_id, account_id, txn_time, amount, kind)
SELECT 600000 + g, 1 + (g % 30000), TIMESTAMP '2025-12-31', -5, 'refund'
FROM generate_series(1, 150000) g;

-- Stale stats: 'refund' isn't in the most-common-values list -> estimate tiny
-- (e.g. rows=1) vs actual 150000.
EXPLAIN ANALYZE SELECT COUNT(*) FROM lab.txns WHERE kind = 'refund';

ANALYZE lab.txns;

-- Fresh stats: estimate ≈ 150000. On real queries, such misestimates lead to
-- wrong join algorithms (e.g. a nested loop over 150k "1" rows).
EXPLAIN ANALYZE SELECT COUNT(*) FROM lab.txns WHERE kind = 'refund';


-- Q5. Original: "SubPlan" under the Seq Scan of accounts, executed once per
--     north account (~3,750 loops), each an index scan + aggregate.
EXPLAIN ANALYZE
SELECT a.account_id,
       (SELECT MAX(t.txn_time) FROM lab.txns t WHERE t.account_id = a.account_id) AS last_txn
FROM lab.accounts a WHERE a.region = 'north';

-- (a) Set-based rewrite: one Hash Join + HashAggregate, no SubPlan.
--     Measure, don't assume! Here it scans ALL 750k txns to serve ~3.8k
--     accounts, so it is NOT faster than the SubPlan (which already uses
--     idx_txns_account per row). Set-based wins when most rows are needed or
--     no index exists; for "a few rows per outer row" an index probe wins.
EXPLAIN ANALYZE
SELECT a.account_id, MAX(t.txn_time) AS last_txn
FROM lab.accounts a
LEFT JOIN lab.txns t ON t.account_id = a.account_id
WHERE a.region = 'north'
GROUP BY a.account_id;

-- (b) Composite index: each SubPlan becomes a single backward index probe
--     ("Index Only Scan Backward" + Limit / "InitPlan" for MAX), so even the
--     per-row version is fast.
CREATE INDEX idx_txns_account_time ON lab.txns (account_id, txn_time);
VACUUM ANALYZE lab.txns;                    -- visibility map for index-only scans
EXPLAIN ANALYZE
SELECT a.account_id,
       (SELECT MAX(t.txn_time) FROM lab.txns t WHERE t.account_id = a.account_id) AS last_txn
FROM lab.accounts a WHERE a.region = 'north';


-- Q6. txn_time::date wraps the column in a cast, so no index on txn_time can be
--     used -> Seq Scan + Filter. Index the bare column and use a range.
CREATE INDEX idx_txns_time ON lab.txns (txn_time);

EXPLAIN SELECT COUNT(*) FROM lab.txns WHERE txn_time::date = '2025-06-15';          -- Seq Scan
EXPLAIN SELECT COUNT(*) FROM lab.txns
WHERE txn_time >= '2025-06-15' AND txn_time < '2025-06-16';                          -- index scan
-- Alternative: an expression index ON lab.txns ((txn_time::date)) (03_hard/06).


-- Q7.
SET work_mem = '64kB';
EXPLAIN ANALYZE SELECT * FROM lab.txns ORDER BY amount;      -- external merge  Disk: …
SET work_mem = '256MB';
EXPLAIN ANALYZE SELECT * FROM lab.txns ORDER BY amount;      -- quicksort  Memory: …
RESET work_mem;

-- An index on amount returns rows already ordered; scanning it backwards and
-- stopping after 20 rows needs no Sort node at all.
CREATE INDEX idx_txns_amount ON lab.txns (amount);
EXPLAIN SELECT * FROM lab.txns ORDER BY amount DESC LIMIT 20;   -- Limit -> Index Scan Backward

DROP SCHEMA lab CASCADE;
