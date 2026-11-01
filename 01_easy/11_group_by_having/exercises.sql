-- =============================================================================
-- 01_easy/11 · GROUP BY & HAVING — EXERCISES
-- Uses: GROUP BY/HAVING + aggregates (10) + ORDER BY/LIMIT (09) + NULLs (08)
--       + WHERE (07) + expressions (06)
-- =============================================================================


-- Q1. Number of customers per country, biggest first (alphabetical on ties).
--     Expected: India 8, USA 5, UK 3, Canada 2, Germany 2



-- Q2. Orders per year AND status (one row per combination), sorted by year
--     then count descending. Which year had the most cancellations?
--     Expected: 2023 had 2 cancellations



-- Q3. Order totals (sum of line revenue, 2 decimals) for orders whose total
--     exceeds 2000, largest first.
--     Expected: 33 -> 2624.79, 21 -> 2225.00, 45 -> 2200.00



-- Q4. For ACTIVE employees, departments whose average salary is above
--     100,000. Show dept_id (label NULL as 'no dept' — hint: COALESCE needs
--     text), headcount and average salary (2 decimals).
--     Expected: 3 rows — 'no dept' 155000.00, '1' 116666.67, '4' 111666.67



-- Q5. Customers with at least 3 non-cancelled orders. Show customer_id,
--     the number of such orders, and their first and last order dates.
--     Expected: 7 customers; customer 1 has 6 orders



-- Q6. The 5 best-selling products by units sold, with their revenue.
--     Break ties by revenue (higher first).
--     Expected product_ids in order: 5, 18, 8, 20, 19



-- Q7. Payment methods report: number of payments, total and average amount
--     (2 decimals) per method, keeping only methods that collected more than
--     2000 in total. Then a second query: number of payments per month in 2025
--     (use DATE_TRUNC), showing months as dates.
--     Expected: 4 methods (cash is excluded); 2025 has 9 months with payments
