-- =============================================================================
-- 02_medium/08 · Advanced DML — SOLUTIONS
-- =============================================================================

BEGIN;


-- Q1. LEFT JOIN from products so unsold products get a row with zeros.
CREATE TEMP TABLE product_sales (
    product_id INT PRIMARY KEY,
    units      INT NOT NULL,
    revenue    NUMERIC(12,2) NOT NULL
);

INSERT INTO product_sales (product_id, units, revenue)
SELECT p.product_id,
       COALESCE(SUM(oi.quantity), 0),
       COALESCE(ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2), 0)
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY p.product_id;                                         -- INSERT 0 24

SELECT COUNT(*) FILTER (WHERE units = 0) AS unsold FROM product_sales;   -- 4


-- Q2. Same SELECT; every product_id already exists -> all skipped.
INSERT INTO product_sales (product_id, units, revenue)
SELECT p.product_id,
       COALESCE(SUM(oi.quantity), 0),
       COALESCE(ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2), 0)
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY p.product_id
ON CONFLICT (product_id) DO NOTHING;                           -- INSERT 0 0


-- Q3. The WHERE on DO UPDATE skips rows whose values are identical (18).
INSERT INTO product_sales (product_id, units, revenue)
VALUES (5, 10, 250.00), (18, 7, 104.93), (99, 1, 10.00)
ON CONFLICT (product_id) DO UPDATE
    SET units   = EXCLUDED.units,
        revenue = EXCLUDED.revenue
    WHERE (product_sales.units, product_sales.revenue)
          IS DISTINCT FROM (EXCLUDED.units, EXCLUDED.revenue)   -- row-value comparison
RETURNING product_id, units, revenue, (xmax = 0) AS inserted;


-- Q4.
UPDATE products p
SET stock_qty = p.stock_qty - r.reserved
FROM (SELECT oi.product_id, SUM(oi.quantity) AS reserved
      FROM order_items oi
      JOIN orders o ON o.order_id = oi.order_id
      WHERE o.status = 'pending'
      GROUP BY oi.product_id) r
WHERE r.product_id = p.product_id
RETURNING p.product_name, p.stock_qty;


-- Q5. Source aggregated per employee (1:1 with the target). The extra
--     "employees old" in FROM exposes the pre-update salary for RETURNING.
UPDATE employees e
SET salary = e.salary + b.bonus
FROM (SELECT o.employee_id,
             ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) * 0.01, 2) AS bonus
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.order_id
      WHERE o.status = 'delivered'
      GROUP BY o.employee_id) b,
     employees old
WHERE b.employee_id = e.emp_id
  AND old.emp_id    = e.emp_id
  AND e.dept_id = 2
  AND e.is_active
RETURNING e.first_name, old.salary AS old_salary, e.salary AS new_salary;


-- Q6.
DELETE FROM order_items oi
USING orders o
WHERE o.order_id = oi.order_id
  AND o.status = 'cancelled'
RETURNING oi.*;


-- Q7. "old" CTE sees the pre-update snapshot; joining it to the UPDATE's
--     RETURNING gives both values. Everything is one atomic statement.
CREATE TEMP TABLE price_audit (
    product_id INT,
    old_price  NUMERIC(10,2),
    new_price  NUMERIC(10,2),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

WITH old AS (
    SELECT product_id, price FROM products WHERE category_id = 8
),
upd AS (
    UPDATE products
    SET price = ROUND(price * 1.10, 2)
    WHERE category_id = 8
    RETURNING product_id, price
)
INSERT INTO price_audit (product_id, old_price, new_price)
SELECT old.product_id, old.price, upd.price
FROM old
JOIN upd ON upd.product_id = old.product_id;

SELECT * FROM price_audit ORDER BY product_id;


ROLLBACK;
