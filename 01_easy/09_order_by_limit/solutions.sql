-- =============================================================================
-- 01_easy/09 · ORDER BY & LIMIT — SOLUTIONS
-- =============================================================================


-- Q1. order_date is unique here, but adding order_id as a tie-breaker is a
--     good habit for any "latest N" query.
SELECT order_id, customer_id, order_date, status
FROM orders
ORDER BY order_date DESC, order_id DESC
LIMIT 5;


-- Q2. NULLS FIRST overrides Postgres' default (NULLs last in ASC).
SELECT dept_id, first_name, last_name, salary
FROM employees
ORDER BY dept_id NULLS FIRST, salary DESC, last_name;


-- Q3. Sort by the alias; filter non-discontinued in WHERE (before sorting).
SELECT product_name, price - cost AS margin
FROM products
WHERE NOT is_discontinued
ORDER BY margin DESC
LIMIT 3;


-- Q4. Page n with size s -> OFFSET (n - 1) * s. product_id breaks price ties
--     so every page is stable.
SELECT product_id, product_name, price
FROM products
ORDER BY price DESC, product_id
LIMIT 5 OFFSET 5;


-- Q5. LIMIT cuts at exactly 9 rows -> one of the two 95,000 engineers is dropped
--     arbitrarily. WITH TIES also returns rows equal to the last one -> 10 rows.
SELECT first_name, salary FROM employees ORDER BY salary DESC LIMIT 9;
SELECT first_name, salary FROM employees ORDER BY salary DESC FETCH FIRST 9 ROWS WITH TIES;


-- Q6. Row-value comparison = "after this exact position in the sort order".
SELECT order_id, order_date
FROM orders
WHERE (order_date, order_id) > ('2024-07-01 08:15', 28)
ORDER BY order_date, order_id
LIMIT 5;


-- Q7a.
SELECT first_name, last_name, phone, signup_date
FROM customers
WHERE phone IS NOT NULL
ORDER BY signup_date DESC
LIMIT 3;

-- Q7b. In Postgres, DESC puts NULLs FIRST, so a naive query returns Research.
SELECT dept_name, budget FROM departments ORDER BY budget DESC LIMIT 1;        -- Research (NULL)!
-- Fix 1: NULLS LAST.
SELECT dept_name, budget FROM departments ORDER BY budget DESC NULLS LAST LIMIT 1;
-- Fix 2: filter NULLs out (clearer intent: "known budgets only").
SELECT dept_name, budget FROM departments WHERE budget IS NOT NULL ORDER BY budget DESC LIMIT 1;
