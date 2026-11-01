-- =============================================================================
-- 02_medium/07 · Views — EXERCISES
-- Uses: views + CTEs (06) + CASE (05) + joins (01, 02) + constraints & DDL (easy/03, 04)
-- Create everything in a schema called "bi" and drop it at the end.
-- =============================================================================


-- Q1. Create bi.v_order_lines: one row per order line with order_id,
--     order_date, status, customer name, product name, category name,
--     quantity and line revenue (2 decimals). Use it to get revenue per
--     category for DELIVERED orders only.
--     Expected: Laptops first (14010.00)



-- Q2. Create bi.v_order_totals (order_id, customer_id, status, order_date, total)
--     ON TOP of bi.v_order_lines, then bi.v_customer_ltv on top of that:
--     customer_id, name, country, orders (non-cancelled), lifetime value
--     (excluding cancelled & returned), first and last order date.
--     Query: the 3 customers with the highest lifetime value.
--     Expected: Aarav 6725.84, John 4192.49, Maria 3718.97



-- Q3. Create bi.v_org_chart: active employees with name, title, department
--     name ('—' if none) and manager name. Then, using only the view, count
--     people per department.
--     Expected: 19 rows in the view



-- Q4. Create an updatable view bi.v_open_orders over orders showing only
--     'pending' and 'shipped' orders, WITH CHECK OPTION. Inside a transaction:
--       a) mark order 45 as 'shipped' with today's shipped_date through the view (works)
--       b) try to mark order 45 'delivered' through the view (why does it fail?)
--     then ROLLBACK.
--     Expected: 4 open orders



-- Q5. Add a column days_open (days since order_date as of 2025-11-01) to
--     bi.v_open_orders with CREATE OR REPLACE. Then try to rename the
--     existing column status to order_status the same way and explain the error.



-- Q6. Try to DROP bi.v_order_lines. What happens and why? Show the list of
--     views in schema bi from information_schema.views.



-- Q7. Clean up the whole schema in one statement.
