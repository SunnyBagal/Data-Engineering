-- =============================================================================
-- 02_medium/02 · Self Joins & Cross Joins — SOLUTIONS
-- =============================================================================


-- Q1. LEFT JOIN keeps the CEO; COALESCE labels the missing manager.
SELECT e.first_name || ' ' || e.last_name                    AS employee,
       e.job_title,
       COALESCE(m.first_name || ' ' || m.last_name, '(none)') AS manager,
       m.job_title                                            AS manager_title
FROM employees e
LEFT JOIN employees m ON m.emp_id = e.manager_id
ORDER BY e.emp_id;


-- Q2. Aggregate the employee side (e), group by the manager side (m).
SELECT m.first_name || ' ' || m.last_name AS manager,
       COUNT(*)                           AS direct_reports,
       ROUND(AVG(e.salary), 2)            AS avg_report_salary
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id
GROUP BY m.emp_id, m.first_name, m.last_name
ORDER BY direct_reports DESC, manager;


-- Q3. "<>": NULL <> 1 is UNKNOWN, so pairs involving the CEO (dept NULL)
--     or the contractor (dept NULL) are dropped -> only Riya (3 vs 2).
SELECT e.first_name, e.dept_id, m.first_name AS manager, m.dept_id AS manager_dept
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id
WHERE e.dept_id <> m.dept_id;                                -- 1 row

-- IS DISTINCT FROM: NULL vs 1 counts as different -> 6 rows.
SELECT e.first_name, e.dept_id, m.first_name AS manager, m.dept_id AS manager_dept
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id
WHERE e.dept_id IS DISTINCT FROM m.dept_id;                  -- 6 rows


-- Q4. First self join is INNER (only referred customers); the second is LEFT
--     (the referrer may not have been referred by anyone).
SELECT c.first_name || ' ' || c.last_name AS customer,
       r.first_name || ' ' || r.last_name AS referred_by,
       g.first_name || ' ' || g.last_name AS referrer_referred_by
FROM customers c
JOIN customers r      ON r.customer_id = c.referred_by
LEFT JOIN customers g ON g.customer_id = r.referred_by
ORDER BY c.customer_id;


-- Q5.
SELECT a.city,
       a.first_name || ' ' || a.last_name AS customer_a,
       b.first_name || ' ' || b.last_name AS customer_b
FROM customers a
JOIN customers b
  ON a.city = b.city
 AND a.customer_id < b.customer_id          -- each pair once, no self-pairs
ORDER BY a.city;


-- Q6.
SELECT cat.category_name,
       a.product_name, b.product_name AS other_product,
       ABS(a.price - b.price)         AS price_diff
FROM products a
JOIN products b
  ON a.category_id = b.category_id
 AND a.product_id  < b.product_id
 AND ABS(a.price - b.price) <= 20
JOIN categories cat ON cat.category_id = a.category_id
ORDER BY cat.category_name, price_diff;


-- Q7. Scaffold (years × methods) with CROSS JOIN, then attach facts with a
--     LEFT JOIN so empty combinations survive; COALESCE turns NULL sums into 0.
SELECT y.year,
       m.method,
       COALESCE(SUM(p.amount), 0) AS collected
FROM generate_series(2023, 2025) AS y(year)
CROSS JOIN (SELECT DISTINCT method FROM payments) AS m
LEFT JOIN payments p
       ON p.method = m.method
      AND p.paid_at >= MAKE_DATE(y.year, 1, 1)
      AND p.paid_at <  MAKE_DATE(y.year + 1, 1, 1)
GROUP BY y.year, m.method
ORDER BY y.year, m.method;
-- Tip: in production, the list of methods should come from a reference table
-- (payment_methods), so methods with NO payments ever also appear.
