-- =============================================================================
-- 03_hard/05 · Query Execution & EXPLAIN — LESSON
-- Builds larger tables in a "sandbox" schema (a few seconds). Exact costs and
-- timings differ per machine; focus on node types and estimated vs actual rows.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;
SELECT setseed(0.5);


-- -----------------------------------------------------------------------------
-- 0. Test data: 50k customers, 400k orders
-- -----------------------------------------------------------------------------

CREATE TABLE big_customers AS
SELECT g AS customer_id,
       (ARRAY['India','USA','UK','Germany','Canada'])[1 + (random() * 4)::int] AS country,
       DATE '2020-01-01' + (random() * 2000)::int AS signup_date
FROM generate_series(1, 50000) g;
ALTER TABLE big_customers ADD PRIMARY KEY (customer_id);

CREATE TABLE big_orders AS
SELECT g AS order_id,
       1 + (random() * 49999)::int                       AS customer_id,
       TIMESTAMP '2023-01-01' + random() * INTERVAL '1000 days' AS order_date,
       round((random() * 1000)::numeric, 2)               AS amount,
       (ARRAY['delivered','delivered','delivered','shipped','cancelled'])[1 + (random() * 4)::int] AS status
FROM generate_series(1, 400000) g;
ALTER TABLE big_orders ADD PRIMARY KEY (order_id);
-- NOTE: deliberately NO index on big_orders.customer_id yet.

ANALYZE big_customers;
ANALYZE big_orders;


-- -----------------------------------------------------------------------------
-- 1. EXPLAIN vs EXPLAIN ANALYZE
-- -----------------------------------------------------------------------------

-- Estimates only (the query is NOT executed).
EXPLAIN
SELECT * FROM big_orders WHERE order_id = 12345;      -- Index Scan using big_orders_pkey

-- Executes and reports actual time/rows. BUFFERS shows pages touched:
-- "shared hit" = found in memory, "read" = fetched from disk/OS cache.
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM big_orders WHERE order_id = 12345;


-- -----------------------------------------------------------------------------
-- 2. Reading a plan tree (bottom-up)
-- -----------------------------------------------------------------------------

-- Orders per country for one month. Read from the innermost nodes:
--   Seq Scan(s) -> Hash -> Hash Join -> HashAggregate -> Sort
EXPLAIN ANALYZE
SELECT c.country, COUNT(*) AS orders, SUM(o.amount) AS revenue
FROM big_orders o
JOIN big_customers c ON c.customer_id = o.customer_id
WHERE o.order_date >= '2024-03-01' AND o.order_date < '2024-04-01'
GROUP BY c.country
ORDER BY revenue DESC;


-- -----------------------------------------------------------------------------
-- 3. Missing index on a join/filter column
-- -----------------------------------------------------------------------------

-- All orders of ONE customer: without an index on customer_id this is a
-- (parallel) Seq Scan over 400k rows to find ~8.
EXPLAIN ANALYZE
SELECT * FROM big_orders WHERE customer_id = 777;

CREATE INDEX idx_big_orders_customer ON big_orders (customer_id);

-- Now: Bitmap/Index Scan — orders of magnitude less work.
EXPLAIN ANALYZE
SELECT * FROM big_orders WHERE customer_id = 777;

-- With the index, joining a FEW customers to their orders becomes a
-- Nested Loop: for each outer row, an index lookup on the inner table.
EXPLAIN ANALYZE
SELECT c.customer_id, o.order_id, o.amount
FROM big_customers c
JOIN big_orders o ON o.customer_id = c.customer_id
WHERE c.customer_id BETWEEN 100 AND 105;


-- -----------------------------------------------------------------------------
-- 4. The three join algorithms (forcing them is for LEARNING only)
-- -----------------------------------------------------------------------------

-- Natural choice for joining large inputs on equality: Hash Join.
EXPLAIN
SELECT COUNT(*) FROM big_orders o JOIN big_customers c ON c.customer_id = o.customer_id;

-- Disable hash joins to see the planner's next-best option (Merge Join:
-- both sides sorted / read in key order) and its higher cost.
SET enable_hashjoin = off;
EXPLAIN
SELECT COUNT(*) FROM big_orders o JOIN big_customers c ON c.customer_id = o.customer_id;

-- And without merge joins too -> Nested Loop with index lookups.
SET enable_mergejoin = off;
EXPLAIN
SELECT COUNT(*) FROM big_orders o JOIN big_customers c ON c.customer_id = o.customer_id;

