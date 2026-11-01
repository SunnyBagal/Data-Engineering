-- =============================================================================
-- 01_easy/06 · SELECT Basics — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Choosing columns (projection)
-- -----------------------------------------------------------------------------

-- All columns: good for a first look at a table.
SELECT * FROM products;

-- Only what you need: less data transferred, stable column order, self-documenting.
SELECT product_name, price, stock_qty
FROM products;

-- Column order in the output follows the SELECT list, not the table definition.
SELECT stock_qty, product_name FROM products;


-- -----------------------------------------------------------------------------
-- 2. Expressions: computing new columns
-- -----------------------------------------------------------------------------

-- Arithmetic between columns. "margin" exists only in this result, not in the table.
SELECT product_name,
       price,
       cost,
       price - cost                           AS margin,
       ROUND((price - cost) / price * 100, 1) AS margin_pct,      -- NUMERIC / NUMERIC -> no int-division issue
       price * stock_qty                      AS inventory_value  -- value of stock at list price
FROM products;

-- Revenue of each order line: the formula used throughout this course.
SELECT order_id,
       product_id,
       quantity,
       unit_price,
       discount,
       quantity * unit_price * (1 - discount) AS line_revenue
FROM order_items;

-- String concatenation with ||. Builds display values.
SELECT first_name || ' ' || last_name AS full_name,
       email
FROM employees;

-- Literal columns: the same value on every row. Useful for labelling results
-- (e.g. before UNIONing two sources together, 02_medium/04).
SELECT 'customer' AS person_type, first_name, last_name FROM customers;

-- Boolean expressions are values too.
SELECT product_name,
       stock_qty = 0       AS is_out_of_stock,
       price > 500         AS is_premium
FROM products;


-- -----------------------------------------------------------------------------
-- 3. Column aliases
-- -----------------------------------------------------------------------------

-- AS renames the output column. Prefer snake_case so nobody needs quotes later.
SELECT salary * 12 AS annual_salary FROM employees;

-- AS is optional... but this is how bugs hide. The missing comma below makes
-- "salary" an ALIAS for first_name instead of a second column:
SELECT first_name salary FROM employees LIMIT 3;   -- one column called "salary"!

-- Quoted alias: allows spaces/capitals. Pretty for a one-off report, painful to reuse.
SELECT product_name AS "Product Name", price AS "Price (USD)" FROM products;

-- Aliases CAN be used in ORDER BY (it runs after SELECT)...
SELECT product_name, price - cost AS margin
FROM products
ORDER BY margin DESC;

-- ...but NOT in WHERE (it runs before SELECT):
-- SELECT product_name, price - cost AS margin FROM products WHERE margin > 100;
--   ERROR: column "margin" does not exist
-- Fix: repeat the expression, or use a subquery/CTE (02_medium/03, 06).
SELECT product_name, price - cost AS margin
FROM products
WHERE price - cost > 100;


-- -----------------------------------------------------------------------------
-- 4. Table aliases
-- -----------------------------------------------------------------------------

-- "p" is a short name for the table; p.price says exactly where price comes from.
-- Mandatory when two tables have the same column name (joins, 02_medium/01).
SELECT p.product_name, p.price
FROM products AS p;


-- -----------------------------------------------------------------------------
-- 5. DISTINCT
-- -----------------------------------------------------------------------------

-- Every country once (5 rows instead of 20).
SELECT DISTINCT country FROM customers;

-- Distinct applies to the WHOLE row: each (country, city) combination once.
SELECT DISTINCT country, city FROM customers;

-- NULLs are grouped together by DISTINCT: Liam's NULL city appears once.
SELECT DISTINCT city FROM customers;

-- Which statuses are in use? A typical "explore a column" query.
SELECT DISTINCT status FROM orders;

-- Which products have ever been sold?
SELECT DISTINCT product_id FROM order_items;       -- 20 of the 24 products

-- Postgres-only DISTINCT ON: keep the FIRST row per customer according to
-- ORDER BY. Here: each customer's most recent order.
-- The ORDER BY must start with the DISTINCT ON column(s).
SELECT DISTINCT ON (customer_id)
       customer_id, order_id, order_date
FROM orders
ORDER BY customer_id, order_date DESC;


-- -----------------------------------------------------------------------------
-- 6. SELECT without a table, and peeking with LIMIT
-- -----------------------------------------------------------------------------

SELECT CURRENT_DATE AS today, 2 * 3.5 AS math, 'hello' || ' world' AS text;

-- LIMIT (topic 09) to peek at big tables without fetching everything.
SELECT * FROM order_items LIMIT 5;
