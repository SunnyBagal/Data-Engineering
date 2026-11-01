-- =============================================================================
-- 02_medium/12 · Conditional Aggregation & Pivoting — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Long format: what GROUP BY gives you
-- -----------------------------------------------------------------------------

-- One row per (year, status): correct, but hard to compare years at a glance.
SELECT EXTRACT(YEAR FROM order_date)::int AS year, status, COUNT(*) AS orders
FROM orders
GROUP BY 1, 2
ORDER BY 1, 2;


-- -----------------------------------------------------------------------------
-- 2. Pivot with FILTER: one column per status
-- -----------------------------------------------------------------------------

-- GROUP BY the row dimension (year); one conditional COUNT per column.
-- All columns are computed in ONE scan of orders.
SELECT EXTRACT(YEAR FROM order_date)::int                         AS year,
       COUNT(*)                                                   AS total,
       COUNT(*) FILTER (WHERE status = 'delivered')               AS delivered,
       COUNT(*) FILTER (WHERE status = 'cancelled')               AS cancelled,
       COUNT(*) FILTER (WHERE status = 'returned')                AS returned,
       COUNT(*) FILTER (WHERE status IN ('pending', 'shipped'))   AS open
FROM orders
GROUP BY 1
ORDER BY 1;


-- -----------------------------------------------------------------------------
-- 3. The portable version: aggregates over CASE
-- -----------------------------------------------------------------------------

-- Same result in MySQL / SQL Server / Oracle / any database.
SELECT EXTRACT(YEAR FROM order_date)::int                        AS year,
       SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END)     AS delivered,
       SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END)     AS cancelled,
       COUNT(CASE WHEN status = 'returned' THEN 1 END)           AS returned   -- no ELSE: NULLs aren't counted
FROM orders
GROUP BY 1
ORDER BY 1;

-- TRAP: ELSE 0 inside COUNT counts EVERY row (0 is not NULL).
SELECT COUNT(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) AS wrong_returned   -- 46!
FROM orders;


-- -----------------------------------------------------------------------------
-- 4. Pivoting sums: revenue by category (rows) x year (columns)
-- -----------------------------------------------------------------------------

WITH lines AS (
    SELECT cat.category_name,
           o.order_date,
           oi.quantity * oi.unit_price * (1 - oi.discount) AS revenue
    FROM order_items oi
    JOIN orders o       ON o.order_id = oi.order_id
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.status <> 'cancelled'
)
SELECT category_name,
       ROUND(SUM(revenue) FILTER (WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'), 2) AS y2023,
       ROUND(SUM(revenue) FILTER (WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'), 2) AS y2024,
       ROUND(SUM(revenue) FILTER (WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'), 2) AS y2025,
       ROUND(SUM(revenue), 2)                                                                       AS total
FROM lines
GROUP BY category_name
ORDER BY total DESC;


-- -----------------------------------------------------------------------------
-- 5. Ratios inside a group
-- -----------------------------------------------------------------------------

-- Problem-order rate per sales rep: cancelled + returned as % of their orders.
-- 100.0 forces decimal division.
SELECT e.first_name || ' ' || e.last_name                                         AS rep,
       COUNT(*)                                                                   AS orders,
       COUNT(*) FILTER (WHERE o.status IN ('cancelled', 'returned'))              AS problems,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.status IN ('cancelled', 'returned'))
             / COUNT(*), 1)                                                       AS problem_rate_pct
FROM orders o
JOIN employees e ON e.emp_id = o.employee_id
GROUP BY e.emp_id, e.first_name, e.last_name
ORDER BY problem_rate_pct DESC;

-- Share of each payment method per year, as columns.
SELECT EXTRACT(YEAR FROM paid_at)::int AS year,
       SUM(amount)                     AS total,
       ROUND(100 * SUM(amount) FILTER (WHERE method = 'card') / SUM(amount), 1) AS card_pct,
       ROUND(100 * SUM(amount) FILTER (WHERE method = 'upi')  / SUM(amount), 1) AS upi_pct,
       ROUND(100 * COALESCE(SUM(amount) FILTER (WHERE method NOT IN ('card', 'upi')), 0)
             / SUM(amount), 1)                                                   AS other_pct
FROM payments
GROUP BY 1
ORDER BY 1;


-- -----------------------------------------------------------------------------
-- 6. NULL vs 0 in pivots
-- -----------------------------------------------------------------------------

-- FILTER over no matching rows -> NULL; SUM(CASE ... ELSE 0) -> 0.
SELECT EXTRACT(YEAR FROM paid_at)::int                              AS year,
       SUM(amount) FILTER (WHERE method = 'cash')                   AS cash_filter,   -- NULL in 2025
       SUM(CASE WHEN method = 'cash' THEN amount ELSE 0 END)        AS cash_case,     -- 0 in 2025
       COALESCE(SUM(amount) FILTER (WHERE method = 'cash'), 0)      AS cash_coalesce  -- 0 in 2025
FROM payments
GROUP BY 1
ORDER BY 1;


-- -----------------------------------------------------------------------------
-- 7. Multi-metric "one row per entity" (feature table)
-- -----------------------------------------------------------------------------

-- One row per customer with many conditional metrics — typical input for
-- dashboards or ML models.
SELECT c.customer_id,
       c.first_name,
       COUNT(o.order_id)                                              AS orders,
       COUNT(o.order_id) FILTER (WHERE o.status = 'cancelled')        AS cancelled,
       COUNT(o.order_id) FILTER (WHERE o.employee_id IS NULL)         AS online_orders,
       COUNT(o.order_id) FILTER (WHERE EXTRACT(ISODOW FROM o.order_date) IN (6, 7)) AS weekend_orders,
       MAX(o.order_date)                                              AS last_order
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY orders DESC;


-- -----------------------------------------------------------------------------
-- 8. Unpivot: columns back into rows
-- -----------------------------------------------------------------------------

-- Start from a wide result (as if it came from a spreadsheet)...
WITH wide AS (
    SELECT EXTRACT(YEAR FROM order_date)::int             AS year,
           COUNT(*) FILTER (WHERE status = 'delivered')   AS delivered,
           COUNT(*) FILTER (WHERE status = 'cancelled')   AS cancelled,
           COUNT(*) FILTER (WHERE status = 'returned')    AS returned
    FROM orders GROUP BY 1
)
-- ...and turn each column into a row. LATERAL lets the VALUES list refer to
-- the current row of "wide" (more on LATERAL in 03_hard/04).
SELECT w.year, v.status, v.orders
FROM wide w
CROSS JOIN LATERAL (VALUES ('delivered', w.delivered),
                           ('cancelled', w.cancelled),
                           ('returned',  w.returned)) AS v(status, orders)
ORDER BY w.year, v.status;

-- Portable unpivot with UNION ALL (one SELECT per column).
WITH wide AS (
    SELECT EXTRACT(YEAR FROM order_date)::int AS year,
           COUNT(*) FILTER (WHERE status = 'delivered') AS delivered,
           COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled
    FROM orders GROUP BY 1
)
SELECT year, 'delivered' AS status, delivered AS orders FROM wide
UNION ALL
SELECT year, 'cancelled', cancelled FROM wide
ORDER BY year, status;
