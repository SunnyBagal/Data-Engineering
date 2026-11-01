-- =============================================================================
-- 01_easy/05 · INSERT, UPDATE, DELETE — SOLUTIONS
-- =============================================================================

BEGIN;   -- everything below is undone by the ROLLBACK at the end


-- Q1. JSONB literal is a string cast implicitly to jsonb; it is validated on insert.
INSERT INTO products (product_name, category_id, price, cost, stock_qty, attributes, created_at)
VALUES ('Gaming Mouse', 12, 59.90, 25, 40, '{"brand":"Clicko","dpi":16000}', CURRENT_DATE)
RETURNING product_id;                                       -- 25 on a fresh database


-- Q2. RETURNING shows the generated ids. Generated ids are NOT predictable:
--     identity values used by rolled-back transactions (e.g. if you ran the
--     lesson first) are skipped, so never hard-code "21" or "47".
--     currval() returns the value THIS session just generated for a sequence,
--     so it's safe even with other users inserting at the same time.
--     (Unlike SELECT MAX(id), which could return someone else's row.)
INSERT INTO customers (first_name, last_name, email, city, country, signup_date)
VALUES ('Tara', 'Menon', 'tara.menon@mail.com', 'Kochi', 'India', CURRENT_DATE)
RETURNING customer_id;                                      -- 21 on a fresh database

INSERT INTO orders (customer_id, employee_id, order_date, status)
VALUES (currval(pg_get_serial_sequence('customers', 'customer_id')),   -- Tara's new id
        NULL, now(), 'pending')                             -- NULL employee = online order
RETURNING order_id;                                         -- 47 on a fresh database

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount)
VALUES (currval(pg_get_serial_sequence('orders', 'order_id')),
        currval(pg_get_serial_sequence('products', 'product_id')), 1, 59.90, 0),   -- the Gaming Mouse
       (currval(pg_get_serial_sequence('orders', 'order_id')), 18, 2, 14.99, 0.05);  -- discount as a fraction
-- In application code you'd read the ids from RETURNING into variables;
-- 02_medium/06 shows how to chain all three inserts in one statement with CTEs.


-- Q3. Preview, then update with the identical WHERE.
SELECT product_id, product_name, price FROM products WHERE category_id = 8;

UPDATE products
SET price = ROUND(price * 0.85, 2)
WHERE category_id = 8
RETURNING product_name, price;                              -- 67.15 and 38.25


-- Q4.
UPDATE orders SET status = 'shipped', shipped_date = CURRENT_DATE WHERE order_id = 45;
UPDATE orders SET status = 'cancelled', shipped_date = NULL      WHERE order_id = 46;

-- UPDATE orders SET status = 'lost' WHERE order_id = 44;
--   ERROR: new row for relation "orders" violates check constraint "orders_status_check"


-- Q5. All SET expressions read the OLD row, so salary * 1.2 uses 60000.
UPDATE employees
SET dept_id   = 1,
    job_title = 'Software Engineer',
    salary    = salary * 1.20
WHERE emp_id = 20
RETURNING *;                                                -- salary 72000.00


-- Q6. A TIMESTAMP compared with a date literal: '2025-10-01' means midnight,
--     so "< '2025-10-01'" includes all of Sep 30.
SELECT * FROM logins WHERE device = 'android' AND login_at < '2025-10-01';

DELETE FROM logins
WHERE device = 'android' AND login_at < '2025-10-01'
RETURNING login_id, customer_id, login_at;                  -- 4 rows


-- Q7. Nisha has no orders, but she has a row in logins (and is not referenced
--     by anyone's referred_by). logins.customer_id -> customers has no
--     ON DELETE action, so the FK blocks the delete.
-- DELETE FROM customers WHERE customer_id = 19;
--   ERROR: ... violates foreign key constraint "logins_customer_id_fkey" on table "logins"

DELETE FROM logins    WHERE customer_id = 19;               -- remove children first
DELETE FROM customers WHERE customer_id = 19;               -- now allowed

ROLLBACK;
SELECT COUNT(*) AS customers_now FROM customers;            -- 20
