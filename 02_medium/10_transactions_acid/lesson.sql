-- =============================================================================
-- 02_medium/10 · Transactions & ACID — LESSON
-- Statements that fail on purpose are commented out with their error message.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;

-- A tiny bank: the CHECK constraint encodes the business rule "no overdrafts".
CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    owner      TEXT NOT NULL,
    balance    NUMERIC(12,2) NOT NULL CHECK (balance >= 0)
);
INSERT INTO accounts VALUES (1, 'Asha', 1000), (2, 'Ben', 500), (3, 'Chen', 0);


-- -----------------------------------------------------------------------------
-- 1. COMMIT: a successful transfer (Atomicity + Consistency)
-- -----------------------------------------------------------------------------

BEGIN;
UPDATE accounts SET balance = balance - 300 WHERE account_id = 1;   -- debit Asha
UPDATE accounts SET balance = balance + 300 WHERE account_id = 2;   -- credit Ben
-- Inside the transaction we see our own changes. Other sessions still see the
-- OLD balances until we commit (Isolation).
SELECT * FROM accounts ORDER BY account_id;
COMMIT;

-- Invariant: total money in the system never changes with a transfer.
SELECT SUM(balance) AS total FROM accounts;          -- 1500


-- -----------------------------------------------------------------------------
-- 2. ROLLBACK: abandon everything since BEGIN
-- -----------------------------------------------------------------------------

BEGIN;
UPDATE accounts SET balance = 0;                     -- oops, no WHERE
SELECT SUM(balance) AS during FROM accounts;         -- 0
ROLLBACK;
SELECT SUM(balance) AS after FROM accounts;          -- 1500 again


-- -----------------------------------------------------------------------------
-- 3. A failing statement aborts the whole transaction
-- -----------------------------------------------------------------------------

-- Try to transfer 2000 from Ben (balance 800). Run these by hand:
--
-- BEGIN;
-- UPDATE accounts SET balance = balance + 2000 WHERE account_id = 3;  -- credit Chen: OK so far
-- UPDATE accounts SET balance = balance - 2000 WHERE account_id = 2;  -- debit Ben
--   ERROR: new row for relation "accounts" violates check constraint "accounts_balance_check"
-- SELECT * FROM accounts;
--   ERROR: current transaction is aborted, commands ignored until end of transaction block
-- COMMIT;      -- in Postgres, COMMIT of an aborted transaction actually performs a ROLLBACK
--
-- Result: Chen's credit is ALSO undone. Without a transaction, Chen would have
-- received 2000 that was never taken from anyone.
SELECT * FROM accounts ORDER BY account_id;          -- unchanged: 700 / 800 / 0


-- -----------------------------------------------------------------------------
-- 4. SAVEPOINT: partial rollback
-- -----------------------------------------------------------------------------

BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 100 WHERE account_id = 3;   -- transfer #1 done

SAVEPOINT before_second_transfer;                    -- checkpoint
UPDATE accounts SET balance = balance - 50 WHERE account_id = 2;
UPDATE accounts SET balance = balance + 50 WHERE account_id = 1;    -- transfer #2...
-- ...turns out to be a mistake: undo ONLY transfer #2.
ROLLBACK TO SAVEPOINT before_second_transfer;

-- A savepoint also rescues a transaction from an error: if a statement fails
-- after a savepoint, ROLLBACK TO SAVEPOINT clears the "aborted" state.
RELEASE SAVEPOINT before_second_transfer;            -- no longer needed
COMMIT;                                              -- transfer #1 is kept

SELECT * FROM accounts ORDER BY account_id;          -- 600 / 800 / 100


-- -----------------------------------------------------------------------------
-- 5. Time inside a transaction
-- -----------------------------------------------------------------------------

-- now() is frozen at the transaction's start; clock_timestamp() keeps moving.
-- This is useful: every row written in one transaction gets the same "now()".
BEGIN;
SELECT now() AS tx_start, clock_timestamp() AS wall_1;
SELECT pg_sleep(0.5);
SELECT now() AS still_tx_start, clock_timestamp() AS wall_2;   -- now() unchanged
COMMIT;


-- -----------------------------------------------------------------------------
-- 6. Sequences are NOT transactional: gaps are normal
-- -----------------------------------------------------------------------------

CREATE TABLE tickets (ticket_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, note TEXT);

INSERT INTO tickets (note) VALUES ('first');                 -- id 1
BEGIN;
INSERT INTO tickets (note) VALUES ('rolled back');           -- consumes id 2
ROLLBACK;
INSERT INTO tickets (note) VALUES ('third');                 -- gets id 3, not 2
SELECT * FROM tickets;                                       -- ids 1 and 3: a gap
-- Never rely on ids being gapless (e.g. for invoice numbers that must be
-- consecutive by law, use a separate counter row updated in the transaction).


-- -----------------------------------------------------------------------------
-- 7. Transactional DDL (Postgres)
-- -----------------------------------------------------------------------------

-- A migration: add a column and back-fill it. If any step fails, the schema
-- change is undone too — no half-migrated database.
BEGIN;
ALTER TABLE accounts ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'INR';
UPDATE accounts SET currency = 'USD' WHERE owner = 'Ben';
SELECT * FROM accounts ORDER BY account_id;
ROLLBACK;                                                    -- column is gone again
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'sandbox' AND table_name = 'accounts';  -- no "currency"


-- -----------------------------------------------------------------------------
-- 8. A realistic multi-table transaction: checkout
-- -----------------------------------------------------------------------------

-- Customer 20 buys 2 x Wireless Mouse (product 5). Order header, line, stock
-- and payment must all succeed together. (Rolled back to keep shared data.)
BEGIN;
INSERT INTO public.orders (order_id, customer_id, order_date, status)
VALUES (1000, 20, now(), 'pending');

INSERT INTO public.order_items (order_id, product_id, quantity, unit_price)
SELECT 1000, product_id, 2, price FROM public.products WHERE product_id = 5;

-- The CHECK (stock_qty >= 0) on products makes overselling impossible: if
-- stock were insufficient, this UPDATE would fail and abort the whole checkout.
UPDATE public.products SET stock_qty = stock_qty - 2 WHERE product_id = 5;

INSERT INTO public.payments (order_id, amount, method, paid_at)
VALUES (1000, 50.00, 'card', now());

SELECT o.order_id, oi.quantity, p.stock_qty, pay.amount
FROM public.orders o
JOIN public.order_items oi ON oi.order_id = o.order_id
JOIN public.products p     ON p.product_id = oi.product_id
JOIN public.payments pay   ON pay.order_id = o.order_id
WHERE o.order_id = 1000;                                      -- stock 198, paid 50.00
ROLLBACK;


-- -----------------------------------------------------------------------------
-- Clean up
-- -----------------------------------------------------------------------------
RESET search_path;
DROP SCHEMA sandbox CASCADE;
