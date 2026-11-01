-- =============================================================================
-- 02_medium/09 · Indexes (Basics) — LESSON
-- Our practice tables are tiny (a seq scan of 46 rows is always cheapest), so
-- we generate a 200,000-row table in a "sandbox" schema to see real effects.
-- Exact costs/timings in EXPLAIN output will differ on your machine.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;


-- -----------------------------------------------------------------------------
-- 1. Build a realistically sized table
-- -----------------------------------------------------------------------------

SELECT setseed(0.42);          -- makes random() reproducible -> same data every run

CREATE TABLE events (
    event_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- PK -> automatic unique index
    customer_id  INT         NOT NULL,
    event_type   TEXT        NOT NULL,
    event_time   TIMESTAMP   NOT NULL,
    amount       NUMERIC(10,2),
    is_test      BOOLEAN     NOT NULL
);

-- generate_series produces 200k rows; random() fills them with varied data.
INSERT INTO events (customer_id, event_type, event_time, amount, is_test)
SELECT (random() * 9999)::int + 1,                                       -- 10,000 customers
       (ARRAY['view','click','add_to_cart','purchase'])[1 + (random() * 3)::int],
       TIMESTAMP '2025-01-01' + random() * INTERVAL '300 days',
       CASE WHEN random() < 0.1 THEN round((random() * 500)::numeric, 2) END,
       random() < 0.02                                                   -- 2% test events
FROM generate_series(1, 200000);

ANALYZE events;                -- collect statistics so the planner can estimate well


-- -----------------------------------------------------------------------------
-- 2. Without an index: sequential scan
-- -----------------------------------------------------------------------------

-- EXPLAIN shows the plan WITHOUT running the query.
-- Expect: "Seq Scan on events ... Filter: (customer_id = 42)"
EXPLAIN
SELECT * FROM events WHERE customer_id = 42;

-- EXPLAIN ANALYZE runs it and shows actual time and rows.
-- "Rows Removed by Filter: ~199980" = work wasted reading rows we didn't need.
EXPLAIN ANALYZE
SELECT * FROM events WHERE customer_id = 42;


-- -----------------------------------------------------------------------------
-- 3. Create an index and compare
-- -----------------------------------------------------------------------------

CREATE INDEX idx_events_customer ON events (customer_id);   -- B-tree by default

-- Expect: "Bitmap Index Scan on idx_events_customer" (or Index Scan) and a much
-- lower cost / execution time: ~20 matching rows found directly.
EXPLAIN ANALYZE
SELECT * FROM events WHERE customer_id = 42;

-- Index Only Scan: the query needs only customer_id, which is IN the index,
-- so the table itself doesn't have to be read (when the visibility map allows).
VACUUM events;                                -- updates the visibility map
EXPLAIN
SELECT customer_id FROM events WHERE customer_id BETWEEN 100 AND 110;


-- -----------------------------------------------------------------------------
-- 4. Selectivity: the planner may IGNORE an index — on purpose
-- -----------------------------------------------------------------------------

-- Same index, two predicates with very different selectivity:
-- ~1% of rows -> the index wins (Bitmap/Index Scan).
EXPLAIN
SELECT * FROM events WHERE customer_id < 100;

-- ~99% of rows -> one sequential pass is cheaper than ~198k index lookups,
-- so the planner chooses a Seq Scan even though an index exists.
EXPLAIN
SELECT * FROM events WHERE customer_id > 100;

-- In between (~1/3 of rows), the planner often uses a BITMAP scan: it collects
-- matching row locations from the index, sorts them by physical position,
-- then reads the table pages in order — a middle ground.
CREATE INDEX idx_events_type ON events (event_type);
EXPLAIN
SELECT * FROM events WHERE event_type = 'click';

-- A rare value (2% test events) on a boolean -> index could help, but an index
-- on a 2-value column is usually wasteful. A PARTIAL index (03_hard/06) is better.
EXPLAIN
SELECT * FROM events WHERE is_test;


-- -----------------------------------------------------------------------------
-- 5. Composite index: column order matters
-- -----------------------------------------------------------------------------

DROP INDEX idx_events_customer;                       -- replaced by the composite below
CREATE INDEX idx_events_customer_time ON events (customer_id, event_time);

-- Uses the index (leftmost column = customer_id).
EXPLAIN SELECT * FROM events WHERE customer_id = 42;

-- Uses both columns: equality on the first, range on the second.
EXPLAIN SELECT * FROM events
WHERE customer_id = 42 AND event_time >= '2025-06-01';

-- "Latest 5 events of a customer": the index is already sorted by
-- (customer_id, event_time), so no Sort node is needed — rows come out in order.
EXPLAIN SELECT * FROM events
WHERE customer_id = 42
ORDER BY event_time DESC
LIMIT 5;

-- Filter only on the SECOND column: the index can't be used efficiently
-- (it's sorted by customer first) -> Seq Scan.
EXPLAIN SELECT * FROM events
WHERE event_time >= '2025-10-01' AND event_time < '2025-10-02';


-- -----------------------------------------------------------------------------
-- 6. Things that prevent index use
-- -----------------------------------------------------------------------------

CREATE INDEX idx_events_time ON events (event_time);

-- Function on the column -> the index on event_time can't be used.
EXPLAIN SELECT COUNT(*) FROM events WHERE DATE(event_time) = '2025-03-15';

-- Rewrite as a range on the bare column -> index range scan.
EXPLAIN SELECT COUNT(*) FROM events
WHERE event_time >= '2025-03-15' AND event_time < '2025-03-16';

-- Leading wildcard: a B-tree can't search "ends with".
EXPLAIN SELECT * FROM events WHERE event_type LIKE '%cart';


-- -----------------------------------------------------------------------------
-- 7. The cost of indexes: space (and write speed)
-- -----------------------------------------------------------------------------

-- Indexes are separate structures that take space and must be updated on
-- every write.
SELECT indexname,
       pg_size_pretty(pg_relation_size(('sandbox.' || indexname)::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'sandbox' AND tablename = 'events';

SELECT pg_size_pretty(pg_relation_size('sandbox.events'))        AS table_size,
       pg_size_pretty(pg_indexes_size('sandbox.events'))         AS all_indexes_size;


-- -----------------------------------------------------------------------------
-- 8. Indexes in our practice database
-- -----------------------------------------------------------------------------

-- PKs/UNIQUE constraints created indexes automatically; schema.sql added some
-- for foreign keys (Postgres does NOT index FK columns automatically).
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;


-- -----------------------------------------------------------------------------
-- Clean up
-- -----------------------------------------------------------------------------
RESET search_path;
DROP SCHEMA sandbox CASCADE;
