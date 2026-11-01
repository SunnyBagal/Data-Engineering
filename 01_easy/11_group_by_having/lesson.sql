-- =============================================================================
-- 01_easy/11 · GROUP BY & HAVING — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. One group per value
-- -----------------------------------------------------------------------------

-- Without GROUP BY: one number for the whole table.
SELECT COUNT(*) FROM customers;                         -- 20

-- With GROUP BY: one row per country, COUNT(*) runs once per group.
SELECT country, COUNT(*) AS customers
FROM customers
GROUP BY country
ORDER BY customers DESC, country;                       -- India 8, USA 5, UK 3, ...

-- Orders per status.
SELECT status, COUNT(*) AS orders
FROM orders
GROUP BY status
ORDER BY orders DESC;

-- NULL forms its own group: orders with no sales rep (online) appear as one row.
SELECT employee_id, COUNT(*) AS orders
FROM orders
GROUP BY employee_id
ORDER BY employee_id NULLS FIRST;


-- -----------------------------------------------------------------------------
-- 2. Several aggregates per group
-- -----------------------------------------------------------------------------

-- Department salary statistics. dept_id NULL = CEO + contractor.
SELECT dept_id,
       COUNT(*)              AS headcount,
       ROUND(AVG(salary), 2) AS avg_salary,
       MIN(salary)           AS min_salary,
       MAX(salary)           AS max_salary,
       SUM(salary)           AS payroll
FROM employees
WHERE is_active                    -- row filter BEFORE grouping
GROUP BY dept_id
ORDER BY dept_id;

-- Revenue per order: the order "total" is an aggregate of its lines.
SELECT order_id,
       COUNT(*)                                              AS lines,
       SUM(quantity)                                         AS units,
       ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS order_total
FROM order_items
GROUP BY order_id
ORDER BY order_total DESC
LIMIT 5;


-- -----------------------------------------------------------------------------
-- 3. The golden rule: SELECT only grouped columns or aggregates
-- -----------------------------------------------------------------------------

-- ERROR: first_name is neither grouped nor aggregated — 8 Indians, 8 names, 1 row?
-- SELECT country, first_name, COUNT(*) FROM customers GROUP BY country;

-- Fix A: aggregate it (e.g. list them).
SELECT country,
       COUNT(*) AS customers,
       STRING_AGG(first_name, ', ' ORDER BY first_name) AS names
FROM customers
GROUP BY country;

-- Fix B: group by it too (but then each group is (country, first_name)).

-- Exception: grouping by a PRIMARY KEY lets you select other columns of that
-- table, because they are functionally dependent on it (one value per key).
SELECT c.customer_id, c.first_name, c.country, COUNT(*) AS logins
FROM customers c, logins l                 -- (old-style join; proper JOINs in 02_medium/01)
WHERE l.customer_id = c.customer_id
GROUP BY c.customer_id                     -- first_name/country allowed: PK dependency
ORDER BY logins DESC;


-- -----------------------------------------------------------------------------
-- 4. Grouping by multiple columns
-- -----------------------------------------------------------------------------

-- One row per (country, city) combination.
SELECT country, city, COUNT(*) AS customers
FROM customers
GROUP BY country, city
ORDER BY country, customers DESC;

-- Payments per method per year.
SELECT EXTRACT(YEAR FROM paid_at) AS year,
       method,
       COUNT(*)    AS payments,
       SUM(amount) AS total
FROM payments
GROUP BY EXTRACT(YEAR FROM paid_at), method
ORDER BY year, total DESC;


-- -----------------------------------------------------------------------------
-- 5. Grouping by expressions (time buckets, flags)
-- -----------------------------------------------------------------------------

-- Orders per year. Grouping by the alias/position is allowed in Postgres.
SELECT EXTRACT(YEAR FROM order_date) AS order_year, COUNT(*) AS orders
FROM orders
GROUP BY order_year
ORDER BY order_year;                                    -- 2023: 20, 2024: 14, 2025: 12

-- Orders per month: DATE_TRUNC keeps it a timestamp (sorts correctly across years,
-- unlike grouping by month number alone which would merge Jan 2023 and Jan 2024).
SELECT DATE_TRUNC('month', order_date)::date AS month, COUNT(*) AS orders
FROM orders
WHERE order_date >= '2025-01-01'
GROUP BY 1
ORDER BY 1;

-- Group by a boolean expression: premium vs regular products.
SELECT price >= 500 AS is_premium,
       COUNT(*)     AS products,
       ROUND(AVG(price), 2) AS avg_price
FROM products
GROUP BY price >= 500;


-- -----------------------------------------------------------------------------
-- 6. HAVING: filtering groups
-- -----------------------------------------------------------------------------

-- Loyal customers: 3+ orders that were not cancelled.
-- WHERE removes cancelled orders (a row condition),
-- HAVING keeps customers whose remaining count >= 3 (a group condition).
SELECT customer_id, COUNT(*) AS orders
FROM orders
WHERE status <> 'cancelled'
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY orders DESC, customer_id;                      -- 7 customers

-- Big orders: totals above 2000.
-- HAVING repeats the aggregate (Postgres doesn't allow the alias here).
SELECT order_id, ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS order_total
FROM order_items
GROUP BY order_id
HAVING SUM(quantity * unit_price * (1 - discount)) > 2000
ORDER BY order_total DESC;                              -- orders 33, 21, 45

-- Data-quality check: duplicate values. (None here — every email is unique.)
SELECT email, COUNT(*) FROM customers GROUP BY email HAVING COUNT(*) > 1;

-- WHERE vs HAVING for a non-aggregate condition: both give the same result,
-- but WHERE filters BEFORE grouping (less work) and states intent clearly.
SELECT country, COUNT(*) FROM customers GROUP BY country HAVING country <> 'India';  -- works, but...
SELECT country, COUNT(*) FROM customers WHERE country <> 'India' GROUP BY country;   -- ...prefer this


-- -----------------------------------------------------------------------------
-- 7. Putting it all together (every clause, in logical order)
-- -----------------------------------------------------------------------------

-- Best-selling products by units (only products with 5+ units sold,
-- excluding lines with discounts of 20% or more).
SELECT   product_id,                                     -- 5. SELECT
         SUM(quantity) AS units,
         ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS revenue
FROM     order_items                                     -- 1. FROM
WHERE    discount < 0.20                                 -- 2. WHERE
GROUP BY product_id                                      -- 3. GROUP BY
HAVING   SUM(quantity) >= 5                              -- 4. HAVING
ORDER BY units DESC, revenue DESC                        -- 6. ORDER BY
LIMIT    5;                                              -- 7. LIMIT
