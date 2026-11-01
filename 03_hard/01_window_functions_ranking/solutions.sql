-- =============================================================================
-- 03_hard/01 · Window Functions — Ranking — SOLUTIONS
-- =============================================================================


-- Q1. ROW_NUMBER always increments (tie order arbitrary -> add emp_id),
--     RANK leaves a gap after a tie, DENSE_RANK doesn't.
SELECT first_name, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, emp_id) AS rn,
       RANK()       OVER (ORDER BY salary DESC)         AS rk,
       DENSE_RANK() OVER (ORDER BY salary DESC)         AS drk
FROM employees
WHERE dept_id = 1;


-- Q2. Three aggregates over the same partition; the WINDOW clause avoids
--     repeating (and re-sorting) the definition.
SELECT first_name, dept_id, salary,
       ROUND(AVG(salary) OVER w, 2)                 AS dept_avg,
       ROUND(salary - AVG(salary) OVER w, 2)        AS diff_from_avg,
       ROUND(100 * salary / SUM(salary) OVER w, 1)  AS pct_of_dept_payroll
FROM employees
WHERE dept_id IS NOT NULL
WINDOW w AS (PARTITION BY dept_id)
ORDER BY dept_id, salary DESC;


-- Q3. DENSE_RANK: ties share a rank and the next distinct value is rank 2.
WITH ranked AS (
    SELECT dept_id, first_name, salary,
           DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dr
    FROM employees
    WHERE dept_id IS NOT NULL
)
SELECT dept_id, first_name, salary
FROM ranked
WHERE dr = 2
ORDER BY dept_id;


-- Q4. Window over an aggregate: rank by SUM(...) inside the grouped query.
WITH product_revenue AS (
    SELECT cat.category_name,
           p.product_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue,
           RANK() OVER (PARTITION BY cat.category_id
                        ORDER BY SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) DESC) AS rk
    FROM order_items oi
    JOIN products p     ON p.product_id    = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    GROUP BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT category_name, product_name, ROUND(revenue, 2) AS revenue, rk
FROM product_revenue
WHERE rk <= 2
ORDER BY category_name, rk;


-- Q5.
WITH order_totals AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items GROUP BY order_id
),
numbered AS (
    SELECT o.customer_id, o.order_id, o.order_date, t.total,
           ROW_NUMBER() OVER (PARTITION BY o.customer_id
                              ORDER BY o.order_date, o.order_id) AS rn     -- earliest first
    FROM orders o
    JOIN order_totals t ON t.order_id = o.order_id
)
SELECT customer_id, order_id, order_date, ROUND(total, 2) AS total
FROM numbered
WHERE rn = 1
ORDER BY customer_id;

-- Cross-check: DISTINCT ON keeps the first row per customer in ORDER BY order.
SELECT DISTINCT ON (customer_id) customer_id, order_id, order_date
FROM orders
ORDER BY customer_id, order_date, order_id;


-- Q6.
BEGIN;
DELETE FROM logins
WHERE login_id IN (
    SELECT login_id
    FROM (SELECT login_id,
                 ROW_NUMBER() OVER (PARTITION BY customer_id, login_at::date
                                    ORDER BY login_at, login_id) AS rn
          FROM logins) x
    WHERE rn > 1
);                                                        -- DELETE 7
SELECT COUNT(*) AS remaining FROM logins;                 -- 30
ROLLBACK;


-- Q7. Aggregate per (year, rep) in a CTE, rank in a second step, filter in a third.
WITH rep_year AS (
    SELECT EXTRACT(YEAR FROM o.order_date)::int AS year,
           e.first_name || ' ' || e.last_name   AS rep,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM orders o
    JOIN employees e    ON e.emp_id    = o.employee_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'delivered'
    GROUP BY 1, e.emp_id, e.first_name, e.last_name
),
ranked AS (
    SELECT year, rep, revenue,
           RANK() OVER (PARTITION BY year ORDER BY revenue DESC) AS rk
    FROM rep_year
)
SELECT year, rep, ROUND(revenue, 2) AS revenue, rk
FROM ranked
WHERE rk = 1
ORDER BY year;
