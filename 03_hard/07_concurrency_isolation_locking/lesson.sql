-- =============================================================================
-- 03_hard/07 · Concurrency, Isolation & Locking — LESSON
--
-- Concurrency needs TWO sessions. This file has two kinds of sections:
--   [RUN]      single-session code — runs as part of this file.
--   [2 TABS]   open two psql windows (A and B) on sql_course and type the
--              steps in the order shown. They are comments here on purpose.
-- Setup for the 2-tab demos: run sections 0 first (they create the tables).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;


-- -----------------------------------------------------------------------------
-- 0. [RUN] Setup
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS stock (
    item     TEXT PRIMARY KEY,
    qty      INT  NOT NULL CHECK (qty >= 0),
    version  INT  NOT NULL DEFAULT 1           -- for optimistic locking (section 4)
);
TRUNCATE stock;
INSERT INTO stock (item, qty) VALUES ('ticket', 1), ('mug', 10), ('pen', 100);

CREATE TABLE IF NOT EXISTS on_call (doctor TEXT PRIMARY KEY, on_duty BOOLEAN NOT NULL);
TRUNCATE on_call;
INSERT INTO on_call VALUES ('alice', TRUE), ('bob', TRUE);


-- -----------------------------------------------------------------------------
-- 1. [RUN] MVCC: every row version has xmin / xmax
-- -----------------------------------------------------------------------------

-- xmin = id of the transaction that created this row version.
SELECT xmin, xmax, * FROM stock;

-- An UPDATE creates a NEW version (new xmin); the old one becomes dead until VACUUM.
UPDATE stock SET qty = qty WHERE item = 'pen';
SELECT xmin, xmax, * FROM stock WHERE item = 'pen';     -- xmin changed
SELECT txid_current() AS my_transaction_id;


-- -----------------------------------------------------------------------------
-- 2. [2 TABS] Read Committed vs Repeatable Read (non-repeatable read)
-- -----------------------------------------------------------------------------
--  A: SET search_path TO sandbox, public;
--  A: BEGIN;                                   -- default: READ COMMITTED
--  A: SELECT qty FROM stock WHERE item = 'mug';        -- 10
--        B: UPDATE sandbox.stock SET qty = 7 WHERE item = 'mug';   -- autocommit
--  A: SELECT qty FROM stock WHERE item = 'mug';        -- 7  <- changed inside A's transaction!
--  A: COMMIT;
--
--  A: BEGIN ISOLATION LEVEL REPEATABLE READ;
--  A: SELECT qty FROM stock WHERE item = 'mug';        -- 7   (snapshot taken here)
--        B: UPDATE sandbox.stock SET qty = 3 WHERE item = 'mug';
--  A: SELECT qty FROM stock WHERE item = 'mug';        -- still 7: stable snapshot
--  A: UPDATE stock SET qty = qty - 1 WHERE item = 'mug';
--     ERROR: could not serialize access due to concurrent update   (SQLSTATE 40001)
--  A: ROLLBACK;                                -- the app must RETRY the whole transaction


-- -----------------------------------------------------------------------------
-- 3. [2 TABS] The lost update — and the atomic-UPDATE fix
-- -----------------------------------------------------------------------------
-- Classic app bug: read qty, compute in code, write qty back.
--  A: BEGIN;  SELECT qty FROM sandbox.stock WHERE item = 'ticket';     -- 1 -> "available!"
--        B: BEGIN;  SELECT qty FROM sandbox.stock WHERE item = 'ticket'; -- 1 -> "available!"
--  A: UPDATE sandbox.stock SET qty = 0 WHERE item = 'ticket';  COMMIT;   -- sold
--        B: UPDATE sandbox.stock SET qty = 0 WHERE item = 'ticket';  COMMIT;   -- sold AGAIN
--  => one ticket, two buyers. Neither statement failed.
--
-- Fix 1: let the database do read+check+write atomically, then check the row count.
--  A: UPDATE sandbox.stock SET qty = qty - 1 WHERE item = 'ticket' AND qty >= 1;   -- UPDATE 1
--        B: UPDATE sandbox.stock SET qty = qty - 1 WHERE item = 'ticket' AND qty >= 1;  -- waits for A,
--           then re-checks the WHERE on the NEW row version -> UPDATE 0 -> "sold out"

-- [RUN] The single-session version of Fix 1:
UPDATE stock SET qty = 1 WHERE item = 'ticket';
UPDATE stock SET qty = qty - 1 WHERE item = 'ticket' AND qty >= 1 RETURNING qty;   -- 1 row: sold
UPDATE stock SET qty = qty - 1 WHERE item = 'ticket' AND qty >= 1 RETURNING qty;   -- 0 rows: sold out


-- -----------------------------------------------------------------------------
-- 4. [RUN] Pessimistic vs optimistic locking
-- -----------------------------------------------------------------------------

-- Pessimistic: lock the row first, so nobody can change it until COMMIT.
BEGIN;
SELECT qty FROM stock WHERE item = 'mug' FOR UPDATE;    -- row lock held from here
-- (another session's UPDATE/FOR UPDATE on 'mug' would now WAIT)
-- Inspect our own locks: a RowExclusiveLock / RowShareLock on the table + transactionid lock.
SELECT locktype, relation::regclass, mode, granted
FROM pg_locks
WHERE pid = pg_backend_pid() AND relation = 'sandbox.stock'::regclass;
UPDATE stock SET qty = qty - 2 WHERE item = 'mug';
COMMIT;                                                  -- lock released

-- Optimistic: no lock while the user is "thinking"; detect conflicts at write time.
-- 1) Read the row and remember its version.
SELECT item, qty, version FROM stock WHERE item = 'pen';          -- version 1
-- 2) Someone else updates it in the meantime (simulated here):
UPDATE stock SET qty = qty - 5, version = version + 1 WHERE item = 'pen';
-- 3) Our write includes the version we read. 0 rows -> conflict -> reload & retry.
UPDATE stock SET qty = qty - 1, version = version + 1
WHERE item = 'pen' AND version = 1                                -- stale version
RETURNING *;                                                      -- 0 rows: conflict detected


