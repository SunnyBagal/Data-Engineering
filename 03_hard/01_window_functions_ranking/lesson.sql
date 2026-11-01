-- =============================================================================
-- 03_hard/01 · Window Functions — Ranking — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. GROUP BY collapses rows; a window function keeps them
-- -----------------------------------------------------------------------------

-- GROUP BY: one row per department, employee detail is gone.
SELECT dept_id, AVG(salary) AS avg_salary
FROM employees
GROUP BY dept_id;

-- Window: every employee stays, with the department average alongside.
-- PARTITION BY dept_id = "compute the AVG separately for each department".
SELECT first_name, dept_id, salary,
       ROUND(AVG(salary) OVER (PARTITION BY dept_id), 2) AS dept_avg,
       COUNT(*)          OVER (PARTITION BY dept_id)     AS dept_size,
       COUNT(*)          OVER ()                         AS company_size   -- empty OVER = all rows
FROM employees
ORDER BY dept_id, salary DESC;


-- -----------------------------------------------------------------------------
-- 2. ROW_NUMBER vs RANK vs DENSE_RANK
-- -----------------------------------------------------------------------------

-- Engineering has a tie: Emily and Vikram both earn 95,000.
-- WINDOW w defines the window once; all three functions reuse it (one sort).
SELECT first_name, salary,
       ROW_NUMBER() OVER w AS row_number,   -- 1..6, tie broken arbitrarily
       RANK()       OVER w AS rank,         -- 1,2,3,4,4,6  (gap after the tie)
       DENSE_RANK() OVER w AS dense_rank    -- 1,2,3,4,4,5  (no gap)
FROM employees
WHERE dept_id = 1
WINDOW w AS (ORDER BY salary DESC);

-- Make ROW_NUMBER deterministic with a tie-breaker (here: earlier hire first).
SELECT first_name, salary, hire_date,
       ROW_NUMBER() OVER (ORDER BY salary DESC, hire_date) AS stable_rn
FROM employees
WHERE dept_id = 1;


-- -----------------------------------------------------------------------------
-- 3. PARTITION BY: rank within each group
-- -----------------------------------------------------------------------------

-- Salary rank inside each department. Numbering restarts at 1 per partition.
SELECT d.dept_name, e.first_name, e.salary,
       DENSE_RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS rank_in_dept
FROM employees e
JOIN departments d ON d.dept_id = e.dept_id
ORDER BY d.dept_name, rank_in_dept;


-- -----------------------------------------------------------------------------
-- 4. Filtering on a window result: wrap it (CTE or subquery)
-- -----------------------------------------------------------------------------

-- Not allowed (window functions run after WHERE):
-- SELECT * FROM employees WHERE ROW_NUMBER() OVER (ORDER BY salary DESC) = 1;
--   ERROR: window functions are not allowed in WHERE

-- Top earner per department: number rows per partition, keep rn = 1.
WITH ranked AS (
    SELECT dept_id, first_name, salary,
           ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC, emp_id) AS rn
    FROM employees
    WHERE dept_id IS NOT NULL
)
SELECT dept_id, first_name, salary
FROM ranked
WHERE rn = 1
ORDER BY dept_id;

-- 2nd highest DISTINCT salary per department: DENSE_RANK = 2
-- (ROW_NUMBER = 2 would return Vikram's 95,000 tie in some runs, wrongly).
WITH ranked AS (
    SELECT dept_id, first_name, salary,
           DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dr
    FROM employees
    WHERE dept_id IS NOT NULL
)
SELECT * FROM ranked WHERE dr = 2 ORDER BY dept_id;


-- -----------------------------------------------------------------------------
-- 5. Ranking aggregated values (window over GROUP BY)
-- -----------------------------------------------------------------------------

-- Windows run AFTER grouping, so they can rank aggregates directly.
-- Top 2 products by revenue in each category.
WITH product_revenue AS (
    SELECT cat.category_name,
           p.product_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue,
           RANK() OVER (PARTITION BY cat.category_id
                        ORDER BY SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) DESC) AS rk
    FROM order_items oi
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    GROUP BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT category_name, product_name, ROUND(revenue, 2) AS revenue, rk
FROM product_revenue
WHERE rk <= 2
ORDER BY category_name, rk;


-- -----------------------------------------------------------------------------
-- 6. Latest row per key (and the DISTINCT ON alternative)
-- -----------------------------------------------------------------------------

-- Each customer's most recent order.
WITH ordered AS (
    SELECT o.*,
           ROW_NUMBER() OVER (PARTITION BY customer_id
                              ORDER BY order_date DESC, order_id DESC) AS rn
    FROM orders o
)
SELECT customer_id, order_id, order_date, status
FROM ordered
WHERE rn = 1
ORDER BY customer_id;                                    -- 18 rows

-- Postgres shortcut — same result, often faster with an index on (customer_id, order_date):
SELECT DISTINCT ON (customer_id) customer_id, order_id, order_date, status
FROM orders
ORDER BY customer_id, order_date DESC, order_id DESC;


-- -----------------------------------------------------------------------------
-- 7. Deduplication with ROW_NUMBER
-- -----------------------------------------------------------------------------

-- Logins: keep only the FIRST login per customer per day (a typical cleanup).
-- PARTITION BY the columns that define a "duplicate"; ORDER BY decides which to keep.
WITH numbered AS (
    SELECT login_id, customer_id, login_at,
           ROW_NUMBER() OVER (PARTITION BY customer_id, login_at::date
                              ORDER BY login_at) AS rn
    FROM logins
)
SELECT COUNT(*) FILTER (WHERE rn = 1) AS kept,
       COUNT(*) FILTER (WHERE rn > 1) AS duplicates
FROM numbered;                                           -- 30 kept, 7 duplicates

-- Deleting the duplicates (rolled back):
BEGIN;
DELETE FROM logins
WHERE login_id IN (
    SELECT login_id FROM (
        SELECT login_id,
               ROW_NUMBER() OVER (PARTITION BY customer_id, login_at::date ORDER BY login_at) AS rn
        FROM logins
    ) x
    WHERE rn > 1
);                                                       -- DELETE 7
ROLLBACK;


-- -----------------------------------------------------------------------------
-- 8. NTILE, PERCENT_RANK, CUME_DIST: segmentation
-- -----------------------------------------------------------------------------

-- Spend quartiles of buying customers (1 = top 25%).
WITH spend AS (
    SELECT o.customer_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS spend
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('cancelled', 'returned')
    GROUP BY o.customer_id
)
SELECT customer_id,
       ROUND(spend, 2)                                   AS spend,
       NTILE(4)       OVER (ORDER BY spend DESC)         AS quartile,
       ROUND(PERCENT_RANK() OVER (ORDER BY spend)::numeric, 2) AS pct_rank,   -- 0 = lowest
       ROUND(CUME_DIST()    OVER (ORDER BY spend)::numeric, 2) AS cume_dist
FROM spend
ORDER BY spend DESC;
-- 18 customers / 4 buckets -> bucket sizes 5, 5, 4, 4.
