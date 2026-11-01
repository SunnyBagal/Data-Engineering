-- =============================================================================
-- 02_medium/08 · Advanced DML — EXERCISES
-- Uses: advanced DML + CTEs (06) + subqueries (03) + joins (01)
--       + constraints (easy/04) + transactions (easy/05)
-- Wrap everything in BEGIN; ... ROLLBACK;
-- =============================================================================

BEGIN;


-- Q1. Create a temp table product_sales(product_id PK, units INT, revenue NUMERIC(12,2))
--     and fill it with INSERT … SELECT for ALL products (0 for never sold).
--     Expected: 24 rows inserted; 4 rows with units = 0



-- Q2. Run the Q1 load a second time so that it doesn't fail and doesn't
--     duplicate anything (ON CONFLICT … DO NOTHING). How many rows were inserted?
--     Expected: 0



-- Q3. A corrected sales feed arrives. UPSERT it into product_sales so existing
--     rows are updated and new rows are inserted, skipping no-op updates:
--       (5, 10, 250.00), (18, 7, 104.93), (99, 1, 10.00)
--     Return each affected row and whether it was inserted.
--     (99 isn't a real product — product_sales has no FK, so it's accepted.)
--     Expected: 2 rows affected (5 updated, 99 inserted; 18 unchanged)



-- Q4. Reserve stock for pending orders with UPDATE … FROM (aggregate the
--     source first). Return product name and the new stock.
--     Expected: 3 rows — GamerX 17 Laptop 2, Midnight Library Tales 149, SQL for Humans 89



-- Q5. Give every active employee in Sales (dept 2) a raise equal to 1% of the
--     revenue of the delivered orders they handled (round to 2 decimals),
--     using UPDATE … FROM. Return name, old salary and new salary
--     (self-join trick).
--     Expected: 3 rows — James +87.38, Kavya +59.99, Pooja +32.54



-- Q6. Delete the order_items of cancelled orders with DELETE … USING, and
--     return the deleted rows.
--     Expected: 3 rows



-- Q7. In ONE statement (writable CTE): increase Cookware prices by 10%,
--     and log product_id, old price and new price into a temp table
--     price_audit(product_id, old_price, new_price, changed_at default now()).
--     Expected: 2 rows logged (79.00 -> 86.90, 45.00 -> 49.50)


ROLLBACK;
