-- =============================================================================
-- 01_easy/07 · WHERE — EXERCISES
-- Uses: WHERE + SELECT expressions/aliases/DISTINCT (06) + DML (05) + types (02)
-- =============================================================================


-- Q1. Engineering employees (dept 1) earning more than 90,000.
--     Show full name (one column) and salary.
--     Expected: 5 rows



-- Q2. Customers from India or the UK who signed up during 2023.
--     Write it once WITHOUT parentheses using OR, see the wrong answer,
--     then fix it two ways (parentheses, and IN).
--     Expected: 10 rows (wrong) -> 5 rows (right)



-- Q3. Products that are NOT discontinued and whose price is between 50 and 400
--     (inclusive). Show name, price and margin (price - cost).
--     Expected: 10 rows



-- Q4. Find every product with "phone" anywhere in its name, regardless of case.
--     Then explain why LIKE '%Phone%' returns one row fewer.
--     Expected: 4 rows



-- Q5. Delivered orders placed in Q4 2024 (October 1 – December 31, inclusive of
--     the whole last day). Use a half-open range on order_date.
--     Expected: 3 rows (orders 32, 33, 34)



-- Q6. Order lines where the customer got any discount AND the discounted line
--     revenue (quantity * unit_price * (1 - discount)) is above 500.
--     Show order_id, product_id, discount and revenue rounded to 2 decimals.
--     Expected: 8 rows



-- Q7. Inside a transaction: customers whose phone starts with '+91' get
--     their phone number cleared (set to NULL) as part of a privacy request.
--     Preview the rows first, run the UPDATE (check the row count), then
--     verify no '+91' phones remain, and ROLLBACK.
--     Expected: 4 rows updated
