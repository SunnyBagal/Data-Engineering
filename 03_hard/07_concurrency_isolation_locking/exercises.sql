-- =============================================================================
-- 03_hard/07 · Concurrency, Isolation & Locking — EXERCISES
-- Uses: locking/isolation + transactions (medium/10) + advanced DML (medium/08)
--       + CTEs (medium/06) + constraints (easy/04)
-- Questions marked [2 TABS] need two psql sessions; write the steps you'd run
-- in each tab as comments, then try them for real.
-- Work in schema "lab"; drop it at the end.
-- =============================================================================


-- Q1. [RUN] Create lab.seats(seat_no PK, flight TEXT, passenger TEXT NULL).
--     Insert seats 1..6 for flight 'AI101', all free. Write ONE statement that
--     books the lowest free seat for 'Ravi' safely under concurrency (two
--     users booking at the same moment must get different seats, nobody
--     waits). Book seats for Ravi, Sara and Tom.
--     Expected: seats 1, 2, 3



-- Q2. [RUN] Optimistic locking: add a version column to lab.seats. Write the
--     UPDATE an app would send to change seat 4's passenger to 'Mia' if it read
--     version 1, simulate a concurrent change in between, and show the
--     conflict (0 rows updated).



-- Q3. [2 TABS] Demonstrate a LOST UPDATE on product stock using the real
--     products table (inside transactions you roll back): both sessions read
--     stock_qty of product 3 (GamerX, 3 units), each sells 1 by writing
--     "stock_qty = <value read> - 1". What is the final stock, and what
--     should it be? Then show two different fixes.



-- Q4. [2 TABS] Under REPEATABLE READ, session A sums all payments while
--     session B inserts a new payment and commits. Does A's second SUM change?
--     What about under READ COMMITTED?



-- Q5. [2 TABS] Produce a deadlock between two transfers on lab.wallets
--     (1 -> 2 and 2 -> 1 at the same time). Then rewrite the transfer so the
--     deadlock is impossible.



-- Q6. [RUN] Write a reusable "claim next N jobs" query for a lab.tasks queue
--     (task_id, kind, status, claimed_by, claimed_at) using
--     FOR UPDATE SKIP LOCKED, that records which worker claimed them and when.
--     Insert 10 tasks, claim 3 as 'worker-A' and 3 as 'worker-B'.
--     Expected: A gets 1-3, B gets 4-6, 4 remain queued



-- Q7. [2 TABS + concept] Doctors' on-call rule (at least one on call) broken
--     by write skew. Explain why REPEATABLE READ allows it and give TWO fixes
--     (one with an isolation level, one with explicit locking).
--     Finally DROP SCHEMA lab CASCADE.
