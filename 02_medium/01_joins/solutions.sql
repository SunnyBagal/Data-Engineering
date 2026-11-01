-- =============================================================================
-- 02_medium/01 · Joins — SOLUTIONS
-- =============================================================================


-- Q1. customers is mandatory (INNER JOIN); the employee is optional (LEFT JOIN),
--     otherwise the 15 online orders would disappear.
SELECT o.order_id,
       o.order_date::date                                      AS order_day,
       c.first_name || ' ' || c.last_name                      AS customer,
       c.country,
       o.status,
       COALESCE(e.first_name || ' ' || e.last_name, 'Online')  AS handled_by
FROM orders o
JOIN customers c      ON c.customer_id = o.customer_id
LEFT JOIN employees e ON e.emp_id      = o.employee_id
ORDER BY o.order_id;


-- Q2.
SELECT cat.category_name,
       SUM(oi.quantity)                                               AS units,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2) AS revenue
FROM order_items oi
JOIN products   p   ON p.product_id    = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
GROUP BY cat.category_id, cat.category_name     -- group by the id: names might not be unique
ORDER BY revenue DESC;


-- Q3. Anti-join: unmatched customers have NULL in every orders column.
SELECT c.first_name || ' ' || c.last_name AS customer, c.signup_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;


-- Q4. COUNT(e.emp_id) gives 0 for Research; NULLIF prevents division by zero.
SELECT d.dept_name,
       COUNT(e.emp_id)                                AS headcount,
       ROUND(d.budget / NULLIF(COUNT(e.emp_id), 0), 2) AS budget_per_head
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name, d.budget
ORDER BY d.dept_id;


-- Q5. The status filter is in ON so that reps without qualifying orders keep
--     their row. COUNT(DISTINCT o.order_id) because joining order_items
--     creates one row per LINE, not per order.
SELECT e.first_name || ' ' || e.last_name                                      AS rep,
       COUNT(DISTINCT o.order_id)                                              AS orders,
       COALESCE(ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2), 0) AS revenue
FROM employees e
LEFT JOIN orders o
       ON o.employee_id = e.emp_id
      AND o.status NOT IN ('cancelled', 'returned')
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE e.dept_id = 2                       -- filter on the LEFT (preserved) table: WHERE is right
GROUP BY e.emp_id, e.first_name, e.last_name
ORDER BY orders DESC, revenue DESC;


-- Q6. Naive: every item row is repeated once per payment and vice versa.
SELECT o.order_id,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS order_total_wrong,
       SUM(p.amount)                                        AS paid_wrong
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN payments p ON p.order_id = o.order_id
WHERE o.order_id IN (6, 28, 41, 44)
GROUP BY o.order_id
ORDER BY o.order_id;            -- 6: 2700/1350, 28: 3798/3798, 41: 1998/999 — all wrong somewhere

-- Fixed: pre-aggregate to one row per order, then join 1:1.
SELECT o.order_id,
       ROUND(t.order_total, 2) AS order_total,
       COALESCE(p.paid, 0)     AS paid
FROM orders o
JOIN (SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS order_total
      FROM order_items
      GROUP BY order_id) t ON t.order_id = o.order_id
LEFT JOIN (SELECT order_id, SUM(amount) AS paid
           FROM payments
           GROUP BY order_id) p ON p.order_id = o.order_id
WHERE o.order_id IN (6, 28, 41, 44)
ORDER BY o.order_id;


-- Q7. Orders and payments are both children of the customer -> fan-out again
--     if joined directly. Aggregate payments per customer first.
SELECT c.first_name || ' ' || c.last_name AS customer,
       COUNT(o.order_id)                  AS orders,
       MAX(o.order_date)                  AS latest_order,
       COALESCE(MAX(pc.paid), 0)          AS total_paid   -- one pc row per customer -> MAX just picks it
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
LEFT JOIN (SELECT o2.customer_id, SUM(p.amount) AS paid
           FROM payments p
           JOIN orders o2 ON o2.order_id = p.order_id
           GROUP BY o2.customer_id) pc ON pc.customer_id = c.customer_id
WHERE c.country = 'India'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_paid DESC;
