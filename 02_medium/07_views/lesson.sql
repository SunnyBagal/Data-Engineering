-- =============================================================================
-- 02_medium/07 · Views — LESSON
-- Views are created in a separate schema "reporting" (a common real-world
-- convention) which is dropped at the end to keep the database clean.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS reporting;


-- -----------------------------------------------------------------------------
-- 1. Create and use a view
-- -----------------------------------------------------------------------------

-- The revenue formula now lives in ONE place. Every report that needs order
-- totals selects from this view instead of re-typing (and mistyping) it.
CREATE VIEW reporting.v_order_totals AS
SELECT o.order_id,
       o.customer_id,
       o.order_date,
       o.status,
       COUNT(*)                                                       AS line_count,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2) AS total
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;                  -- order_id is the PK: other o.* columns are allowed

-- Query it exactly like a table.
SELECT * FROM reporting.v_order_totals ORDER BY total DESC LIMIT 3;   -- 33, 21, 45

-- Filters added outside are pushed INTO the view's query by the planner,
-- so this does not compute all 46 totals first.
SELECT * FROM reporting.v_order_totals WHERE order_id = 6;


-- -----------------------------------------------------------------------------
-- 2. Views built on views (layers)
-- -----------------------------------------------------------------------------

-- Customer summary uses v_order_totals. LEFT JOIN keeps customers without orders.
CREATE VIEW reporting.v_customer_summary AS
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name                              AS customer,
       c.country,
       COUNT(t.order_id) FILTER (WHERE t.status <> 'cancelled')        AS orders,
       COALESCE(SUM(t.total) FILTER (WHERE t.status NOT IN ('cancelled', 'returned')), 0) AS lifetime_value,
       MAX(t.order_date)                                               AS last_order_at
FROM customers c
LEFT JOIN reporting.v_order_totals t ON t.customer_id = c.customer_id
GROUP BY c.customer_id;

SELECT * FROM reporting.v_customer_summary ORDER BY lifetime_value DESC LIMIT 5;

-- Analysts can now answer questions in one short line:
SELECT country, ROUND(AVG(lifetime_value), 2) AS avg_ltv
FROM reporting.v_customer_summary
GROUP BY country
ORDER BY avg_ltv DESC;


-- -----------------------------------------------------------------------------
-- 3. Views for security / simplification: hide columns
-- -----------------------------------------------------------------------------

-- A staff directory WITHOUT salary. Grant users access to this view instead
-- of the employees table (GRANT/REVOKE: 03_hard/11).
CREATE VIEW reporting.v_staff_directory AS
SELECT e.emp_id,
       e.first_name || ' ' || e.last_name             AS name,
       e.email,
       e.job_title,
       d.dept_name,
       m.first_name || ' ' || m.last_name             AS manager
FROM employees e
LEFT JOIN departments d ON d.dept_id = e.dept_id
LEFT JOIN employees  m  ON m.emp_id  = e.manager_id
WHERE e.is_active;                                    -- soft-deleted staff are hidden

SELECT * FROM reporting.v_staff_directory ORDER BY dept_name NULLS FIRST, name;


-- -----------------------------------------------------------------------------
-- 4. Updatable views and WITH CHECK OPTION
-- -----------------------------------------------------------------------------

-- Simple view (one table, no aggregates/joins) -> automatically updatable.
CREATE VIEW reporting.v_in_stock_products AS
SELECT product_id, product_name, price, stock_qty
FROM products
WHERE stock_qty > 0
WITH CHECK OPTION;          -- writes through the view must stay visible in the view

BEGIN;
-- This UPDATE goes through the view to the products table.
UPDATE reporting.v_in_stock_products SET price = price + 1 WHERE product_id = 5;
SELECT product_id, price FROM products WHERE product_id = 5;          -- 26.00 in the base table

-- Setting stock to 0 would make the row vanish from the view -> rejected:
-- UPDATE reporting.v_in_stock_products SET stock_qty = 0 WHERE product_id = 5;
--   ERROR: new row violates check option for view "v_in_stock_products"
ROLLBACK;

-- Views with joins/aggregates are NOT auto-updatable:
-- UPDATE reporting.v_order_totals SET total = 0 WHERE order_id = 1;
--   ERROR: cannot update view "v_order_totals" ... Views containing GROUP BY are not automatically updatable


-- -----------------------------------------------------------------------------
-- 5. Changing a view: CREATE OR REPLACE and its limits
-- -----------------------------------------------------------------------------

-- Allowed: same columns in the same order, new columns appended at the END.
CREATE OR REPLACE VIEW reporting.v_in_stock_products AS
SELECT product_id, product_name, price, stock_qty,
       price * stock_qty AS stock_value                  -- new column at the end
FROM products
WHERE stock_qty > 0
WITH CHECK OPTION;

-- Not allowed: renaming/removing/reordering existing columns.
-- CREATE OR REPLACE VIEW reporting.v_in_stock_products AS
-- SELECT product_id, product_name AS name, price, stock_qty FROM products WHERE stock_qty > 0;
--   ERROR: cannot change name of view column "product_name" to "name"
-- -> DROP VIEW and CREATE VIEW again instead.


-- -----------------------------------------------------------------------------
-- 6. The SELECT * trap
-- -----------------------------------------------------------------------------

-- "*" is expanded to the column list when the view is CREATED.
CREATE VIEW reporting.v_departments_all AS SELECT * FROM departments;
BEGIN;
ALTER TABLE departments ADD COLUMN cost_center TEXT;  -- new column on the table...
SELECT * FROM reporting.v_departments_all LIMIT 1;    -- ...not in the view (4 columns)
ROLLBACK;


-- -----------------------------------------------------------------------------
-- 7. Dependencies
-- -----------------------------------------------------------------------------

-- Views depend on their base tables and on each other.
-- ALTER TABLE order_items ALTER COLUMN discount TYPE NUMERIC(5,3);
--   ERROR: cannot alter type of a column used by a view or rule
-- DROP VIEW reporting.v_order_totals;
--   ERROR: cannot drop view v_order_totals because other objects depend on it
--   DETAIL: view reporting.v_customer_summary depends on view reporting.v_order_totals

-- List views and their definitions (metadata).
SELECT table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'reporting'
ORDER BY view_name;

SELECT pg_get_viewdef('reporting.v_order_totals'::regclass, true) AS definition;


-- -----------------------------------------------------------------------------
-- Clean up
-- -----------------------------------------------------------------------------
DROP SCHEMA reporting CASCADE;        -- drops every view inside it
