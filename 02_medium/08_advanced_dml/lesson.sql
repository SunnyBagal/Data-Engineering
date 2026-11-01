-- =============================================================================
-- 02_medium/08 · Advanced DML — LESSON
-- Everything runs inside BEGIN ... ROLLBACK, so the shared data is unchanged.
-- =============================================================================

BEGIN;


-- -----------------------------------------------------------------------------
-- 1. INSERT ... SELECT: insert a query's result
-- -----------------------------------------------------------------------------

-- A summary table, filled from an aggregate query in one statement.
CREATE TEMP TABLE daily_revenue (
    day      DATE PRIMARY KEY,
    orders   INT NOT NULL,
    revenue  NUMERIC(12,2) NOT NULL
);

INSERT INTO daily_revenue (day, orders, revenue)          -- column list = safe mapping
SELECT o.order_date::date,
       COUNT(DISTINCT o.order_id),
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2)
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY o.order_date::date;                              -- INSERT 0 42

SELECT * FROM daily_revenue ORDER BY revenue DESC LIMIT 3;


-- -----------------------------------------------------------------------------
-- 2. ON CONFLICT DO NOTHING: idempotent inserts
-- -----------------------------------------------------------------------------

-- Re-running the same load must not fail or duplicate rows. Without ON CONFLICT,
-- the second run would raise "duplicate key value violates unique constraint".
INSERT INTO daily_revenue (day, orders, revenue)
SELECT o.order_date::date, COUNT(DISTINCT o.order_id), 0
FROM orders o
GROUP BY o.order_date::date
ON CONFLICT (day) DO NOTHING;              -- only days not yet present are inserted (3 cancelled-only days)


-- -----------------------------------------------------------------------------
-- 3. UPSERT: ON CONFLICT DO UPDATE
-- -----------------------------------------------------------------------------

-- A supplier price feed: product 5 and 6 exist (update), 25 is new (insert).
INSERT INTO products (product_id, product_name, category_id, price, cost, stock_qty, created_at)
VALUES (5,  'Wireless Mouse',      4, 27.00, 8.00,  0, CURRENT_DATE),
       (6,  'Mechanical Keyboard', 4, 89.99, 40.00, 0, CURRENT_DATE),   -- same price: no-op
       (25, 'Gaming Headset',     12, 79.00, 35.00, 0, CURRENT_DATE)
ON CONFLICT (product_id)                       -- the conflict target: a unique/PK column
DO UPDATE SET price = EXCLUDED.price,          -- EXCLUDED = the proposed (rejected) row
              cost  = EXCLUDED.cost
WHERE products.price IS DISTINCT FROM EXCLUDED.price   -- skip rows where nothing changed
   OR products.cost  IS DISTINCT FROM EXCLUDED.cost
RETURNING product_id, product_name, price,
          (xmax = 0) AS inserted;              -- Postgres trick: xmax = 0 -> row was inserted
-- 2 rows returned: product 5 (updated) and 25 (inserted). Product 6 was skipped.
-- Note: stock_qty/created_at of existing rows are untouched — only SET columns change.

-- Keep the identity sequence in sync after inserting an explicit id.
SELECT setval(pg_get_serial_sequence('products', 'product_id'), (SELECT MAX(product_id) FROM products));


-- -----------------------------------------------------------------------------
-- 4. UPDATE ... FROM: update using other tables
-- -----------------------------------------------------------------------------

-- Reserve stock for pending orders: subtract the quantities on pending orders.
-- Aggregate the source FIRST so each product matches exactly one source row.
UPDATE products p
SET stock_qty = p.stock_qty - r.reserved
FROM (
    SELECT oi.product_id, SUM(oi.quantity) AS reserved
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.status = 'pending'
    GROUP BY oi.product_id
) AS r
WHERE r.product_id = p.product_id               -- the join condition
RETURNING p.product_id, p.product_name, p.stock_qty;   -- 3 products

