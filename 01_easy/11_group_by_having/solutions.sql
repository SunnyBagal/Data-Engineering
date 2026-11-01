-- =============================================================================
-- 01_easy/11 · GROUP BY & HAVING — SOLUTIONS
-- =============================================================================


-- Q1. Sorting by the alias, then by country to make ties deterministic.
SELECT country, COUNT(*) AS customers
FROM customers
GROUP BY country
ORDER BY customers DESC, country;


-- Q2. Grouping by two things: an expression and a column.
SELECT EXTRACT(YEAR FROM order_date) AS year,
       status,
       COUNT(*)                      AS orders
FROM orders
GROUP BY year, status
ORDER BY year, orders DESC;
-- Cancellations: 2023 -> orders 8, 15 (2); 2024 -> order 29 (1).


-- Q3. The filter is on an aggregate, so it must go in HAVING.
SELECT order_id,
       ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS order_total
FROM order_items
GROUP BY order_id
HAVING SUM(quantity * unit_price * (1 - discount)) > 2000
ORDER BY order_total DESC;


-- Q4. WHERE removes inactive staff (row filter); HAVING keeps rich departments
--     (group filter). COALESCE needs matching types -> cast dept_id to text.
SELECT COALESCE(dept_id::text, 'no dept') AS dept,
       COUNT(*)                           AS headcount,
       ROUND(AVG(salary), 2)              AS avg_salary
FROM employees
WHERE is_active
GROUP BY dept_id
HAVING AVG(salary) > 100000
ORDER BY avg_salary DESC;
-- Note: GROUP BY dept_id (the raw column) and SELECT a function of it is fine.


-- Q5.
SELECT customer_id,
       COUNT(*)        AS orders,
       MIN(order_date) AS first_order,
       MAX(order_date) AS last_order
FROM orders
WHERE status <> 'cancelled'
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY orders DESC, customer_id;


-- Q6. Products 8, 20 and 19 all sold 6 units; revenue breaks the tie.
SELECT product_id,
       SUM(quantity)                                         AS units,
       ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS revenue
FROM order_items
GROUP BY product_id
ORDER BY units DESC, revenue DESC
LIMIT 5;


-- Q7a.
SELECT method,
       COUNT(*)              AS payments,
       SUM(amount)           AS total,
       ROUND(AVG(amount), 2) AS avg_amount
FROM payments
GROUP BY method
HAVING SUM(amount) > 2000
ORDER BY total DESC;

-- Q7b. DATE_TRUNC returns a timestamp at the start of the month; ::date for display.
SELECT DATE_TRUNC('month', paid_at)::date AS month,
       COUNT(*)                           AS payments
FROM payments
WHERE paid_at >= '2025-01-01' AND paid_at < '2026-01-01'
GROUP BY DATE_TRUNC('month', paid_at)
ORDER BY month;
