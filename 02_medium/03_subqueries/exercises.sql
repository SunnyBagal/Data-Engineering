-- =============================================================================
-- 02_medium/03 · Subqueries — EXERCISES
-- Uses: subqueries + joins (01, 02) + GROUP BY/HAVING (easy/11) + NULLs (easy/08)
--       + DML in a transaction (easy/05)
-- =============================================================================


-- Q1. Products priced above the average product price. Show name, price and
--     how much above the average they are (2 decimals).
--     Expected: 8 rows; average = 392.71



-- Q2. Customers (name, country) who have bought at least one product from the
--     Laptops category. Each customer must appear once. Solve it twice:
--     with IN and with EXISTS.
--     Expected: 8 customers



-- Q3. Customers who have NEVER placed an order, using NOT EXISTS. Then explain
--     why  customer_id NOT IN (SELECT customer_id FROM orders)  happens to work
--     here, but  NOT IN (SELECT referred_by FROM customers)  would not.
--     Expected: Nisha, Lucas



-- Q4. Employees who earn more than the average salary of their own department.
--     Show name, dept_id, salary and the department average (2 decimals).
--     Expected: 7 rows



-- Q5. Each customer's most recent order: customer name, order_id, order_date,
--     status. Use a correlated subquery.
--     Expected: 18 rows; Aarav -> order 43



-- Q6. Average order value per country, excluding cancelled orders.
--     Compute order totals in a derived table first.
--     Expected: USA 918.32 (14 orders) highest, UK 384.44 lowest



-- Q7. (a) Products more expensive than every Phone.
--     (b) Inside a transaction: set stock_qty to 0 for every product whose
--         price is above the average price of its OWN category (correlated
--         subquery in UPDATE), return the affected names, then ROLLBACK.
--     Expected: (a) 3 laptops  (b) 12 rows updated
