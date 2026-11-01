-- =============================================================================
-- 01_easy/04 · Constraints — EXERCISES
-- Uses: constraints + DDL (03) + data types (02) + transactions (01)
-- Work in a schema called "lab"; drop it at the end.
-- =============================================================================


-- Q1. Create lab.coupons with:
--       coupon_code   up to 20 chars, primary key
--       pct_off       numeric(5,2), required, must be > 0 and <= 90
--       valid_from    date, required
--       valid_to      date, required, must be on or after valid_from
--       max_uses      int, optional, but if present must be positive
--       is_active     boolean, required, default true
--     Name every CHECK constraint.



-- Q2. Write 4 INSERTs into lab.coupons: one valid, and three that each break a
--     different rule. Run them one by one, note the error, then comment out
--     the failing ones so the file runs cleanly.



-- Q3. Create lab.coupon_redemptions(redemption_id auto PK, coupon_code FK to
--     lab.coupons, order_id FK to public.orders, redeemed_at timestamp default now()).
--     Rules: deleting a coupon must be BLOCKED if it was ever redeemed;
--     the same coupon can be used only once per order.
--     Insert a redemption of your valid coupon on order 1, then try to delete
--     the coupon (should fail — comment it out after seeing the error).



-- Q4. Inspect public.payments: list every constraint name, its type letter
--     and its definition using pg_constraint.
--     Expected: 4 rows (1 PK, 1 FK, 2 CHECKs)



-- Q5. Inside a transaction, try (one at a time) these changes to the REAL data,
--     write down which constraint stops each one, then ROLLBACK:
--       a) set the status of order 1 to 'lost'
--       b) insert an order for customer 999
--       c) give product 5 a stock_qty of -3
--       d) insert a customer whose email is 'aarav.shah@mail.com'



-- Q6. Our products table allows the same product_name twice. Add a UNIQUE
--     constraint on product_name in a transaction (it should succeed because
--     names are currently unique), prove a duplicate is rejected, then ROLLBACK.



-- Q7. Explain in comments: why does   CHECK (max_uses > 0)   accept a row with
--     max_uses = NULL, and how would you write the rule if NULL must be rejected?
--     Finally DROP SCHEMA lab CASCADE.
