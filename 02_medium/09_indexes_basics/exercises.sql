-- =============================================================================
-- 02_medium/09 · Indexes (Basics) — EXERCISES
-- Uses: indexes + DDL (easy/03) + functions (easy/12) + GROUP BY (easy/11)
--       + joins (01) + CTEs (06)
-- Work in a schema "lab"; drop it at the end. Plans/timings vary per machine —
-- focus on the NODE TYPES (Seq Scan / Index Scan / Bitmap / Index Only / Sort).
-- =============================================================================


-- Q1. List every index in the public schema with its table and definition.
--     How many are there, and which of them were created automatically by a
--     PRIMARY KEY or UNIQUE constraint?
--     Expected: 16 indexes; 12 come from PK/UNIQUE constraints



-- Q2. Create lab.page_views with 300,000 rows:
--       view_id (identity PK), user_id (1..20000), url (one of 50 paths like
--       '/product/1' .. '/product/50'), viewed_at (random time in 2025),
--       duration_ms (random 100..60000).
--     Use setseed() for reproducibility, then ANALYZE.



-- Q3. EXPLAIN ANALYZE "all views of user 777". Note the plan and execution
--     time. Create a suitable index and run it again. What changed?



-- Q4. The product team asks for "the 10 most recent views of user 777".
--     Design ONE index that makes this query need no Sort node, and show
--     the plan proves it.



-- Q5. Count views on 2025-07-04. Write it first with
--     viewed_at::date = '2025-07-04', then sargably. Create an index on
--     viewed_at and compare the two plans.



-- Q6. Which plan does the planner pick for  WHERE duration_ms > 100  (almost
--     all rows) versus  WHERE duration_ms > 59900  (very few rows), once there
--     is an index on duration_ms? Explain why they differ.



-- Q7. Report the size of lab.page_views and of each of its indexes
--     (pg_size_pretty). Which index would you drop if writes became too slow,
--     and why? Finally DROP SCHEMA lab CASCADE.
