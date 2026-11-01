-- =============================================================================
-- 02_medium/09 · Indexes (Basics) — SOLUTIONS
-- =============================================================================


-- Q1. Constraint-backed indexes are listed in pg_constraint with conindid;
--     joining tells us which indexes a PK/UNIQUE constraint owns.
SELECT i.tablename,
       i.indexname,
       i.indexdef,
       c.contype IS NOT NULL AS from_constraint      -- p = primary key, u = unique
FROM pg_indexes i
LEFT JOIN pg_constraint c
       ON c.conindid = (i.schemaname || '.' || i.indexname)::regclass
      AND c.contype IN ('p', 'u')
WHERE i.schemaname = 'public'
ORDER BY i.tablename, i.indexname;
-- 16 indexes: 9 primary keys + 3 unique constraints (dept_name, both emails)
-- + 4 created in schema.sql for foreign-key columns.


-- Q2.
CREATE SCHEMA IF NOT EXISTS lab;
SELECT setseed(0.7);

CREATE TABLE lab.page_views (
    view_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     INT       NOT NULL,
    url         TEXT      NOT NULL,
    viewed_at   TIMESTAMP NOT NULL,
    duration_ms INT       NOT NULL
);

INSERT INTO lab.page_views (user_id, url, viewed_at, duration_ms)
SELECT 1 + (random() * 19999)::int,
       '/product/' || (1 + (random() * 49)::int),
       TIMESTAMP '2025-01-01' + random() * INTERVAL '365 days',
       100 + (random() * 59900)::int
FROM generate_series(1, 300000);

ANALYZE lab.page_views;


-- Q3. Before: Seq Scan, ~300k rows read, ~15 kept ("Rows Removed by Filter").
EXPLAIN ANALYZE SELECT * FROM lab.page_views WHERE user_id = 777;

CREATE INDEX idx_pv_user ON lab.page_views (user_id);

-- After: Bitmap/Index Scan on idx_pv_user — only the matching rows are touched;
-- execution time drops by one to two orders of magnitude.
EXPLAIN ANALYZE SELECT * FROM lab.page_views WHERE user_id = 777;


-- Q4. Equality column first, sort column second. The index delivers rows
--     already ordered by viewed_at within user 777; reading it backwards
--     gives DESC order and the LIMIT stops after 10 rows. No Sort node.
CREATE INDEX idx_pv_user_time ON lab.page_views (user_id, viewed_at);

EXPLAIN
SELECT * FROM lab.page_views
WHERE user_id = 777
ORDER BY viewed_at DESC
LIMIT 10;                       -- expect: Limit -> Index Scan Backward using idx_pv_user_time
-- idx_pv_user is now redundant: (user_id, viewed_at) serves user_id-only lookups too.
DROP INDEX lab.idx_pv_user;


-- Q5.
CREATE INDEX idx_pv_time ON lab.page_views (viewed_at);

-- Cast on the column: the index on viewed_at is not usable -> Seq Scan.
EXPLAIN SELECT COUNT(*) FROM lab.page_views WHERE viewed_at::date = '2025-07-04';

-- Half-open range on the bare column -> Index (Only) Scan / Bitmap scan on idx_pv_time.
EXPLAIN SELECT COUNT(*) FROM lab.page_views
WHERE viewed_at >= '2025-07-04' AND viewed_at < '2025-07-05';


-- Q6.
CREATE INDEX idx_pv_duration ON lab.page_views (duration_ms);
ANALYZE lab.page_views;

EXPLAIN SELECT * FROM lab.page_views WHERE duration_ms > 100;     -- Seq Scan
EXPLAIN SELECT * FROM lab.page_views WHERE duration_ms > 59900;   -- Index / Bitmap scan
-- The statistics tell the planner that "> 100" matches ~100% of rows: one
-- sequential pass is cheaper than 300k random index lookups. "> 59900" matches
-- ~0.2%: jumping through the index wins. Same index, different selectivity.


-- Q7.
SELECT pg_size_pretty(pg_relation_size('lab.page_views')) AS table_size,
       pg_size_pretty(pg_indexes_size('lab.page_views'))  AS indexes_total;

SELECT indexname,
       pg_size_pretty(pg_relation_size(('lab.' || indexname)::regclass)) AS size
FROM pg_indexes
WHERE schemaname = 'lab' AND tablename = 'page_views'
ORDER BY pg_relation_size(('lab.' || indexname)::regclass) DESC;
-- Candidate to drop: idx_pv_duration — it only helps rare "very long view"
-- queries. Never drop the PK index. Decide with real usage data:
--   SELECT indexrelname, idx_scan FROM pg_stat_user_indexes WHERE schemaname = 'lab';

DROP SCHEMA lab CASCADE;
