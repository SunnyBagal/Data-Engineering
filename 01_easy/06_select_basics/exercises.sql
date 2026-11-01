-- =============================================================================
-- 01_easy/06 · SELECT Basics — EXERCISES
-- Uses: SELECT + data types (02) + DML / transactions (05, 01)
-- =============================================================================


-- Q1. List every employee as one column "employee" in the format
--     'Last, First (Job Title)'   e.g.  'Sharma, Anita (CEO)'
--     plus their monthly salary (salary / 12) rounded to 2 decimals.
--     Expected: 20 rows; Anita's monthly salary = 20833.33



-- Q2. For each product show: product_name, price, cost, margin (price - cost),
--     margin_pct (margin as % of price, 1 decimal) and a boolean column
--     needs_restock that is true when stock_qty < 10.
--     Expected: 24 rows; GamerX 17 Laptop: margin 550.00, margin_pct 25.0, needs_restock true



-- Q3. How many different job titles exist? First list them with DISTINCT,
--     then count the rows you got.
--     Expected: 17 distinct titles



-- Q4. List the distinct (country, city) pairs of customers. How many are there,
--     and why is it 16 even though only 15 distinct non-NULL cities exist?



-- Q5. For every order line show order_id, product_id and these three columns:
--       gross      = quantity * unit_price
--       discount_amt = gross * discount (2 decimals)
--       net        = gross - discount_amt
--     Expected: 78 rows; order 6 / product 2: gross 1500.00, discount_amt 150.00, net 1350.00



-- Q6. Using DISTINCT ON, show the most recent login (customer_id, login_at,
--     device) of each customer who has logged in.
--     Expected: 7 rows; customer 1's latest login is 2025-09-20 12:00 (android)



-- Q7. Predict, then run: what does each query return, and why?
--       a) SELECT DISTINCT dept_id FROM employees;          -- how many rows?
--       b) SELECT 'a' || NULL || 'b';
--       c) SELECT product_name price FROM products LIMIT 1; -- how many columns?
--       d) SELECT salary AS s FROM employees WHERE s > 100000;
