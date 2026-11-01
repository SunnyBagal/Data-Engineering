-- =============================================================================
-- 01_easy/09 · ORDER BY & LIMIT — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Basic sorting
-- -----------------------------------------------------------------------------

-- ASC is the default (cheapest first). Writing it is optional but explicit.
SELECT product_name, price FROM products ORDER BY price ASC;

-- DESC: most expensive first.
SELECT product_name, price FROM products ORDER BY price DESC;

-- Text sorts alphabetically; dates chronologically.
SELECT last_name, first_name FROM customers ORDER BY last_name;
SELECT first_name, hire_date FROM employees ORDER BY hire_date;


-- -----------------------------------------------------------------------------
-- 2. Multiple sort keys — direction is PER column
-- -----------------------------------------------------------------------------

-- Country A→Z, and within each country, newest signup first.
SELECT country, first_name, signup_date
FROM customers
ORDER BY country ASC, signup_date DESC;

-- Department, then highest salary first, then name as a final tie-breaker.
SELECT dept_id, salary, last_name
FROM employees
ORDER BY dept_id, salary DESC, last_name;


-- -----------------------------------------------------------------------------
-- 3. Sorting by expressions, aliases and (avoid!) positions
-- -----------------------------------------------------------------------------

-- By an alias: allowed because ORDER BY runs after SELECT.
SELECT product_name, price - cost AS margin
FROM products
ORDER BY margin DESC;

-- By an expression that isn't even in the SELECT list.
SELECT product_name FROM products ORDER BY price * stock_qty DESC;   -- by inventory value

-- By position: "2" = second column. Works, but breaks silently if someone
-- edits the SELECT list. Fine for ad-hoc queries, avoid in saved code.
SELECT product_name, price FROM products ORDER BY 2 DESC;


-- -----------------------------------------------------------------------------
-- 4. NULLs in sorting
-- -----------------------------------------------------------------------------

-- Postgres: NULL counts as "largest" -> last in ASC, first in DESC.
SELECT dept_name, budget FROM departments ORDER BY budget;          -- Research last
SELECT dept_name, budget FROM departments ORDER BY budget DESC;     -- Research FIRST (surprise!)

-- Be explicit so the query behaves the same on every database.
SELECT dept_name, budget FROM departments ORDER BY budget DESC NULLS LAST;

-- Unshipped orders first, then by date — e.g. an operations to-do list.
SELECT order_id, status, shipped_date
FROM orders
ORDER BY shipped_date NULLS FIRST, order_id;


-- -----------------------------------------------------------------------------
-- 5. LIMIT / FETCH FIRST: top-N queries
-- -----------------------------------------------------------------------------

-- The 3 most expensive products.
SELECT product_name, price FROM products ORDER BY price DESC LIMIT 3;

-- Standard-SQL spelling of the same thing (also works in Oracle, SQL Server 2012+).
SELECT product_name, price FROM products ORDER BY price DESC FETCH FIRST 3 ROWS ONLY;

-- The single most recent order (a "row of the maximum" — more useful than MAX(),
-- which only gives the date, not the rest of the row).
SELECT order_id, customer_id, order_date FROM orders ORDER BY order_date DESC LIMIT 1;

-- WITH TIES: the 9 best-paid employees, plus anyone tied with the 9th.
-- Two engineers both earn 95,000 -> 10 rows, nobody unfairly cut off.
SELECT first_name, last_name, salary
FROM employees
ORDER BY salary DESC
FETCH FIRST 9 ROWS WITH TIES;

-- LIMIT without ORDER BY = "any 3 rows". Never rely on it for meaning.
SELECT product_name FROM products LIMIT 3;


-- -----------------------------------------------------------------------------
-- 6. OFFSET pagination
-- -----------------------------------------------------------------------------

-- Page size 10. Page 1 = OFFSET 0, page 2 = OFFSET 10, page 3 = OFFSET 20.
-- order_id is unique, so the order is fully deterministic.
SELECT order_id, order_date FROM orders ORDER BY order_id LIMIT 10 OFFSET 0;
SELECT order_id, order_date FROM orders ORDER BY order_id LIMIT 10 OFFSET 10;
SELECT order_id, order_date FROM orders ORDER BY order_id LIMIT 10 OFFSET 20;

-- Non-deterministic pagination bug: many products share the same category,
-- so "ORDER BY category_id" alone gives an arbitrary order inside a category,
-- and pages may overlap. Always append a unique key as a tie-breaker:
SELECT product_id, category_id FROM products
ORDER BY category_id, product_id            -- product_id = tie-breaker
LIMIT 5 OFFSET 5;


-- -----------------------------------------------------------------------------
-- 7. Keyset (seek) pagination — fast at any depth
-- -----------------------------------------------------------------------------

-- The client remembers the last row of the previous page: (2024-07-01 08:15, 28).
-- Row-value comparison (a, b) > (x, y) means a > x OR (a = x AND b > y).
-- With an index on (order_date, order_id) this jumps directly to the right spot,
-- instead of reading and discarding OFFSET rows.
SELECT order_id, order_date
FROM orders
WHERE (order_date, order_id) > ('2024-07-01 08:15', 28)
ORDER BY order_date, order_id
LIMIT 5;                                     -- orders 29..33


-- -----------------------------------------------------------------------------
-- 8. Combining with WHERE and DISTINCT
-- -----------------------------------------------------------------------------

-- Cheapest product you can actually buy right now.
SELECT product_name, price
FROM products
WHERE stock_qty > 0 AND NOT is_discontinued
ORDER BY price
LIMIT 1;

-- Second-highest distinct unit price ever charged: DISTINCT first, then skip one.
SELECT DISTINCT unit_price
FROM order_items
ORDER BY unit_price DESC
LIMIT 1 OFFSET 1;                            -- 1500.00

-- Random sample of 3 customers (fine for small tables; sorts everything).
SELECT first_name, country FROM customers ORDER BY random() LIMIT 3;
