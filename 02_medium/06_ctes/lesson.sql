-- =============================================================================
-- 02_medium/06 · CTEs (WITH) — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. From nested subquery to CTE
-- -----------------------------------------------------------------------------

-- Average order value with a derived table: read inside-out.
SELECT ROUND(AVG(total), 2) AS avg_order_value
FROM (SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
      FROM order_items
      GROUP BY order_id) t;

-- Same with a CTE: read top-down, the step has a meaningful name.
WITH order_totals AS (
    SELECT order_id,
           SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items
    GROUP BY order_id
)
SELECT ROUND(AVG(total), 2) AS avg_order_value
FROM order_totals;


-- -----------------------------------------------------------------------------
-- 2. Chaining CTEs: each step can use the previous ones
-- -----------------------------------------------------------------------------

-- Customer tiers in readable steps:
--   order_totals  -> one row per order
--   customer_spend -> one row per customer (all customers, 0 if none)
--   tiered        -> add the tier label
WITH order_totals AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items
    GROUP BY order_id
),
customer_spend AS (
    SELECT c.customer_id,
           c.first_name || ' ' || c.last_name AS customer,
           COALESCE(SUM(ot.total), 0)         AS spend
    FROM customers c
    LEFT JOIN orders o        ON o.customer_id = c.customer_id
                             AND o.status NOT IN ('cancelled', 'returned')
    LEFT JOIN order_totals ot ON ot.order_id = o.order_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
tiered AS (
    SELECT customer, spend,
           CASE WHEN spend >= 3000 THEN 'gold'
                WHEN spend >= 1000 THEN 'silver'
                WHEN spend >  0    THEN 'bronze'
                ELSE                    'none' END AS tier
    FROM customer_spend
)
SELECT tier, COUNT(*) AS customers, ROUND(SUM(spend), 2) AS tier_spend
FROM tiered
GROUP BY tier
ORDER BY MIN(spend) DESC;                       -- gold, silver, bronze, none

-- Debugging tip: to inspect an intermediate step, just change the final line
-- to "SELECT * FROM customer_spend;".


-- -----------------------------------------------------------------------------
-- 3. Referencing a CTE more than once
-- -----------------------------------------------------------------------------

-- Each category's share of total revenue. The CTE is used twice: once for the
-- per-category rows, once for the grand total (a derived table would have to
-- be written out twice).
WITH category_revenue AS (
    SELECT cat.category_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM order_items oi
    JOIN products p     ON p.product_id    = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    GROUP BY cat.category_name
)
SELECT category_name,
       ROUND(revenue, 2)                                                    AS revenue,
       ROUND(100 * revenue / (SELECT SUM(revenue) FROM category_revenue), 1) AS pct_of_total
FROM category_revenue
ORDER BY revenue DESC;                          -- Laptops 55.8 %


-- -----------------------------------------------------------------------------
-- 4. Top-per-group without window functions (preview: 03_hard/01 does it better)
-- -----------------------------------------------------------------------------

-- Best-paid employee in each department.
WITH dept_max AS (
    SELECT dept_id, MAX(salary) AS max_salary
    FROM employees
    WHERE dept_id IS NOT NULL
    GROUP BY dept_id
)
SELECT d.dept_name, e.first_name, e.last_name, e.salary
FROM employees e
JOIN dept_max m    ON m.dept_id = e.dept_id AND m.max_salary = e.salary  -- ties would return both
JOIN departments d ON d.dept_id = e.dept_id
ORDER BY e.salary DESC;


-- -----------------------------------------------------------------------------
-- 5. Comparing against an aggregate computed once
-- -----------------------------------------------------------------------------

-- Months of 2024 whose revenue beat the 2024 monthly average.
WITH order_totals AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items GROUP BY order_id
),
monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(ot.total)                           AS revenue
    FROM orders o
    JOIN order_totals ot ON ot.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.order_date >= '2024-01-01' AND o.order_date < '2025-01-01'
    GROUP BY 1
),
stats AS (
    SELECT AVG(revenue) AS avg_revenue FROM monthly       -- one row
)
SELECT m.month, ROUND(m.revenue, 2) AS revenue, ROUND(s.avg_revenue, 2) AS avg_month
FROM monthly m
CROSS JOIN stats s                                         -- attach the single stats row
WHERE m.revenue > s.avg_revenue
ORDER BY m.month;                                          -- 5 months


-- -----------------------------------------------------------------------------
-- 6. MATERIALIZED / NOT MATERIALIZED (PostgreSQL 12+)
-- -----------------------------------------------------------------------------

-- Default: a CTE used once is inlined, so the filter on product_id can be
-- pushed down into the scan of order_items (uses the index).
EXPLAIN
WITH s AS (SELECT * FROM order_items)
SELECT * FROM s WHERE product_id = 5;

-- MATERIALIZED forces the whole CTE to be computed first, then filtered.
-- Useful when a CTE is expensive and referenced many times, or to stop the
-- planner from choosing a bad plan. Compare the two plans.
EXPLAIN
WITH s AS MATERIALIZED (SELECT * FROM order_items)
SELECT * FROM s WHERE product_id = 5;


-- -----------------------------------------------------------------------------
-- 7. Data-modifying CTEs: move rows in one atomic statement
-- -----------------------------------------------------------------------------

BEGIN;
CREATE TEMP TABLE orders_archive (LIKE orders);

-- DELETE ... RETURNING feeds the deleted rows straight into an INSERT.
-- Both happen in ONE statement: either both succeed or neither does.
-- (order_items of these orders go too, via ON DELETE CASCADE.)
WITH moved AS (
    DELETE FROM orders
    WHERE status = 'cancelled'
    RETURNING *
)
INSERT INTO orders_archive
SELECT * FROM moved;

SELECT order_id, status FROM orders_archive;               -- 8, 15, 29
SELECT COUNT(*) AS orders_left FROM orders;                -- 43
ROLLBACK;                                                  -- undo the demo
