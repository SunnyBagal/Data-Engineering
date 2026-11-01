-- =============================================================================
-- 02_medium/05 · CASE Expressions — EXERCISES
-- Uses: CASE + joins (01) + subqueries/derived tables (03) + GROUP BY (easy/11)
--       + NULLs (easy/08) + DML in a transaction (easy/05)
-- =============================================================================


-- Q1. Label every product as 'budget' (< 50), 'mid-range' (50 to < 500) or
--     'premium' (>= 500), then count products and average price per band,
--     sorted from cheapest band to most expensive.
--     Expected: budget 7, mid-range 12, premium 5



-- Q2. Salary grades for ACTIVE employees: 'executive' (>= 150k), 'senior'
--     (>= 100k), 'mid' (>= 70k), else 'junior'. Show headcount per grade.
--     Expected: executive 4, senior 4, mid 8, junior 3



-- Q3. Customer tiers by lifetime spend on orders that were NOT cancelled or
--     returned: 'gold' (>= 3000), 'silver' (>= 1000), 'bronze' (> 0),
--     'none' (never spent). Show each customer's name, spend (2 decimals) and
--     tier, then count customers per tier.
--     Expected: gold 4, silver 7, bronze 7, none 2



-- Q4. Classify each order's shipping speed: 'not shipped' when shipped_date is
--     NULL, 'fast' (<= 2 days), 'normal' (3 days), 'slow' (more). Count orders
--     per class.
--     Expected: fast 24, normal 16, slow 1, not shipped 5



-- Q5. List all orders sorted by workflow stage: pending, shipped, delivered,
--     returned, cancelled — and within a stage, newest first. Add a column
--     needs_action = 'yes' for pending/shipped orders and orders 'returned',
--     'no' otherwise.



-- Q6. For each country: number of customers, number with a phone, and the
--     percentage with a phone (1 decimal) — using SUM(CASE …), not FILTER.
--     Expected: USA 5 / 5 / 100.0, UK 3 / 2 / 66.7



-- Q7. Inside a transaction, apply a new price policy in ONE UPDATE:
--       discontinued products   -> price unchanged
--       out of stock (0)        -> +5%
--       stock > 100             -> -10%
--       otherwise               -> unchanged
--     Round to 2 decimals, update only the rows that actually change, and
--     return the name, stock and new price. Then ROLLBACK.
--     Expected: 7 rows updated