-- -----------------------------------------------------------------------------
-- 5. [2 TABS] NOWAIT and lock_timeout
-- -----------------------------------------------------------------------------
--  A: BEGIN; SELECT * FROM sandbox.stock WHERE item = 'pen' FOR UPDATE;
--        B: SELECT * FROM sandbox.stock WHERE item = 'pen' FOR UPDATE NOWAIT;
--           ERROR: could not obtain lock on row in relation "stock"   (instant, no waiting)
--        B: SET lock_timeout = '2s';
--        B: UPDATE sandbox.stock SET qty = 0 WHERE item = 'pen';
--           ERROR: canceling statement due to lock timeout   (after 2 seconds)
--  A: COMMIT;
-- In migrations ALWAYS: SET lock_timeout = '5s'; before ALTER TABLE on busy tables.


-- -----------------------------------------------------------------------------
-- 6. [RUN + 2 TABS] SKIP LOCKED: a safe multi-worker job queue
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS job_queue (
    job_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payload  TEXT NOT NULL,
    status   TEXT NOT NULL DEFAULT 'queued'
);
TRUNCATE job_queue RESTART IDENTITY;
INSERT INTO job_queue (payload) SELECT 'send email #' || g FROM generate_series(1, 6) g;

-- A worker claims up to 2 jobs that nobody else has locked, and marks them.
-- Concurrent workers running the same statement get DIFFERENT jobs, never wait,
-- never double-process. (Worker B in another tab would receive jobs 3 and 4.)
WITH next_jobs AS (
    SELECT job_id
    FROM job_queue
    WHERE status = 'queued'
    ORDER BY job_id
    LIMIT 2
    FOR UPDATE SKIP LOCKED
)
UPDATE job_queue j
SET status = 'processing'
FROM next_jobs n
WHERE j.job_id = n.job_id
RETURNING j.job_id, j.payload;

SELECT * FROM job_queue ORDER BY job_id;


-- -----------------------------------------------------------------------------
-- 7. [2 TABS] Deadlock
-- -----------------------------------------------------------------------------
--  A: BEGIN; UPDATE sandbox.stock SET qty = qty + 1 WHERE item = 'mug';
--        B: BEGIN; UPDATE sandbox.stock SET qty = qty + 1 WHERE item = 'pen';
--  A: UPDATE sandbox.stock SET qty = qty + 1 WHERE item = 'pen';    -- waits for B
--        B: UPDATE sandbox.stock SET qty = qty + 1 WHERE item = 'mug';  -- waits for A -> cycle!
--           ERROR: deadlock detected  (after ~1s Postgres kills one of them)
--  A: COMMIT;
-- Prevention: always touch rows in the same order, e.g.
--   SELECT * FROM sandbox.stock WHERE item IN ('mug','pen') ORDER BY item FOR UPDATE;


-- -----------------------------------------------------------------------------
-- 8. [2 TABS] Write skew: Repeatable Read is NOT enough, Serializable is
-- -----------------------------------------------------------------------------
-- Rule: at least one doctor must stay on call.
--  A: BEGIN ISOLATION LEVEL REPEATABLE READ;
--  A: SELECT COUNT(*) FROM sandbox.on_call WHERE on_duty;          -- 2 -> "I can leave"
--        B: BEGIN ISOLATION LEVEL REPEATABLE READ;
--        B: SELECT COUNT(*) FROM sandbox.on_call WHERE on_duty;    -- 2 -> "I can leave"
--  A: UPDATE sandbox.on_call SET on_duty = FALSE WHERE doctor = 'alice';  COMMIT;
--        B: UPDATE sandbox.on_call SET on_duty = FALSE WHERE doctor = 'bob';    COMMIT;
--  => both committed, NOBODY is on call. (Different rows were updated, so no conflict.)
--
-- Repeat with BEGIN ISOLATION LEVEL SERIALIZABLE in both tabs:
--        B's COMMIT (or UPDATE) fails with
--        ERROR: could not serialize access due to read/write dependencies among transactions
--  -> retry B; on retry it sees only 1 doctor on duty and refuses to leave.


-- -----------------------------------------------------------------------------
-- 9. [RUN] Advisory locks: app-level mutex
-- -----------------------------------------------------------------------------

-- "Only one nightly-report job at a time": try to grab lock #2025.
SELECT pg_try_advisory_lock(2025) AS got_lock;     -- true: we are the only runner
-- ... do the work ...
SELECT pg_advisory_unlock(2025)  AS released;      -- always release (or use the _xact_ variant)

-- Transaction-scoped variant releases automatically at COMMIT/ROLLBACK.
BEGIN;
SELECT pg_advisory_xact_lock(2025);
COMMIT;


-- -----------------------------------------------------------------------------
-- 10. [RUN] Who is blocking whom? (useful on a real server)
-- -----------------------------------------------------------------------------

SELECT pid,
       state,
       wait_event_type,
       pg_blocking_pids(pid) AS blocked_by,
       LEFT(query, 60)       AS query
FROM pg_stat_activity
WHERE datname = current_database();


-- Clean up
RESET search_path;
DROP SCHEMA sandbox CASCADE;
