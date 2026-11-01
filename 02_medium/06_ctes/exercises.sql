-- =============================================================================
-- 02_medium/06 · CTEs — EXERCISES
-- Uses: CTEs + CASE (05) + subqueries (03) + joins (01, 02) + GROUP BY (easy/11)
--       + date functions (easy/12) + DML/transactions (easy/05)
-- =============================================================================


-- Q1. Rewrite the customer-tier report (topic 05 Q3) with CTEs:
--     order_totals -> customer_spend -> tiers, then count customers per tier.
--     Expected: gold 4, silver 7, bronze 7, none 2



-- Q2. Which months of 2024 had revenue (non-cancelled orders) above the 2024
--     monthly average? Show month, revenue and the average.
--     Expected: Jan, Apr, Jul, Nov, Dec 2024; average 993.71



-- Q3. Each category's revenue and its share of total revenue (1 decimal),
--     plus a running label 'core' if share >= 15 %, else 'niche'.
--     Expected: Laptops 55.8 % core, Phones 20.5 % core, Accessories 13.7 % niche



-- Q4. The top-spending customer in each country (non-cancelled, non-returned
--     orders), without window functions.
--     Expected: India Aarav 6725.84, USA John 4192.49, UK Oliver 1403.60,
--               Canada Chloe 1194.10, Germany Lukas 1150.00



-- Q5. Repeat-purchase rate: of the customers with at least one non-cancelled
--     order, what percentage have more than one? Show both counts and the %.
--     Expected: 13 of 18 = 72.2 %



-- Q6. Product scorecard for ALL products: units sold, revenue, gross profit
--     (revenue - units * cost), and status = 'never sold' / 'top seller'
--     (gross profit >= 1000) / 'regular'. Sort by gross profit descending.
--     Expected: 24 rows; ProBook 14 Laptop first with gross profit 1640.00



-- Q7. Inside a transaction, archive every RETURNED order into a temp table
--     orders_returned (same structure as orders) using a single data-modifying
--     CTE (DELETE … RETURNING → INSERT). Their payments block the delete —
--     handle that too (hint: delete the payments in an earlier CTE… does it
--     work? Why / why not?). Show what was archived, then ROLLBACK.
--     Expected: 3 orders archived (4, 20, 37)
