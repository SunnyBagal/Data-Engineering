-- =============================================================================
-- 03_hard/07 · Concurrency, Isolation & Locking — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;


-- Q1. SKIP LOCKED: concurrent bookers skip a seat another transaction is in the
--     middle of booking, instead of waiting for it (and then failing).
CREATE TABLE lab.seats (
    seat_no   INT PRIMARY KEY,
    flight    TEXT NOT NULL,
    passenger TEXT
);
INSERT INTO lab.seats (seat_no, flight) SELECT g, 'AI101' FROM generate_series(1, 6) g;

-- The booking statement (run once per passenger):
WITH free_seat AS (
    SELECT seat_no FROM lab.seats
    WHERE flight = 'AI101' AND passenger IS NULL
    ORDER BY seat_no
    LIMIT 1
    FOR UPDATE SKIP LOCKED
)
UPDATE lab.seats s SET passenger = 'Ravi'
FROM free_seat f WHERE s.seat_no = f.seat_no
RETURNING s.seat_no, s.passenger;                       -- seat 1

WITH free_seat AS (
    SELECT seat_no FROM lab.seats WHERE flight = 'AI101' AND passenger IS NULL
    ORDER BY seat_no LIMIT 1 FOR UPDATE SKIP LOCKED
)
UPDATE lab.seats s SET passenger = 'Sara' FROM free_seat f WHERE s.seat_no = f.seat_no
RETURNING s.seat_no, s.passenger;                       -- seat 2

WITH free_seat AS (
    SELECT seat_no FROM lab.seats WHERE flight = 'AI101' AND passenger IS NULL
    ORDER BY seat_no LIMIT 1 FOR UPDATE SKIP LOCKED
)
UPDATE lab.seats s SET passenger = 'Tom' FROM free_seat f WHERE s.seat_no = f.seat_no
RETURNING s.seat_no, s.passenger;                       -- seat 3
-- In an app, the passenger name is a parameter ($1) of one prepared statement.


-- Q2.
ALTER TABLE lab.seats ADD COLUMN version INT NOT NULL DEFAULT 1;

SELECT seat_no, passenger, version FROM lab.seats WHERE seat_no = 4;   -- app reads version 1

UPDATE lab.seats SET passenger = 'Zoe', version = version + 1          -- concurrent change
WHERE seat_no = 4;

UPDATE lab.seats
SET passenger = 'Mia', version = version + 1
WHERE seat_no = 4 AND version = 1                                       -- the version we read
RETURNING *;                                                            -- 0 rows -> conflict:
-- the app tells the user "this seat was just taken", reloads, and retries.


