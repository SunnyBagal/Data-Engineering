-- =============================================================================
-- 01_easy/06 · SELECT Basics — SOLUTIONS
-- =============================================================================


-- Q1. || concatenates; mixing in a literal ', ' and parentheses builds the format.
SELECT last_name || ', ' || first_name || ' (' || job_title || ')' AS employee,
       ROUND(salary / 12, 2)                                      AS monthly_salary
FROM employees;


-- Q2. price is NUMERIC, so (price - cost) / price is exact decimal division.
SELECT product_name,
       price,
       cost,
       price - cost                           AS margin,
       ROUND((price - cost) / price * 100, 1) AS margin_pct,
       stock_qty < 10                         AS needs_restock     -- a boolean expression
FROM products;


-- Q3.
SELECT DISTINCT job_title FROM employees;            -- 17 rows
-- Preview of topic 10, counting directly:
SELECT COUNT(DISTINCT job_title) AS distinct_titles FROM employees;   -- 17


-- Q4. 16 pairs. DISTINCT treats NULL as a value of its own, so (USA, NULL)
--     from Liam is a separate pair; COUNT(DISTINCT city) would ignore NULLs (15).
SELECT DISTINCT country, city FROM customers;


-- Q5. Expressions can't reference aliases defined in the same SELECT, so
--     "net" repeats the formula instead of writing gross - discount_amt.
SELECT order_id,
       product_id,
       quantity * unit_price                                   AS gross,
       ROUND(quantity * unit_price * discount, 2)              AS discount_amt,
       quantity * unit_price - ROUND(quantity * unit_price * discount, 2) AS net
FROM order_items;


-- Q6. ORDER BY must start with the DISTINCT ON column; the next sort key
--     (login_at DESC) decides WHICH row per customer is kept.
SELECT DISTINCT ON (customer_id)
       customer_id, login_at, device
FROM logins
ORDER BY customer_id, login_at DESC;


-- Q7.
--  a) 6 rows: departments 1–5 plus one NULL (CEO and the contractor).
--  b) NULL — any || with NULL yields NULL. Use CONCAT('a', NULL, 'b') -> 'ab'.
--  c) ONE column named "price" containing product names (missing comma = alias).
--  d) ERROR: column "s" does not exist — WHERE is evaluated before SELECT, so
--     the alias doesn't exist yet. Use WHERE salary > 100000.
SELECT CONCAT('a', NULL, 'b') AS concat_ignores_null;