RESET enable_hashjoin;
RESET enable_mergejoin;


-- -----------------------------------------------------------------------------
-- 5. Bad estimates: stale statistics
-- -----------------------------------------------------------------------------

-- Add 100k new 'refunded' rows. Autovacuum hasn't analyzed them yet, so the
-- planner believes 'refunded' doesn't exist (estimate rows=1 or tiny).
INSERT INTO big_orders (order_id, customer_id, order_date, amount, status)
SELECT 400000 + g, 1 + (g % 50000), TIMESTAMP '2025-10-01', 10, 'refunded'
FROM generate_series(1, 100000) g;

EXPLAIN ANALYZE
SELECT COUNT(*) FROM big_orders WHERE status = 'refunded';
-- Compare "rows=" (estimate) with "actual ... rows=" (100000): way off.

ANALYZE big_orders;                     -- refresh statistics

EXPLAIN ANALYZE
SELECT COUNT(*) FROM big_orders WHERE status = 'refunded';   -- estimate now close to reality

-- What the planner knows about a column:
SELECT attname, n_distinct, most_common_vals, most_common_freqs
FROM pg_stats
WHERE schemaname = 'sandbox' AND tablename = 'big_orders' AND attname = 'status';


-- -----------------------------------------------------------------------------
-- 6. Sorts that spill to disk: work_mem
-- -----------------------------------------------------------------------------

-- With a tiny work_mem the sort can't fit in memory:
-- look for "Sort Method: external merge  Disk: ...kB".
SET work_mem = '64kB';
EXPLAIN ANALYZE
SELECT * FROM big_orders ORDER BY amount DESC LIMIT 100000;

-- More memory -> "Sort Method: quicksort / top-N heapsort  Memory: ...kB"
-- (in memory, no Disk: line, faster).
-- work_mem is PER sort/hash operation per query — set it carefully on servers.
SET work_mem = '64MB';
EXPLAIN ANALYZE
SELECT * FROM big_orders ORDER BY amount DESC LIMIT 100000;
RESET work_mem;

-- Top-N heapsort: with a small LIMIT, Postgres keeps only the best N rows in memory.
EXPLAIN ANALYZE
SELECT * FROM big_orders ORDER BY amount DESC LIMIT 10;      -- "top-N heapsort"


-- -----------------------------------------------------------------------------
-- 7. Rewrites that change the plan
-- -----------------------------------------------------------------------------

-- 7a. Correlated subquery in SELECT -> a SubPlan executed once per row.
EXPLAIN ANALYZE
SELECT c.customer_id,
       (SELECT COUNT(*) FROM big_orders o WHERE o.customer_id = c.customer_id) AS orders
FROM big_customers c
WHERE c.country = 'Germany';

-- Same result with a join + GROUP BY: one set-based pass (Hash Join + aggregate).
EXPLAIN ANALYZE
SELECT c.customer_id, COUNT(o.order_id) AS orders
FROM big_customers c
LEFT JOIN big_orders o ON o.customer_id = c.customer_id
WHERE c.country = 'Germany'
GROUP BY c.customer_id;

-- 7b. Non-sargable predicate vs sargable rewrite (index on order_date).
CREATE INDEX idx_big_orders_date ON big_orders (order_date);

EXPLAIN SELECT COUNT(*) FROM big_orders
WHERE EXTRACT(YEAR FROM order_date) = 2024 AND EXTRACT(MONTH FROM order_date) = 3;   -- Seq Scan

EXPLAIN SELECT COUNT(*) FROM big_orders
WHERE order_date >= '2024-03-01' AND order_date < '2024-04-01';                   -- index range scan

-- 7c. Anti-join: NOT EXISTS gets a "Hash Anti Join"; NOT IN with a nullable
-- subquery cannot be turned into an anti join (and has the NULL trap).
EXPLAIN SELECT COUNT(*) FROM big_customers c
WHERE NOT EXISTS (SELECT 1 FROM big_orders o WHERE o.customer_id = c.customer_id);


-- -----------------------------------------------------------------------------
-- 8. EXPLAIN on data-modifying statements: always inside a transaction
-- -----------------------------------------------------------------------------

BEGIN;
EXPLAIN ANALYZE
DELETE FROM big_orders WHERE status = 'refunded';   -- ANALYZE really deletes...
ROLLBACK;                                           -- ...so roll it back


-- -----------------------------------------------------------------------------
-- Clean up
-- -----------------------------------------------------------------------------
RESET search_path;
DROP SCHEMA sandbox CASCADE;
