-- =============================================================================
-- 02_medium/07 · Views — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS bi;


-- Q1. The view keeps raw-ish detail; aggregation happens in the query using it.
CREATE VIEW bi.v_order_lines AS
SELECT o.order_id,
       o.order_date,
       o.status,
       o.customer_id,
       c.first_name || ' ' || c.last_name                        AS customer,
       p.product_name,
       cat.category_name,
       oi.quantity,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount), 2) AS revenue
FROM order_items oi
JOIN orders     o   ON o.order_id      = oi.order_id
JOIN customers  c   ON c.customer_id   = o.customer_id
JOIN products   p   ON p.product_id    = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id;

SELECT category_name, SUM(revenue) AS revenue
FROM bi.v_order_lines
WHERE status = 'delivered'
GROUP BY category_name
ORDER BY revenue DESC;
-- Note: rounding each line before summing can differ by a cent from summing
-- first and rounding once. Decide which your business wants and be consistent.


-- Q2. Layered views: lines -> orders -> customers.
CREATE VIEW bi.v_order_totals AS
SELECT order_id, customer_id, status, order_date, SUM(revenue) AS total
FROM bi.v_order_lines
GROUP BY order_id, customer_id, status, order_date;

CREATE VIEW bi.v_customer_ltv AS
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name                                        AS customer,
       c.country,
       COUNT(t.order_id) FILTER (WHERE t.status <> 'cancelled')                  AS orders,
       COALESCE(SUM(t.total) FILTER (WHERE t.status NOT IN ('cancelled', 'returned')), 0) AS lifetime_value,
       MIN(t.order_date)                                                         AS first_order_at,
       MAX(t.order_date)                                                         AS last_order_at
FROM customers c
LEFT JOIN bi.v_order_totals t ON t.customer_id = c.customer_id
GROUP BY c.customer_id;

SELECT customer, lifetime_value
FROM bi.v_customer_ltv
ORDER BY lifetime_value DESC
LIMIT 3;


-- Q3.
CREATE VIEW bi.v_org_chart AS
SELECT e.emp_id,
       e.first_name || ' ' || e.last_name AS name,
       e.job_title,
       COALESCE(d.dept_name, '—')         AS department,
       m.first_name || ' ' || m.last_name AS manager
FROM employees e
LEFT JOIN departments d ON d.dept_id = e.dept_id
LEFT JOIN employees  m  ON m.emp_id  = e.manager_id
WHERE e.is_active;

SELECT COUNT(*) FROM bi.v_org_chart;                           -- 19
SELECT department, COUNT(*) AS people
FROM bi.v_org_chart
GROUP BY department
ORDER BY people DESC;


-- Q4. One base table + simple WHERE -> automatically updatable.
CREATE VIEW bi.v_open_orders AS
SELECT order_id, customer_id, employee_id, order_date, status, shipped_date
FROM orders
WHERE status IN ('pending', 'shipped')
WITH CHECK OPTION;

SELECT COUNT(*) FROM bi.v_open_orders;                         -- 4 (43, 44, 45, 46)

BEGIN;
UPDATE bi.v_open_orders                                        -- a) still 'open' -> allowed
SET status = 'shipped', shipped_date = CURRENT_DATE
WHERE order_id = 45;
-- b) 'delivered' is outside the view's WHERE -> the row would disappear from
--    the view, which WITH CHECK OPTION forbids:
-- UPDATE bi.v_open_orders SET status = 'delivered' WHERE order_id = 45;
--   ERROR: new row violates check option for view "v_open_orders"
ROLLBACK;


-- Q5. Appending a column at the end is allowed.
CREATE OR REPLACE VIEW bi.v_open_orders AS
SELECT order_id, customer_id, employee_id, order_date, status, shipped_date,
       DATE '2025-11-01' - order_date::date AS days_open
FROM orders
WHERE status IN ('pending', 'shipped')
WITH CHECK OPTION;

-- Renaming an existing column is not:
-- CREATE OR REPLACE VIEW bi.v_open_orders AS
-- SELECT order_id, customer_id, employee_id, order_date, status AS order_status, ...
--   ERROR: cannot change name of view column "status" to "order_status"
-- CREATE OR REPLACE must keep existing columns (name, type, position) so that
-- objects depending on the view don't break. Use ALTER VIEW ... RENAME COLUMN,
-- or DROP + CREATE.
ALTER VIEW bi.v_open_orders RENAME COLUMN status TO order_status;   -- the supported way


-- Q6.
-- DROP VIEW bi.v_order_lines;
--   ERROR: cannot drop view bi.v_order_lines because other objects depend on it
--   DETAIL: view bi.v_order_totals depends on view bi.v_order_lines
--           view bi.v_customer_ltv depends on view bi.v_order_totals
-- Postgres tracks dependencies so you can't silently break downstream views.
SELECT table_name FROM information_schema.views WHERE table_schema = 'bi' ORDER BY 1;


-- Q7.
DROP SCHEMA bi CASCADE;
