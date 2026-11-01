-- =============================================================================
-- 01_easy/05 · INSERT, UPDATE, DELETE — EXERCISES
-- Uses: DML + constraints (04) + DDL (03) + data types (02) + transactions (01)
-- Start with BEGIN; and finish with ROLLBACK; so the shared data stays intact.
-- =============================================================================

BEGIN;


-- Q1. A new product arrives: 'Gaming Mouse', category Gaming (12), price 59.90,
--     cost 25, stock 40, created today, attributes {"brand":"Clicko","dpi":16000}.
--     Insert it and return its new product_id.
--     Expected: product_id 25



-- Q2. Insert a new customer (any details, country 'India') and, in a second
--     statement, an order for them dated now with status 'pending' handled
--     online (no employee). Use RETURNING to get both ids.
--     Then add two order_items for that order: 1 × product 25 at its price,
--     and 2 × product 18 at 14.99 with a 5% discount.



-- Q3. Every product in the Cookware category (8) gets a 15% price cut,
--     rounded to 2 decimals. First SELECT the affected rows, then UPDATE
--     and return product_name with the new price.
--     Expected: 2 rows updated (79.00 -> 67.15, 45.00 -> 38.25)



-- Q4. Mark order 45 as shipped today, and order 46 as cancelled
--     (a cancelled order has no shipped_date). Use ONE statement per order.
--     Then try to set order 44's status to 'lost' — which constraint stops you?



-- Q5. Kevin Lee (emp 20, a contractor) becomes a permanent Engineering
--     employee: department 1, title 'Software Engineer', salary +20%.
--     Do it in a single UPDATE and return the new row.
--     Expected salary: 72000.00



-- Q6. Delete all logins made from the 'android' device before 2025-10-01.
--     Preview with SELECT, then DELETE ... RETURNING.
--     Expected: 4 rows



-- Q7. Try to delete customer 19 (Nisha). Why does it fail even though she has
--     no orders? Fix it by first deleting what blocks it, then delete her.
--     Finally, ROLLBACK everything and prove customers still has 20 rows.
