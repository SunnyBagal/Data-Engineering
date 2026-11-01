-- =============================================================================
-- 03_hard/12 · Partitioning, Materialized Views & Scaling — LESSON
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;
SELECT setseed(0.21);


-- -----------------------------------------------------------------------------
-- 1. RANGE partitioning by month
-- -----------------------------------------------------------------------------

-- The parent holds no data itself; it defines columns and the partition key.
-- The PRIMARY KEY must include the partition key (uniqueness is enforced per partition).
CREATE TABLE page_events (
    event_id    BIGINT    NOT NULL,
    user_id     INT       NOT NULL,
    event_type  TEXT      NOT NULL,
    created_at  TIMESTAMP NOT NULL,
    PRIMARY KEY (event_id, created_at)
) PARTITION BY RANGE (created_at);

-- One partition per month of 2025: FROM is inclusive, TO is exclusive.
-- Generated with a DO block instead of 12 hand-written statements.
DO $$
DECLARE m DATE;
BEGIN
    FOR m IN SELECT generate_series(DATE '2025-01-01', DATE '2025-12-01', INTERVAL '1 month')::date LOOP
        EXECUTE format('CREATE TABLE %I PARTITION OF page_events FOR VALUES FROM (%L) TO (%L)',
                       'page_events_' || to_char(m, 'YYYY_MM'), m, m + INTERVAL '1 month');
    END LOOP;
END $$;

-- DEFAULT partition: catches rows outside all ranges instead of failing.
CREATE TABLE page_events_default PARTITION OF page_events DEFAULT;

-- An index on the parent is created on every partition automatically.
CREATE INDEX ON page_events (user_id);

-- Insert into the PARENT; Postgres routes each row to its partition.
INSERT INTO page_events (event_id, user_id, event_type, created_at)
SELECT g,
       1 + (random() * 9999)::int,
       (ARRAY['view','click','purchase'])[1 + (random() * 2)::int],
       TIMESTAMP '2025-01-01' + random() * INTERVAL '365 days'
FROM generate_series(1, 200000) g;
INSERT INTO page_events VALUES (999999, 1, 'view', '2026-02-01');   -- lands in DEFAULT
ANALYZE page_events;

-- Where did rows go? tableoid tells the physical table of each row.
SELECT tableoid::regclass AS partition, COUNT(*) AS rows
FROM page_events
GROUP BY 1
ORDER BY 1;


-- -----------------------------------------------------------------------------
-- 2. Partition pruning
-- -----------------------------------------------------------------------------

-- Filter on the partition key -> only the March partition is scanned.
EXPLAIN
SELECT COUNT(*) FROM page_events
WHERE created_at >= '2025-03-01' AND created_at < '2025-04-01';

-- Without a filter on the key -> every partition is scanned (Append of 13 scans).
EXPLAIN
SELECT COUNT(*) FROM page_events WHERE user_id = 42;

-- A function on the key defeats pruning, just like it defeats indexes.
EXPLAIN
SELECT COUNT(*) FROM page_events WHERE EXTRACT(MONTH FROM created_at) = 3;


-- -----------------------------------------------------------------------------
-- 3. Data retention: detach / drop old partitions (instant)
-- -----------------------------------------------------------------------------

-- Archive January: DETACH turns the partition into a normal standalone table.
-- Compare with DELETE ... WHERE created_at < '2025-02-01': row by row, bloats the table.
ALTER TABLE page_events DETACH PARTITION page_events_2025_01;
SELECT COUNT(*) AS rows_still_in_parent FROM page_events;
SELECT COUNT(*) AS rows_in_archive      FROM page_events_2025_01;   -- data kept, separately

-- Re-attach it later (Postgres validates the range unless a matching CHECK exists)...
ALTER TABLE page_events ATTACH PARTITION page_events_2025_01
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
-- ...or drop it for good:  DROP TABLE page_events_2025_01;


-- -----------------------------------------------------------------------------
-- 4. LIST and HASH partitioning
-- -----------------------------------------------------------------------------

-- LIST: explicit values per partition (e.g. data residency per region).
CREATE TABLE customers_by_region (LIKE public.customers) PARTITION BY LIST (country);
CREATE TABLE customers_india PARTITION OF customers_by_region FOR VALUES IN ('India');
CREATE TABLE customers_na    PARTITION OF customers_by_region FOR VALUES IN ('USA', 'Canada');
CREATE TABLE customers_other PARTITION OF customers_by_region DEFAULT;
INSERT INTO customers_by_region SELECT * FROM public.customers;

SELECT tableoid::regclass AS partition, COUNT(*) FROM customers_by_region GROUP BY 1 ORDER BY 1;

-- HASH: spread rows evenly over N partitions when no natural range exists.
CREATE TABLE sessions (session_id BIGINT, user_id INT NOT NULL) PARTITION BY HASH (user_id);
CREATE TABLE sessions_p0 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessions_p1 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sessions_p2 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sessions_p3 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 3);
INSERT INTO sessions SELECT g, g FROM generate_series(1, 10000) g;
SELECT tableoid::regclass AS partition, COUNT(*) FROM sessions GROUP BY 1 ORDER BY 1;   -- ~2500 each


-- -----------------------------------------------------------------------------
-- 5. Materialized views
-- -----------------------------------------------------------------------------

-- An expensive aggregation, stored physically.
CREATE MATERIALIZED VIEW mv_customer_ltv AS
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name                          AS customer,
       COUNT(DISTINCT o.order_id)                                  AS orders,
       COALESCE(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 0) AS lifetime_value
FROM public.customers c
LEFT JOIN public.orders o       ON o.customer_id = c.customer_id AND o.status NOT IN ('cancelled','returned')
LEFT JOIN public.order_items oi ON oi.order_id   = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;

-- It's a real relation: indexable. A UNIQUE index enables REFRESH ... CONCURRENTLY.
CREATE UNIQUE INDEX ON mv_customer_ltv (customer_id);

SELECT * FROM mv_customer_ltv ORDER BY lifetime_value DESC LIMIT 3;

-- Snapshot semantics: new data is invisible until a refresh.
BEGIN;
INSERT INTO public.orders (order_id, customer_id, order_date, status) VALUES (900, 20, now(), 'delivered');
INSERT INTO public.order_items (order_id, product_id, quantity, unit_price) VALUES (900, 2, 1, 1500);

SELECT orders, lifetime_value FROM mv_customer_ltv WHERE customer_id = 20;   -- 0 | 0  (stale)

-- CONCURRENTLY: builds the new result and swaps in the differences; readers are
-- never blocked (needs the unique index; slower than a plain refresh).
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_ltv;
SELECT orders, lifetime_value FROM mv_customer_ltv WHERE customer_id = 20;   -- 1 | 1500
ROLLBACK;                         -- undo the demo order (and the refresh, which is transactional)


-- -----------------------------------------------------------------------------
-- 6. Housekeeping views every data engineer should know
-- -----------------------------------------------------------------------------

-- Table sizes, including indexes and TOAST.
SELECT relname AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       n_live_tup AS live_rows,
       n_dead_tup AS dead_rows,                      -- MVCC garbage waiting for VACUUM
       last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname IN ('public', 'sandbox')
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 8;

-- Manual maintenance (autovacuum usually does this for you).
VACUUM (ANALYZE) page_events;


RESET search_path;
DROP SCHEMA sandbox CASCADE;