-- Department budgets = 120% of current active payroll (Research has no staff,
-- so it has no source row and is left untouched).
UPDATE departments d
SET budget = ROUND(s.payroll * 1.2, 2)
FROM (SELECT dept_id, SUM(salary) AS payroll
      FROM employees WHERE is_active AND dept_id IS NOT NULL
      GROUP BY dept_id) s
WHERE s.dept_id = d.dept_id
RETURNING d.dept_name, d.budget;                -- 5 rows

-- Same with a correlated subquery (portable). WITHOUT the EXISTS guard,
-- Research would be set to NULL (subquery returns no row -> NULL).
UPDATE departments d
SET location = (SELECT MIN(c.city) FROM customers c WHERE c.city = d.location)
WHERE EXISTS (SELECT 1 FROM customers c WHERE c.city = d.location);


-- -----------------------------------------------------------------------------
-- 5. RETURNING old AND new values: the self-join trick
-- -----------------------------------------------------------------------------

-- RETURNING shows the NEW row. Joining the table to itself in FROM gives
-- access to the row as it was BEFORE the update (same statement snapshot).
UPDATE products p
SET price = ROUND(p.price * 1.10, 2)
FROM products old
WHERE old.product_id = p.product_id
  AND p.category_id = 7                         -- Appliances
RETURNING p.product_name, old.price AS old_price, p.price AS new_price;


-- -----------------------------------------------------------------------------
-- 6. DELETE ... USING: delete based on other tables
-- -----------------------------------------------------------------------------

-- Remove the lines of cancelled orders (keeping the order headers).
DELETE FROM order_items oi
USING orders o
WHERE o.order_id = oi.order_id
  AND o.status = 'cancelled'
RETURNING oi.order_id, oi.product_id;           -- 3 lines

-- Equivalent, portable form with a subquery:
-- DELETE FROM order_items WHERE order_id IN (SELECT order_id FROM orders WHERE status = 'cancelled');


-- -----------------------------------------------------------------------------
-- 7. Writable CTEs: several changes, one atomic statement
-- -----------------------------------------------------------------------------

CREATE TEMP TABLE price_history (
    product_id INT,
    old_price  NUMERIC(10,2),
    new_price  NUMERIC(10,2),
    changed_at TIMESTAMPTZ DEFAULT now()
);

-- "old" reads the table BEFORE the update (all parts share one snapshot),
-- "upd" applies the change, the INSERT logs both values.
WITH old AS (
    SELECT product_id, price FROM products WHERE category_id = 8
),
upd AS (
    UPDATE products SET price = price - 5
    WHERE category_id = 8
    RETURNING product_id, price
)
INSERT INTO price_history (product_id, old_price, new_price)
SELECT old.product_id, old.price, upd.price
FROM old JOIN upd USING (product_id);

SELECT * FROM price_history;


-- -----------------------------------------------------------------------------
-- 8. MERGE (PostgreSQL 15+, SQL Server, Oracle) — shown for reference
-- -----------------------------------------------------------------------------
-- This course's minimum is Postgres 13, so MERGE is commented out. On PG 15+
-- you can run it as-is (inside this transaction).
--
-- MERGE INTO products AS t
-- USING (VALUES (7,  39.00, false),
--               (15, 499.00, true),
--               (26, 15.00, false)) AS s(product_id, price, drop_it)
--   ON t.product_id = s.product_id
-- WHEN MATCHED AND s.drop_it THEN
--     UPDATE SET is_discontinued = TRUE
-- WHEN MATCHED THEN
--     UPDATE SET price = s.price
-- WHEN NOT MATCHED THEN
--     INSERT (product_id, product_name, category_id, price, created_at)
--     VALUES (s.product_id, 'New item', 4, s.price, CURRENT_DATE);


ROLLBACK;     -- undo everything
SELECT COUNT(*) AS products_after_rollback FROM products;   -- 24
