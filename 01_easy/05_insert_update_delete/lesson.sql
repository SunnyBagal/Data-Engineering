-- =============================================================================
-- 01_easy/05 · INSERT, UPDATE, DELETE — LESSON
-- Everything on the real tables runs inside BEGIN ... ROLLBACK, so the shared
-- data is unchanged when the file finishes. Run it statement by statement.
-- =============================================================================

BEGIN;   -- start a transaction: nothing below is permanent until COMMIT


-- -----------------------------------------------------------------------------
-- 1. INSERT
-- -----------------------------------------------------------------------------

-- Single row, columns listed explicitly. customer_id is omitted -> identity
-- generates the next value (21). referred_by and phone are omitted -> NULL.
INSERT INTO customers (first_name, last_name, email, city, country, signup_date)
VALUES ('Asha', 'Rao', 'asha.rao@mail.com', 'Bengaluru', 'India', CURRENT_DATE);

-- Multi-row insert: ONE statement, ONE round trip. Much faster than 3 inserts,
-- and atomic: if one row fails, none are inserted.
INSERT INTO customers (first_name, last_name, email, country, signup_date)
VALUES ('Ben',   'Ng',    'ben.ng@mail.com',    'Singapore', '2025-10-01'),
       ('Carla', 'Diaz',  'carla.d@mail.com',   'Spain',     '2025-10-02'),
       ('Dev',   'Patel', 'dev.patel@mail.com', 'India',     '2025-10-03');

-- RETURNING gives back what was inserted (including generated ids) — no need for
-- a second "SELECT max(id)" query, which is also wrong under concurrency.
INSERT INTO departments (dept_name, location, budget)
VALUES ('Legal', 'Delhi', 250000)
RETURNING dept_id, dept_name;

-- DEFAULT keyword: explicitly ask for the column default.
INSERT INTO employees (first_name, last_name, email, dept_id, manager_id,
                       job_title, salary, hire_date, is_active)
VALUES ('Irfan', 'Ali', 'irfan.ali@corp.com', 1, 5,
        'Software Engineer', 98000, CURRENT_DATE, DEFAULT)   -- DEFAULT -> TRUE
RETURNING emp_id, is_active;

-- Using expressions/functions in VALUES.
INSERT INTO orders (customer_id, employee_id, order_date, status)
VALUES (21, NULL, now(), 'pending')          -- order for our new customer Asha
RETURNING order_id, order_date;

SELECT customer_id, first_name, email, country FROM customers WHERE customer_id > 20;


-- -----------------------------------------------------------------------------
-- 2. UPDATE
-- -----------------------------------------------------------------------------

-- ALWAYS preview the rows with the same WHERE before updating.
SELECT product_id, product_name, price FROM products WHERE category_id = 4;

-- Update using an expression on the current value: 10% price increase,
-- rounded to cents (NUMERIC multiplication may produce more decimals).
UPDATE products
SET price = ROUND(price * 1.10, 2)
WHERE category_id = 4;                      -- psql prints "UPDATE 6" = rows changed

-- Multiple columns at once; all SET expressions see the OLD row values.
UPDATE products
SET stock_qty       = stock_qty + 50,
    is_discontinued = FALSE
WHERE product_id = 9;

-- Swap demo: because SET reads old values, this really swaps the two names.
UPDATE employees
SET first_name = last_name,
    last_name  = first_name
WHERE emp_id = 20;
SELECT emp_id, first_name, last_name FROM employees WHERE emp_id = 20;   -- Lee Kevin

-- Setting a value to NULL (e.g. customer asked us to delete their phone number).
UPDATE customers SET phone = NULL WHERE customer_id = 1;

-- UPDATE ... RETURNING: see the new values immediately.
UPDATE orders
SET status = 'shipped', shipped_date = CURRENT_DATE
WHERE order_id = 45
RETURNING order_id, status, shipped_date;

-- Soft delete: keep the row for history, mark it inactive.
UPDATE employees SET is_active = FALSE WHERE emp_id = 13;


-- -----------------------------------------------------------------------------
-- 3. DELETE
-- -----------------------------------------------------------------------------

-- Delete a specific row by primary key: the safest kind of WHERE.
DELETE FROM payments WHERE payment_id = 43;

-- Delete by a condition. Preview first!
SELECT * FROM logins WHERE customer_id = 19;
DELETE FROM logins WHERE customer_id = 19
RETURNING login_id, login_at;                -- shows what was removed

-- Foreign keys protect parents that still have children:
-- DELETE FROM customers WHERE customer_id = 3;
--   ERROR: violates foreign key constraint "orders_customer_id_fkey"

-- ...but ON DELETE CASCADE on order_items -> deleting an order removes its lines.
SELECT COUNT(*) AS lines_before FROM order_items WHERE order_id = 46;   -- 2
DELETE FROM orders WHERE order_id = 46;
SELECT COUNT(*) AS lines_after  FROM order_items WHERE order_id = 46;   -- 0


-- -----------------------------------------------------------------------------
-- 4. The "forgot the WHERE" disaster (safe here because we will roll back)
-- -----------------------------------------------------------------------------

SAVEPOINT before_disaster;                   -- a checkpoint inside the transaction
UPDATE products SET price = 0;               -- EVERY product is now free!
SELECT COUNT(*) AS free_products FROM products WHERE price = 0;   -- 24
ROLLBACK TO SAVEPOINT before_disaster;       -- undo only back to the savepoint
SELECT COUNT(*) AS free_products FROM products WHERE price = 0;   -- 0


-- -----------------------------------------------------------------------------
-- 5. Undo everything in this lesson
-- -----------------------------------------------------------------------------
ROLLBACK;

SELECT COUNT(*) AS customers_now FROM customers;   -- 20 again: nothing was kept
