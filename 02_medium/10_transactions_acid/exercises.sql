-- =============================================================================
-- 02_medium/10 · Transactions & ACID — EXERCISES
-- Uses: transactions + advanced DML (08) + constraints (easy/04) + joins (01)
--       + DDL (easy/03)
-- =============================================================================


-- Q1. Create lab.wallets(wallet_id PK, owner, balance NUMERIC(10,2) that can
--     never go negative). Insert: (1,'Ravi',500), (2,'Sara',200), (3,'Tom',0).
--     In one transaction move 150 from Ravi to Tom and 50 from Sara to Tom,
--     then COMMIT. Prove the total balance is unchanged.
--     Expected: 350 / 150 / 200, total 700



-- Q2. Write (as comments, then run by hand) a transaction that tries to move
--     400 from Sara to Ravi. Which statement fails, what state is the
--     transaction in afterwards, and what are the balances after you end it?
--     Expected: balances unchanged (350 / 150 / 200)



-- Q3. Payroll run with savepoints: in ONE transaction
--       - pay Tom 100 from Ravi              (keep)
--       - SAVEPOINT
--       - pay Sara 1000 from Ravi             (fails or is wrong -> undo it)
--       - pay Sara 25 from Ravi               (keep)
--     Use ROLLBACK TO SAVEPOINT for the middle step and COMMIT the rest.
--     Expected: Ravi 225, Sara 175, Tom 300



-- Q4. Show that now() is constant within a transaction while clock_timestamp()
--     advances (use pg_sleep(0.2) between two SELECTs). Then explain why an
--     audit table might prefer now() for all rows written by one transaction.



-- Q5. Checkout on the REAL data, all in one transaction that you ROLL BACK at
--     the end: customer 19 (Nisha) orders 1 × 'Air Fryer' (13) and
--     2 × 'Chef Knife' (17) at current prices, pays the full amount by UPI.
--     Use INSERT … RETURNING / INSERT … SELECT so you don't hard-code prices,
--     decrement stock with UPDATE … FROM, then show the order total, the
--     payment and the new stock levels.
--     Expected: total 219.00; stock Air Fryer 34, Chef Knife 78



-- Q6. Demonstrate that identity values are not rolled back: insert a row into
--     lab.wallets' sibling table lab.wallet_log(log_id identity, note) in a
--     transaction that you roll back, insert another row normally, and show
--     the gap.



-- Q7. Answer in comments:
--     a) Which ACID property do CHECK constraints support?
--     b) If the database server loses power right after COMMIT returns, is
--        the transaction lost? Why not?
--     c) Why should an application never keep a transaction open while
--        waiting for a user to click "Confirm"?
--     Finally: DROP SCHEMA lab CASCADE.
