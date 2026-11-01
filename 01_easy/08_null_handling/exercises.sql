-- =============================================================================
-- 01_easy/08 · NULL Handling — EXERCISES
-- Uses: NULL + WHERE (07) + SELECT expressions (06) + DML (05)
-- =============================================================================


-- Q1. List customers without a phone number. Show full name and a column
--     contact that holds their email (since phone is missing).
--     Expected: 7 rows



-- Q2. Orders that have not shipped yet and are NOT cancelled
--     (i.e. still in the pipeline). Show order_id, status, order_date.
--     Expected: 2 rows (45, 46)



-- Q3. In ONE query on customers, show: total rows, how many have a phone,
--     how many have a city, how many were referred by someone, and how many
--     have NO phone (computed as a difference).
--     Expected: 20 | 13 | 19 | 10 | 7



-- Q4. Find customers who have never referred anyone. First write it with
--     NOT IN (…) and explain the 0-row result, then fix it.
--     Expected: 0 rows (buggy) -> 12 rows (fixed)



-- Q5. Products whose color is NOT 'black' — including products that have no
--     color attribute at all (use attributes ->> 'color').
--     Compare  <> 'black'  with  IS DISTINCT FROM 'black'.
--     Expected: 3 rows with <>, 22 rows with IS DISTINCT FROM



-- Q6. For each order show order_id, status, days_to_ship
--     (shipped_date - order_date::date) and a column ship_label that says
--     'not shipped' when days_to_ship is NULL, otherwise the number as text
--     followed by ' days'. Then, separately, compute the average days_to_ship.
--     Expected: 46 rows; average = 2.44



-- Q7. Data repair. Inside a transaction, reproduce an intern's mistake:
--       UPDATE customers SET phone = '' WHERE phone IS NULL;
--     Show that COUNT(phone) now (wrongly) says 20. Then repair it with ONE
--     UPDATE that turns empty strings back into NULL using NULLIF, verify
--     COUNT(phone) = 13 again, and ROLLBACK.
--     Expected: 20 after the mistake, 13 after the repair
