-- =============================================================================
-- 03_hard/04 · Advanced Grouping & LATERAL — EXERCISES
-- Uses: ROLLUP/CUBE/GROUPING SETS/LATERAL + recursive CTEs (03) + windows (01)
--       + JSON basics + CASE (medium/05) + joins (medium/01)
-- =============================================================================


-- Q1. Payments by year and method with ROLLUP. Replace the NULLs of subtotal
--     rows with 'All years' / 'All methods' using GROUPING(), and order so each
--     year's subtotal follows its detail rows and the grand total is last.
--     Expected: 17 rows; 2024 subtotal 11924.49; grand total 28049.57



-- Q2. Order counts with CUBE over (country, status). How many rows are
--     produced? Which country has the most orders overall, and which status
--     is most common overall?
--     Expected: 24 rows; India 19 orders; 'delivered' 36



-- Q3. Using GROUPING SETS, one query that returns: revenue per year, revenue
--     per category, and the grand total (non-cancelled orders). Add a column
--     "breakdown" = 'year' / 'category' / 'total'.
--     Expected: 3 year rows + 7 category rows + 1 total = 11 rows; total 30453.52



-- Q4. Revenue by ROOT category and leaf category with subtotals per root and a
--     grand total (ROLLUP + the recursive category tree).
--     Expected: Electronics subtotal 28563.55, grand total 31730.52



-- Q5. For each customer who has orders, their 2 largest orders (by total) using
--     CROSS JOIN LATERAL. Then rewrite with ROW_NUMBER and confirm the same rows.
--     Expected: 34 rows



-- Q6. Explode products.attributes->'tags' with LATERAL and count products per
--     tag; also list products that have NO tags (LEFT JOIN LATERAL … ON TRUE).
--     Expected: 7 distinct tags; 17 products without tags



-- Q7. For every department (all 6), the two most recently hired employees and
--     how many days after the previous hire they joined (LAG inside the
--     lateral subquery). Departments without staff must still appear.
--     Expected: 10 rows; Research appears once with NULLs