-- Q3. [2 TABS]
--  A: BEGIN; SELECT stock_qty FROM products WHERE product_id = 3;          -- 3
--        B: BEGIN; SELECT stock_qty FROM products WHERE product_id = 3;    -- 3
--  A: UPDATE products SET stock_qty = 2 WHERE product_id = 3;  COMMIT;     -- 3 - 1 computed in app
--        B: UPDATE products SET stock_qty = 2 WHERE product_id = 3;  COMMIT;   -- waits, then overwrites
--  Final stock = 2, but 2 units were sold -> it should be 1. (Restore with stock_qty = 3.)
--
--  Fix A (atomic): UPDATE products SET stock_qty = stock_qty - 1
--                  WHERE product_id = 3 AND stock_qty >= 1;
--      B's UPDATE waits for A, then re-reads the committed row (2) and writes 1.
--  Fix B (pessimistic): SELECT stock_qty FROM products WHERE product_id = 3 FOR UPDATE;
--      B's SELECT … FOR UPDATE waits until A commits, then reads 2 (not 3).
--  (Fix C: REPEATABLE READ — B's UPDATE fails with 40001 and B retries.)

-- [RUN] Fix A in one session, rolled back:
BEGIN;
UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 3 AND stock_qty >= 1 RETURNING stock_qty;  -- 2
UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 3 AND stock_qty >= 1 RETURNING stock_qty;  -- 1
ROLLBACK;


-- Q4. [2 TABS]
--  A: BEGIN ISOLATION LEVEL REPEATABLE READ;  SELECT SUM(amount) FROM payments;   -- 28049.57
--        B: INSERT INTO payments (order_id, amount, method, paid_at)
--           VALUES (44, 143.97, 'cash', now());                                    -- autocommit
--  A: SELECT SUM(amount) FROM payments;   -- still 28049.57 (snapshot from A's first query)
--  A: COMMIT;  SELECT SUM(amount) FROM payments;   -- 28193.54 now
--  Under READ COMMITTED, A's second SUM already shows 28193.54 (each statement
--  takes a new snapshot) -> a multi-query report could be internally inconsistent.
--  Cleanup: DELETE FROM payments WHERE order_id = 44;


-- Q5. [2 TABS]
CREATE TABLE lab.wallets (wallet_id INT PRIMARY KEY, balance NUMERIC(10,2) NOT NULL CHECK (balance >= 0));
INSERT INTO lab.wallets VALUES (1, 500), (2, 500);
--  A: BEGIN; UPDATE lab.wallets SET balance = balance - 10 WHERE wallet_id = 1;
--        B: BEGIN; UPDATE lab.wallets SET balance = balance - 20 WHERE wallet_id = 2;
--  A: UPDATE lab.wallets SET balance = balance + 10 WHERE wallet_id = 2;   -- waits for B
--        B: UPDATE lab.wallets SET balance = balance + 20 WHERE wallet_id = 1; -- ERROR: deadlock detected
--
-- Deadlock-free version: lock BOTH rows first, always in ascending id order,
-- so the second transfer simply waits for the first instead of crossing it.
BEGIN;
SELECT wallet_id FROM lab.wallets WHERE wallet_id IN (2, 1) ORDER BY wallet_id FOR UPDATE;
UPDATE lab.wallets SET balance = balance - 20 WHERE wallet_id = 2;
UPDATE lab.wallets SET balance = balance + 20 WHERE wallet_id = 1;
COMMIT;
SELECT * FROM lab.wallets ORDER BY wallet_id;                         -- 520 / 480


-- Q6.
CREATE TABLE lab.tasks (
    task_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind       TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','claimed','done')),
    claimed_by TEXT,
    claimed_at TIMESTAMPTZ
);
INSERT INTO lab.tasks (kind) SELECT 'resize-image' FROM generate_series(1, 10);

-- The claim query (worker name and batch size would be parameters).
WITH picked AS (
    SELECT task_id FROM lab.tasks
    WHERE status = 'queued'
    ORDER BY task_id
    LIMIT 3
    FOR UPDATE SKIP LOCKED
)
UPDATE lab.tasks t
SET status = 'claimed', claimed_by = 'worker-A', claimed_at = now()
FROM picked p WHERE t.task_id = p.task_id
RETURNING t.task_id, t.claimed_by;                                    -- 1, 2, 3

WITH picked AS (
    SELECT task_id FROM lab.tasks
    WHERE status = 'queued' ORDER BY task_id LIMIT 3
    FOR UPDATE SKIP LOCKED
)
UPDATE lab.tasks t
SET status = 'claimed', claimed_by = 'worker-B', claimed_at = now()
FROM picked p WHERE t.task_id = p.task_id
RETURNING t.task_id, t.claimed_by;                                    -- 4, 5, 6

SELECT status, COUNT(*) FROM lab.tasks GROUP BY status;               -- claimed 6, queued 4
-- Production tip: a partial index ON lab.tasks (task_id) WHERE status = 'queued'
-- keeps the claim query fast however large the done-history grows.


-- Q7. Under REPEATABLE READ each transaction reads its own snapshot (2 doctors
--     on duty) and updates a DIFFERENT row, so there is no write-write conflict
--     to detect — both commit and the invariant "COUNT(on_duty) >= 1" breaks.
--  Fix 1: SERIALIZABLE in both transactions — Postgres' SSI detects the
--         read/write dependency cycle and aborts one with 40001; the retry sees
--         only one doctor on duty.
--  Fix 2: explicit locking of the rows the decision depends on:
--         SELECT * FROM on_call WHERE on_duty FOR UPDATE;
--         The second transaction waits, then re-evaluates and sees 1 doctor.
--  (Fix 3 for some rules: materialize the invariant in a single row, e.g. a
--   counter with CHECK (on_duty_count >= 1), so both transactions hit the same row.)

DROP SCHEMA lab CASCADE;
