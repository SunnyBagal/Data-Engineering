-- =============================================================================
-- 02_medium/04 · Set Operations — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. UNION ALL: stack results
-- -----------------------------------------------------------------------------

-- One contact list from two tables. The literal column labels where each row
-- came from. Column names in the output come from the FIRST query.
SELECT 'customer' AS person_type, first_name, last_name, email
FROM customers
UNION ALL
SELECT 'employee',                first_name, last_name, email
FROM employees
ORDER BY last_name, first_name;          -- ORDER BY sorts the COMBINED result: 40 rows

-- UNION ALL keeps duplicates: every product_id once per line, twice.
SELECT COUNT(*) FROM (
    SELECT product_id FROM order_items
    UNION ALL
    SELECT product_id FROM order_items
) x;                                     -- 156 = 78 + 78


-- -----------------------------------------------------------------------------
-- 2. UNION: stack and remove duplicates
-- -----------------------------------------------------------------------------

-- Every city where we have a customer OR a department.
-- Mumbai appears in both tables but only once in the result.
SELECT city     AS place FROM customers
UNION
SELECT location          FROM departments
ORDER BY place;                          -- 17 rows (includes one NULL: Liam's city)

-- UNION vs UNION ALL row counts on the same input.
SELECT
  (SELECT COUNT(*) FROM (SELECT country FROM customers UNION     SELECT country FROM customers) a) AS with_union,     -- 5
  (SELECT COUNT(*) FROM (SELECT country FROM customers UNION ALL SELECT country FROM customers) b) AS with_union_all; -- 40


-- -----------------------------------------------------------------------------
-- 3. INTERSECT: in both
-- -----------------------------------------------------------------------------

-- Cities that have both customers and a company office.
SELECT city FROM customers
INTERSECT
SELECT location FROM departments;        -- Delhi, Mumbai, Pune

-- Retained customers: ordered in 2023 AND in 2024.
SELECT customer_id FROM orders WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'
INTERSECT
SELECT customer_id FROM orders WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
ORDER BY customer_id;                    -- 8 customers

-- First names shared by a customer and an employee.
SELECT first_name FROM customers
INTERSECT
SELECT first_name FROM employees;        -- Meera


-- -----------------------------------------------------------------------------
-- 4. EXCEPT: in the first, not in the second
-- -----------------------------------------------------------------------------

-- Lapsed customers: ordered in 2023 but NOT in 2024.
SELECT customer_id FROM orders WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'
EXCEPT
SELECT customer_id FROM orders WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
ORDER BY customer_id;                    -- 2, 6, 8, 11, 13

-- Order matters: A EXCEPT B  ≠  B EXCEPT A.
SELECT product_id FROM products EXCEPT SELECT product_id FROM order_items;    -- never sold: 4 rows
SELECT product_id FROM order_items EXCEPT SELECT product_id FROM products;    -- orphans: 0 rows (FK guarantees it)

-- EXCEPT returns only the key; to get names, join back (or use NOT EXISTS directly).
SELECT p.product_id, p.product_name
FROM products p
JOIN (SELECT product_id FROM products
      EXCEPT
      SELECT product_id FROM order_items) unsold ON unsold.product_id = p.product_id;


-- -----------------------------------------------------------------------------
-- 5. Rules: column count, types, positions
-- -----------------------------------------------------------------------------

-- Different column counts:
-- SELECT first_name, last_name FROM customers UNION SELECT first_name FROM employees;
--   ERROR: each UNION query must have the same number of columns

-- Incompatible types:
-- SELECT customer_id FROM customers UNION SELECT email FROM employees;
--   ERROR: UNION types integer and character varying cannot be matched

-- Columns are matched by POSITION, not name. This runs, but mixes first and
-- last names in the same column — a silent bug:
SELECT first_name, last_name FROM customers WHERE customer_id = 1
UNION ALL
SELECT last_name, first_name FROM employees WHERE emp_id = 1;


-- -----------------------------------------------------------------------------
-- 6. ORDER BY / LIMIT per branch need parentheses
-- -----------------------------------------------------------------------------

-- The 2 most expensive laptops and the 2 cheapest books, in one result.
(SELECT product_name, price FROM products WHERE category_id = 3 ORDER BY price DESC LIMIT 2)
UNION ALL
(SELECT product_name, price FROM products WHERE category_id IN (10, 11) ORDER BY price LIMIT 2);


-- -----------------------------------------------------------------------------
-- 7. Report with a total row
-- -----------------------------------------------------------------------------

-- Detail rows + a TOTAL row. A hidden sort key keeps TOTAL last regardless of
-- how the labels sort alphabetically.
SELECT status, orders
FROM (
    SELECT status, COUNT(*) AS orders, 1 AS sort_key FROM orders GROUP BY status
    UNION ALL
    SELECT 'TOTAL', COUNT(*), 2 FROM orders
) t
ORDER BY sort_key, orders DESC;


-- -----------------------------------------------------------------------------
-- 8. Reconciliation: comparing two "copies" of data
-- -----------------------------------------------------------------------------

-- Simulate a target table loaded by an ETL job, with one row missing and one changed.
CREATE TEMP TABLE products_copy AS SELECT product_id, product_name, price FROM products;
DELETE FROM products_copy WHERE product_id = 7;
UPDATE products_copy SET price = 999 WHERE product_id = 12;

-- Rows in the source that are missing or different in the target...
SELECT product_id, product_name, price FROM products
EXCEPT
SELECT product_id, product_name, price FROM products_copy;    -- ids 7 and 12

-- ...and rows in the target that don't match the source.
SELECT product_id, product_name, price FROM products_copy
EXCEPT
SELECT product_id, product_name, price FROM products;         -- id 12 (wrong price)

DROP TABLE products_copy;
