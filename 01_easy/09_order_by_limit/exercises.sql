-- =============================================================================
-- 01_easy/09 · ORDER BY & LIMIT — EXERCISES
-- Uses: ORDER BY/LIMIT + NULLs (08) + WHERE (07) + SELECT expressions/DISTINCT (06)
-- =============================================================================


-- Q1. The 5 most recent orders: order_id, customer_id, order_date, status.
--     Expected: orders 46, 45, 44, 43, 42



-- Q2. All employees sorted by department (employees without a department
--     FIRST), then by salary highest first, then by last name.
--     Show dept_id, first_name, last_name, salary.



-- Q3. Top 3 products by margin (price - cost), excluding discontinued ones.
--     Show product_name and margin.
--     Expected: GamerX 17 Laptop 550.00, UltraBook Air 13 450.00, ProBook 14 Laptop 350.00



-- Q4. A product catalog page shows 5 products per page, most expensive first.
--     Return page 2. Make the ordering deterministic.
--     Expected: Robot Vacuum, Budget Laptop 15, 27in 4K Monitor, Espresso Machine,
--               Noise Cancelling Headphones



-- Q5. "Who are the 9 highest-paid employees?" Write it with LIMIT and with
--     FETCH FIRST … WITH TIES. Why do the results differ in row count?
--     Expected: 9 rows vs 10 rows



-- Q6. Keyset pagination: a user has seen orders up to
--     (order_date = '2024-07-01 08:15', order_id = 28), sorted by date then id.
--     Return the next 5 orders.
--     Expected: orders 29, 30, 31, 32, 33



-- Q7. The 3 customers who signed up most recently and HAVE a phone number,
--     showing name, phone and signup_date. Then: the department with the
--     largest known budget (ignore NULL budgets — careful with DESC!).
--     Expected: Lucas, Ethan, Liam  |  Engineering
