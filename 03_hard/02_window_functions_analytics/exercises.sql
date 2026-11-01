-- =============================================================================
-- 03_hard/02 · Window Functions — Analytics — EXERCISES
-- Uses: LAG/LEAD/frames + ranking windows (01) + CTEs (medium/06)
--       + joins (medium/01) + date functions (easy/12) + NULLIF (easy/08)
-- =============================================================================


-- Q1. Monthly collections (payments) for 2024 with: previous month, change,
--     month-over-month % (1 decimal), running total and 3-month moving average.
--     Expected: 12 rows; Dec running total 11924.49; Nov MoM +176.6 %



-- Q2. For customer 1 (Aarav), list orders with the number of days since the
--     previous order and until the next order.
--     Expected: gaps 62, 135, 223, 274, 285



-- Q3. Across all customers, the average, minimum and maximum number of days
--     between consecutive orders of the same customer.
--     Expected: 344.1 | 62 | 761



-- Q4. Every employee (with a department) and: the highest salary in their
--     department, the name of who earns it, and the lowest salary — using
--     FIRST_VALUE / LAST_VALUE (watch the frame!).
--     Expected: 18 rows; Engineering top Rahul 180000, lowest 70000



-- Q5. Running count of orders per year: for each order show its year,
--     the order's position in that year (ROW_NUMBER) and the running revenue
--     within the year (ROWS frame).
--     Expected: last 2023 row has running revenue equal to 2023's total



-- Q6. For each customer, the order that came immediately AFTER a cancelled
--     order (if any): customer, cancelled order id, next order id and the days
--     between them.
--     Expected: 2 rows — customer 7 (8 -> 25, 338 days), customer 11 (15 -> 38, 580 days)



-- Q7. Rolling 7-day login count per customer using a RANGE frame with an
--     interval (current login and the 6 days before it), and the maximum
--     value each customer ever reached.
--     Expected: 7 customers; customers 1 and 13 both peak at 7
