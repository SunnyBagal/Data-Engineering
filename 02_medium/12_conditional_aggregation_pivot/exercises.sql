-- =============================================================================
-- 02_medium/12 · Conditional Aggregation & Pivoting — EXERCISES
-- Uses: pivots + CTEs (06) + CASE (05) + joins (01) + date functions (easy/12)
--       + GROUP BY (easy/11)
-- =============================================================================


-- Q1. Orders per year as one row each, with columns: total, delivered,
--     cancelled, returned, open (pending + shipped). Use FILTER.
--     Expected: 2023 | 20 | 16 | 2 | 2 | 0 ; 2024 | 14 | 13 | 1 | 0 | 0 ; 2025 | 12 | 7 | 0 | 1 | 4



-- Q2. Revenue (non-cancelled orders) per category as rows and 2023 / 2024 /
--     2025 as columns, plus a total column, highest total first.
--     Expected: Laptops 6090.00 | 6720.00 | 4900.00 | 17710.00



-- Q3. Customer signups: countries as rows, signup years 2022–2025 as columns,
--     using SUM(CASE …) only (portable — no FILTER).
--     Expected: India 3 | 3 | 1 | 1



-- Q4. For each sales rep (employee on orders): delivered, cancelled and
--     returned order counts, and the problem rate % (cancelled + returned)
--     with 1 decimal, worst first.
--     Expected: James 20.0, Kavya 16.7, Pooja 12.5, Mark 0.0



-- Q5. Logins by device (rows) with weekday and weekend counts as columns and
--     the weekend share in % (1 decimal).
--     Expected: android 4 | 2 | 33.3 ; ios 11 | 2 | 15.4 ; web 15 | 3 | 16.7



-- Q6. Payments pivot: years as rows, payment methods as columns (amounts),
--     showing 0 instead of NULL where nothing was paid. Add a column "top_method"
--     naming the method with the highest amount that year (hint: GREATEST of
--     the columns, then CASE to find which one it was).
--     Expected: 2023 top = card, 2024 top = card, 2025 top = card



-- Q7. Unpivot your Q1 result back into (year, status_group, orders) rows,
--     excluding rows with 0 orders.
--     Expected: 8 rows
