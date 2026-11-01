-- =============================================================================
-- 03_hard/12 · Partitioning, Materialized Views & Scaling — EXERCISES
-- Uses: partitioning/MVs + EXPLAIN (05) + indexes (06) + dynamic SQL (08)
--       + window functions (01, 02) + CTEs (medium/06)
-- Work in schema "lab"; drop it at the end.
-- =============================================================================


-- Q1. Create lab.payments_part with the same columns as payments, partitioned
--     by RANGE on paid_at with yearly partitions 2023, 2024, 2025 and a DEFAULT
--     partition. Primary key (payment_id, paid_at). Load all payments and
--     show rows and total amount per partition.
--     Expected: 2023 -> 19 rows / 10942.62, 2024 -> 14 / 11924.49, 2025 -> 10 / 5182.46, default 0



-- Q2. Prove partition pruning: EXPLAIN a query for payments made in 2024 and
--     one for payments with amount > 1000 (no key filter). How many partitions
--     does each plan touch?
--     Expected: 1 vs 4



-- Q3. Retention policy "keep only the last two years": detach the 2023
--     partition into lab.payments_archive_2023 (rename it), and show the parent
--     now has 24 rows while the archive keeps 19.



-- Q4. A 2026 payment arrives. Insert one; where does it land? Then create the
--     proper 2026 partition. Why does that fail while the row sits in DEFAULT,
--     and how do you fix it?



-- Q5. Create lab.mv_monthly_revenue (month, orders, revenue) over
--     non-cancelled orders with a unique index. Query the 3 best months.
--     Expected: 2024-11 2624.79, 2025-10 2403.95, 2023-12 2278.98



-- Q6. Show the MV is stale: inside a transaction insert a big order for the
--     current month, query the MV (unchanged), REFRESH … CONCURRENTLY, query
--     again, ROLLBACK.



-- Q7. Design (comments): a click-stream table receives 50 million rows/day and
--     must keep 90 days online; analysts query by day and by user_id. Propose
--     the partitioning scheme, indexes, retention mechanism, and where heavy
--     analytics should run. Finally DROP SCHEMA lab CASCADE.
