-- =============================================================================
-- 01_easy/10 · Aggregate Functions — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. COUNT in its three forms
-- -----------------------------------------------------------------------------

SELECT COUNT(*)                    AS total_customers,      -- 20: every row
       COUNT(phone)                AS with_phone,           -- 13: non-NULL values only
       COUNT(DISTINCT country)     AS countries             -- 5: unique non-NULL values
FROM customers;

-- How many customers have actually ordered? Count unique ids in orders,
-- not rows (one customer has many orders).
SELECT COUNT(*)                     AS order_rows,          -- 46
       COUNT(DISTINCT customer_id)  AS ordering_customers,  -- 18
       COUNT(employee_id)           AS rep_assisted_orders  -- 31 (NULL = online)
FROM orders;


-- -----------------------------------------------------------------------------
-- 2. SUM, AVG, MIN, MAX
-- -----------------------------------------------------------------------------

-- Sales KPIs over all order lines.
SELECT SUM(quantity)                                         AS units_sold,       -- 95
       ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS total_revenue,    -- 31730.52
       ROUND(AVG(quantity * unit_price * (1 - discount)), 2) AS avg_line_revenue, -- 406.80
       MAX(unit_price)                                       AS max_unit_price,
       MIN(unit_price)                                       AS min_unit_price
FROM order_items;
-- Aggregates take expressions, not just columns: the revenue formula is computed
-- per row, then summed.

-- MIN / MAX work on dates and text too.
SELECT MIN(hire_date)  AS first_hire,
       MAX(hire_date)  AS latest_hire,
       MIN(last_name)  AS alphabetically_first   -- 'Brown'
FROM employees;

-- WHERE filters rows BEFORE aggregation: payroll of active staff only.
SELECT COUNT(*)              AS active_staff,     -- 19
       SUM(salary)           AS payroll,          -- 2,090,000
       ROUND(AVG(salary), 2) AS avg_salary,       -- 110,000
       MAX(salary) - MIN(salary) AS salary_spread -- arithmetic between aggregates
FROM employees
WHERE is_active;


-- -----------------------------------------------------------------------------
-- 3. Average vs median
-- -----------------------------------------------------------------------------

-- PERCENTILE_CONT is an "ordered-set aggregate": it needs the values sorted.
-- The CEO's salary pulls the average far above what a typical employee earns.
SELECT ROUND(AVG(salary), 2)                                 AS average,   -- 110000
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)   AS median,    -- 95000
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY salary)   AS p90,
       MODE() WITHIN GROUP (ORDER BY salary)                 AS most_common
FROM employees
WHERE is_active;


-- -----------------------------------------------------------------------------
-- 4. NULLs and empty inputs
-- -----------------------------------------------------------------------------

-- AVG ignores the NULL budget (Research): average of 5 values, not 6.
SELECT AVG(budget) AS avg_known, COUNT(budget) AS n_known FROM departments;

-- SUM over ZERO rows returns NULL, COUNT returns 0. A classic report bug:
-- "total paid for order 999" should be 0, not empty.
SELECT SUM(amount)              AS raw_sum,      -- NULL
       COALESCE(SUM(amount), 0) AS safe_sum,     -- 0
       COUNT(*)                 AS n             -- 0
FROM payments
WHERE order_id = 999;


-- -----------------------------------------------------------------------------
-- 5. Collecting values: STRING_AGG, ARRAY_AGG, BOOL_AND / BOOL_OR
-- -----------------------------------------------------------------------------

-- One comma-separated string; ORDER BY inside makes the output deterministic.
SELECT STRING_AGG(DISTINCT country, ', ' ORDER BY country) AS countries
FROM customers;

-- An array of values (Postgres). Useful for passing lists to applications.
SELECT ARRAY_AGG(product_name ORDER BY price DESC) AS laptops_by_price
FROM products
WHERE category_id = 3;

-- Are ALL products sold above cost? Is ANY product out of stock?
SELECT BOOL_AND(price > cost)   AS all_profitable,   -- true
       BOOL_OR(stock_qty = 0)   AS any_out_of_stock  -- true
FROM products;


-- -----------------------------------------------------------------------------
-- 6. FILTER: several conditional aggregates in ONE scan of the table
-- -----------------------------------------------------------------------------

SELECT COUNT(*)                                         AS all_orders,
       COUNT(*) FILTER (WHERE status = 'delivered')     AS delivered,
       COUNT(*) FILTER (WHERE status = 'cancelled')     AS cancelled,
       COUNT(*) FILTER (WHERE employee_id IS NULL)      AS online
FROM orders;

-- Same for sums: revenue paid by each method, side by side.
SELECT SUM(amount) FILTER (WHERE method = 'card')   AS card,
       SUM(amount) FILTER (WHERE method = 'upi')    AS upi,
       SUM(amount) FILTER (WHERE method = 'paypal') AS paypal,
       SUM(amount)                                  AS total
FROM payments;


-- -----------------------------------------------------------------------------
-- 7. Ratios built from aggregates
-- -----------------------------------------------------------------------------

-- Cancellation rate. Cast to numeric BEFORE dividing to avoid integer division.
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'cancelled') / COUNT(*), 2)
       AS cancellation_rate_pct                                  -- 6.52
FROM orders;

-- Average order value (AOV) = revenue / number of distinct orders.
SELECT ROUND(SUM(quantity * unit_price * (1 - discount))
             / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM order_items;


-- -----------------------------------------------------------------------------
-- 8. Things that DON'T work (and why)
-- -----------------------------------------------------------------------------

-- Mixing a plain column with an aggregate (no GROUP BY):
-- SELECT customer_id, COUNT(*) FROM orders;
--   ERROR: column "orders.customer_id" must appear in the GROUP BY clause
--   -> 46 different customer_ids but only one output row: which one to show? (topic 11)

-- Aggregate in WHERE:
-- SELECT * FROM products WHERE price > AVG(price);
--   ERROR: aggregate functions are not allowed in WHERE
--   -> fix with a subquery (02_medium/03):
SELECT product_name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products);
