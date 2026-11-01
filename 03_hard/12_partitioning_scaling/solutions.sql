-- =============================================================================
-- 03_hard/12 · Partitioning, Materialized Views & Scaling — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;


-- Q1. The PK must contain the partition key (paid_at).
CREATE TABLE lab.payments_part (
    payment_id INT           NOT NULL,
    order_id   INT           NOT NULL,
    amount     NUMERIC(10,2) NOT NULL,
    method     VARCHAR(20)   NOT NULL,
    paid_at    TIMESTAMP     NOT NULL,
    PRIMARY KEY (payment_id, paid_at)
) PARTITION BY RANGE (paid_at);

CREATE TABLE lab.payments_2023    PARTITION OF lab.payments_part FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE lab.payments_2024    PARTITION OF lab.payments_part FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE lab.payments_2025    PARTITION OF lab.payments_part FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE lab.payments_default PARTITION OF lab.payments_part DEFAULT;

INSERT INTO lab.payments_part (payment_id, order_id, amount, method, paid_at)
SELECT payment_id, order_id, amount, method, paid_at FROM payments;

-- LEFT JOIN from the catalog so the empty DEFAULT partition shows 0.
SELECT c.relname AS partition, COUNT(p.payment_id) AS rows, COALESCE(SUM(p.amount), 0) AS total
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
LEFT JOIN lab.payments_part p ON p.tableoid = c.oid
WHERE i.inhparent = 'lab.payments_part'::regclass
GROUP BY c.relname
ORDER BY c.relname;


-- Q2.
EXPLAIN SELECT SUM(amount) FROM lab.payments_part
WHERE paid_at >= '2024-01-01' AND paid_at < '2025-01-01';     -- only payments_2024

EXPLAIN SELECT COUNT(*) FROM lab.payments_part WHERE amount > 1000;   -- Append over all 4 partitions


-- Q3. DETACH is a metadata operation: instant regardless of size.
ALTER TABLE lab.payments_part DETACH PARTITION lab.payments_2023;
ALTER TABLE lab.payments_2023 RENAME TO payments_archive_2023;

SELECT (SELECT COUNT(*) FROM lab.payments_part)          AS live_rows,      -- 24
       (SELECT COUNT(*) FROM lab.payments_archive_2023)  AS archived_rows;  -- 19


-- Q4. No 2026 partition yet -> the row goes to DEFAULT.
INSERT INTO lab.payments_part VALUES (1000, 44, 143.97, 'cash', '2026-01-15');
SELECT tableoid::regclass AS landed_in FROM lab.payments_part WHERE payment_id = 1000;   -- payments_default

-- CREATE TABLE lab.payments_2026 PARTITION OF lab.payments_part
--     FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
--   ERROR: updated partition constraint for default partition "payments_default"
--          would be violated by some row
-- The DEFAULT partition may not contain rows that belong to the new range.
-- Fix: move those rows out, create the partition, move them back (one transaction).
BEGIN;
CREATE TEMP TABLE moving AS
    SELECT * FROM lab.payments_default WHERE paid_at >= '2026-01-01' AND paid_at < '2027-01-01';
DELETE FROM lab.payments_default WHERE paid_at >= '2026-01-01' AND paid_at < '2027-01-01';
CREATE TABLE lab.payments_2026 PARTITION OF lab.payments_part
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
INSERT INTO lab.payments_part SELECT * FROM moving;             -- routed to payments_2026
COMMIT;
SELECT tableoid::regclass AS now_in FROM lab.payments_part WHERE payment_id = 1000;      -- payments_2026
-- Lesson: create future partitions AHEAD of time (scheduled job / pg_partman).


-- Q5.
CREATE MATERIALIZED VIEW lab.mv_monthly_revenue AS
SELECT DATE_TRUNC('month', o.order_date)::date                     AS month,
       COUNT(DISTINCT o.order_id)                                  AS orders,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY 1;
CREATE UNIQUE INDEX ON lab.mv_monthly_revenue (month);

SELECT * FROM lab.mv_monthly_revenue ORDER BY revenue DESC LIMIT 3;


-- Q6.
BEGIN;
INSERT INTO orders (order_id, customer_id, order_date, status) VALUES (901, 18, '2025-10-31 12:00', 'pending');
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (901, 3, 2, 2200);

SELECT * FROM lab.mv_monthly_revenue WHERE month = '2025-10-01';   -- 3 orders, 2403.95 (stale)
REFRESH MATERIALIZED VIEW CONCURRENTLY lab.mv_monthly_revenue;
SELECT * FROM lab.mv_monthly_revenue WHERE month = '2025-10-01';   -- 4 orders, 6803.95
ROLLBACK;


-- Q7. One reasonable design:
--  * PARTITION BY RANGE (event_time) with DAILY partitions (50M rows/day ->
--    each partition is a manageable unit; queries "by day" prune to 1–7
--    partitions). Pre-create partitions days ahead with pg_partman / a cron job.
--  * Indexes per partition: BRIN on event_time (tiny, data arrives in time
--    order) and a B-tree on user_id (or (user_id, event_time)) for user lookups.
--  * Retention: a daily job DETACHes and DROPs (or exports to Parquet in object
--    storage, then drops) partitions older than 90 days — no DELETE, no bloat.
--  * Bulk ingestion with COPY (or batched multi-row INSERTs) into the parent.
--  * Heavy analytics: replicate/stream (logical replication / CDC) into a
--    columnar warehouse (Snowflake/BigQuery/ClickHouse/DuckDB on Parquet) and
--    keep pre-aggregated daily tables or materialized views for dashboards;
--    point BI tools at a read replica or the warehouse, not the primary.

DROP SCHEMA lab CASCADE;
