-- =============================================================================
-- 02_medium/10 · Transactions & ACID — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;


-- Q1.
CREATE TABLE lab.wallets (
    wallet_id INT PRIMARY KEY,
    owner     TEXT NOT NULL,
    balance   NUMERIC(10,2) NOT NULL CHECK (balance >= 0)   -- the invariant lives in the DB
);
INSERT INTO lab.wallets VALUES (1, 'Ravi', 500), (2, 'Sara', 200), (3, 'Tom', 0);

BEGIN;
UPDATE lab.wallets SET balance = balance - 150 WHERE wallet_id = 1;
UPDATE lab.wallets SET balance = balance + 150 WHERE wallet_id = 3;
UPDATE lab.wallets SET balance = balance - 50  WHERE wallet_id = 2;
UPDATE lab.wallets SET balance = balance + 50  WHERE wallet_id = 3;
COMMIT;

SELECT * FROM lab.wallets ORDER BY wallet_id;                 -- 350 / 150 / 200
SELECT SUM(balance) AS total FROM lab.wallets;                -- 700


-- Q2.
-- BEGIN;
-- UPDATE lab.wallets SET balance = balance - 400 WHERE wallet_id = 2;
--   ERROR: new row ... violates check constraint "wallets_balance_check"   (150 - 400 < 0)
-- UPDATE lab.wallets SET balance = balance + 400 WHERE wallet_id = 1;
--   ERROR: current transaction is aborted, commands ignored until end of transaction block
-- ROLLBACK;
-- The first UPDATE fails; the transaction is ABORTED, so nothing else runs and
-- nothing can be committed. After ROLLBACK the balances are unchanged.
SELECT * FROM lab.wallets ORDER BY wallet_id;                 -- 350 / 150 / 200


-- Q3.
BEGIN;
UPDATE lab.wallets SET balance = balance - 100 WHERE wallet_id = 1;   -- Ravi -> Tom 100
UPDATE lab.wallets SET balance = balance + 100 WHERE wallet_id = 3;

SAVEPOINT big_payment;
UPDATE lab.wallets SET balance = balance + 1000 WHERE wallet_id = 2;  -- credit first...
-- UPDATE lab.wallets SET balance = balance - 1000 WHERE wallet_id = 1;  -- ...this would FAIL (250 - 1000 < 0)
ROLLBACK TO SAVEPOINT big_payment;                                    -- undo just this step

UPDATE lab.wallets SET balance = balance - 25 WHERE wallet_id = 1;    -- Ravi -> Sara 25
UPDATE lab.wallets SET balance = balance + 25 WHERE wallet_id = 2;
COMMIT;

SELECT * FROM lab.wallets ORDER BY wallet_id;                 -- 225 / 175 / 300


-- Q4.
BEGIN;
SELECT now() AS tx_time, clock_timestamp() AS real_time_1;
SELECT pg_sleep(0.2);
SELECT now() AS tx_time, clock_timestamp() AS real_time_2;    -- now() identical, clock moved
COMMIT;
-- now() gives every row written by the transaction the SAME timestamp: an
-- order, its lines and its payment share one "created_at", which makes it easy
-- to group the changes of one business operation together.


-- Q5. RETURNING + INSERT … SELECT avoid hard-coded ids and prices.
--     (Explicit order_id 1001 keeps the example readable; in an app you'd
--      capture the generated id from RETURNING.)
BEGIN;
INSERT INTO orders (order_id, customer_id, order_date, status)
VALUES (1001, 19, now(), 'pending')
RETURNING order_id;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 1001, p.product_id, v.qty, p.price                     -- current price copied
FROM (VALUES (13, 1), (17, 2)) AS v(product_id, qty)
JOIN products p ON p.product_id = v.product_id;

UPDATE products p
SET stock_qty = p.stock_qty - oi.quantity
FROM order_items oi
WHERE oi.order_id = 1001 AND oi.product_id = p.product_id;    -- 1:1 per product -> safe

INSERT INTO payments (order_id, amount, method, paid_at)
SELECT 1001, SUM(quantity * unit_price * (1 - discount)), 'upi', now()
FROM order_items WHERE order_id = 1001;

SELECT (SELECT SUM(quantity * unit_price) FROM order_items WHERE order_id = 1001) AS order_total, -- 219.00
       (SELECT amount FROM payments WHERE order_id = 1001)                        AS paid,        -- 219.00
       (SELECT stock_qty FROM products WHERE product_id = 13)                      AS air_fryer,   -- 34
       (SELECT stock_qty FROM products WHERE product_id = 17)                      AS chef_knife;  -- 78
ROLLBACK;


-- Q6.
CREATE TABLE lab.wallet_log (log_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, note TEXT);
INSERT INTO lab.wallet_log (note) VALUES ('kept #1');          -- 1
BEGIN;
INSERT INTO lab.wallet_log (note) VALUES ('rolled back');      -- 2 (consumed)
ROLLBACK;
INSERT INTO lab.wallet_log (note) VALUES ('kept #2');          -- 3
SELECT * FROM lab.wallet_log;                                  -- 1, 3: gap at 2
-- Sequences are deliberately non-transactional so concurrent inserts never
-- wait for each other to commit or roll back.


-- Q7.
-- a) Consistency: a commit can never leave data violating a constraint.
-- b) Not lost: COMMIT only returns after the change is written to the
--    write-ahead log (WAL) on durable storage; on restart, Postgres replays
--    the WAL (Durability). (Unless fsync/synchronous_commit were disabled.)
-- c) An open transaction holds row locks (blocking other writers), keeps old
--    row versions from being vacuumed (bloat), and occupies a connection.
--    Users can take minutes — or close the tab. Validate first, then run a
--    short transaction when the user confirms (optimistic concurrency).

DROP SCHEMA lab CASCADE;
