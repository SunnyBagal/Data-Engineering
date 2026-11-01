-- =============================================================================
-- 02_medium/01 · Joins — EXERCISES
-- Uses: joins + GROUP BY/HAVING (easy/11) + aggregates (easy/10)
--       + NULL/COALESCE (easy/08) + functions (easy/12)
-- =============================================================================


-- Q1. Order list: order_id, order day (date only), customer full name,
--     country, status and the handling employee's full name — or 'Online'
--     when there is no employee. All 46 orders must appear.
--     Expected: 46 rows; order 3 -> 'Online'



-- Q2. Revenue and units per category name, highest revenue first.
--     Expected: 7 rows; Laptops 17710.00 (12 units) first, Fiction 224.87 last



-- Q3. Customers who have never placed an order (use a LEFT JOIN anti-join).
--     Show full name and signup date.
--     Expected: Nisha Bose, Lucas Moreau



-- Q4. Headcount per department INCLUDING departments with no employees, and
--     the department's budget per employee (NULL when there are no employees
--     or no budget — no division errors!).
--     Expected: 6 rows; Research 0 employees; Engineering 250000.00 per head



-- Q5. Sales team performance: for every employee in Sales (dept 2), the number
--     of DISTINCT orders they handled that were not cancelled or returned,
--     and the revenue of those orders. Employees with no orders must show 0.
--     Expected: Kavya 10 orders, James 8, Pooja 7, Mark 1, Priya 0, Tom 0



-- Q6. Payment check per order: for orders 6, 28, 41 and 44 show the order
--     total and the amount paid. First write the naive 3-table join and see
--     the inflated numbers; then fix it by aggregating each child table first.
--     Expected (fixed): 6 -> 1350 / 1350, 28 -> 1899 / 1899, 41 -> 999 / 999, 44 -> 143.97 / 0



-- Q7. For every customer from India, show their name, number of orders
--     (0 if none), date of their latest order, and total amount they have paid
--     (0 if nothing). Sort by amount paid, highest first.
--     Expected: 8 rows; Aarav Shah first (6 orders)
