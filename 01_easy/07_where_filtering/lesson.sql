-- =============================================================================
-- 01_easy/07 · WHERE — Filtering Rows — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Comparison operators
-- -----------------------------------------------------------------------------

SELECT product_name, price FROM products WHERE price > 500;          -- strictly greater
SELECT product_name, price FROM products WHERE price <= 25;          -- less or equal
SELECT first_name, country FROM customers WHERE country = 'India';   -- text equality is case-sensitive
SELECT first_name, country FROM customers WHERE country <> 'India';  -- <> is standard SQL; != also works

-- Booleans can be used directly; "= TRUE" is redundant.
SELECT first_name, last_name FROM employees WHERE NOT is_active;

-- Dates compare chronologically (a typed column, not text!).
SELECT first_name, hire_date FROM employees WHERE hire_date < '2017-01-01';


-- -----------------------------------------------------------------------------
-- 2. AND, OR, NOT — and why parentheses matter
-- -----------------------------------------------------------------------------

-- AND: both conditions must be true.
SELECT first_name, salary FROM employees
WHERE dept_id = 1 AND salary > 100000;

-- OR: at least one must be true.
SELECT product_name, stock_qty, is_discontinued FROM products
WHERE stock_qty = 0 OR is_discontinued;

-- PRECEDENCE BUG: intended "Indian or British customers who joined in 2023".
-- AND binds tighter than OR, so this is: India (any year) OR (UK AND 2023).
SELECT first_name, country, signup_date FROM customers
WHERE country = 'India' OR country = 'UK'
  AND signup_date >= '2023-01-01' AND signup_date < '2024-01-01';     -- 10 rows: WRONG

-- Fixed with parentheses...
SELECT first_name, country, signup_date FROM customers
WHERE (country = 'India' OR country = 'UK')
  AND signup_date >= '2023-01-01' AND signup_date < '2024-01-01';     -- 5 rows: right

-- ...or, cleaner, with IN (no OR at all -> no precedence trap).
SELECT first_name, country, signup_date FROM customers
WHERE country IN ('India', 'UK')
  AND signup_date >= '2023-01-01' AND signup_date < '2024-01-01';


-- -----------------------------------------------------------------------------
-- 3. IN / NOT IN
-- -----------------------------------------------------------------------------

-- Shorter and clearer than status = 'shipped' OR status = 'pending'.
SELECT order_id, status FROM orders WHERE status IN ('shipped', 'pending');

SELECT order_id, status FROM orders WHERE status NOT IN ('delivered', 'cancelled');

-- IN with numbers: orders handled by two specific sales reps.
SELECT order_id, employee_id FROM orders WHERE employee_id IN (11, 12);


-- -----------------------------------------------------------------------------
-- 4. BETWEEN — inclusive on BOTH ends
-- -----------------------------------------------------------------------------

SELECT product_name, price FROM products
WHERE price BETWEEN 39.50 AND 89.99;           -- includes 39.50 and 89.99 themselves

-- Same thing, explicit. Use this form when you want to be unambiguous.
SELECT product_name, price FROM products
WHERE price >= 39.50 AND price <= 89.99;

-- THE TIMESTAMP TRAP: orders on Black Friday 2023 (2023-11-24).
-- '2023-11-24' as a timestamp means 2023-11-24 00:00:00, so this asks for
-- orders between midnight and midnight -> 0 rows, although 2 exist.
SELECT order_id, order_date FROM orders
WHERE order_date BETWEEN '2023-11-24' AND '2023-11-24';             -- 0 rows!

-- Half-open range: from the start of the day, up to (not including) the next day.
SELECT order_id, order_date FROM orders
WHERE order_date >= '2023-11-24' AND order_date < '2023-11-25';     -- 2 rows

-- Same idea for a whole year: works for DATE and TIMESTAMP, and uses indexes.
SELECT COUNT(*) AS orders_2024 FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';


-- -----------------------------------------------------------------------------
-- 5. Pattern matching: LIKE, ILIKE, regex
-- -----------------------------------------------------------------------------

SELECT product_name FROM products WHERE product_name LIKE 'S%';       -- starts with S
SELECT product_name FROM products WHERE product_name LIKE '%Laptop';  -- ends with Laptop
SELECT product_name FROM products WHERE product_name LIKE '%Phone%';  -- contains (case-sensitive): 3
SELECT product_name FROM products WHERE product_name ILIKE '%phone%'; -- case-insensitive: 4 (Headphones too)

-- _ matches exactly one character: last names of exactly 4 letters.
SELECT last_name FROM customers WHERE last_name LIKE '____';

-- Escaping a literal % or _ : find job titles containing an underscore (none) safely.
SELECT job_title FROM employees WHERE job_title LIKE '%\_%';

-- Regular expressions (Postgres ~ operator) for patterns LIKE can't express:
-- phone numbers that start with +1 or +44.
SELECT first_name, phone FROM customers WHERE phone ~ '^\+(1|44)-';


-- -----------------------------------------------------------------------------
-- 6. Filtering on expressions — and keeping it sargable
-- -----------------------------------------------------------------------------

-- Works, but wraps the column in a function -> an index on order_date can't be used.
SELECT COUNT(*) FROM orders WHERE EXTRACT(YEAR FROM order_date) = 2024;

-- Same result, column left "bare" -> index-friendly. Prefer this form.
SELECT COUNT(*) FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';

-- Filtering on a computed value: line items worth more than 1000.
SELECT order_id, product_id, quantity * unit_price * (1 - discount) AS revenue
FROM order_items
WHERE quantity * unit_price * (1 - discount) > 1000;    -- can't use the alias here

-- Filtering on JSON (preview of 03_hard/10): ->> extracts a field as text.
SELECT product_name FROM products WHERE attributes ->> 'brand' = 'Lumen';


-- -----------------------------------------------------------------------------
-- 7. WHERE in UPDATE / DELETE (preview with SELECT, then change, then undo)
-- -----------------------------------------------------------------------------

BEGIN;
SELECT product_id, stock_qty FROM products WHERE stock_qty = 0 AND NOT is_discontinued;
UPDATE products SET stock_qty = 10 WHERE stock_qty = 0 AND NOT is_discontinued;   -- UPDATE 3
ROLLBACK;
