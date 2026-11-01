-- =============================================================================
-- 03_hard/02 · Window Functions — Analytics — SOLUTIONS
-- =============================================================================


-- Q1. Monthly aggregation in a CTE, then window functions on top.
WITH monthly AS (
    SELECT DATE_TRUNC('month', paid_at)::date AS month, SUM(amount) AS revenue
    FROM payments
    WHERE paid_at >= '2024-01-01' AND paid_at < '2025-01-01'
    GROUP BY 1
)
SELECT month,
       revenue,
       LAG(revenue) OVER w                                                           AS prev_month,
       revenue - LAG(revenue) OVER w                                                 AS change,
       ROUND(100 * (revenue - LAG(revenue) OVER w) / NULLIF(LAG(revenue) OVER w, 0), 1) AS mom_pct,
       SUM(revenue) OVER (w ROWS UNBOUNDED PRECEDING)                                AS running_total,
       ROUND(AVG(revenue) OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)      AS moving_avg_3m
FROM monthly
WINDOW w AS (ORDER BY month)            -- frames can extend a named window: OVER (w ROWS …)
ORDER BY month;


-- Q2.
SELECT order_id,
       order_date::date                                                AS order_day,
       order_date::date - LAG(order_date::date)  OVER w                AS days_since_prev,
       LEAD(order_date::date) OVER w - order_date::date                AS days_until_next
FROM orders
WHERE customer_id = 1
WINDOW w AS (ORDER BY order_date)
ORDER BY order_date;


-- Q3. PARTITION BY customer so gaps are only measured within one customer;
--     first orders produce NULL gaps, which AVG/MIN/MAX ignore.
WITH gaps AS (
    SELECT order_date::date - LAG(order_date::date) OVER (PARTITION BY customer_id
                                                          ORDER BY order_date) AS gap_days
    FROM orders
)
SELECT ROUND(AVG(gap_days), 1) AS avg_gap, MIN(gap_days) AS min_gap, MAX(gap_days) AS max_gap
FROM gaps;


-- Q4. FIRST_VALUE with DESC gives the top; for the lowest, LAST_VALUE needs the
--     full frame (or FIRST_VALUE with ASC, which avoids the trap entirely).
SELECT first_name, dept_id, salary,
       FIRST_VALUE(salary)     OVER w_desc                                   AS dept_max,
       FIRST_VALUE(first_name) OVER w_desc                                   AS top_earner,
       LAST_VALUE(salary)      OVER (w_desc ROWS BETWEEN UNBOUNDED PRECEDING
                                                   AND UNBOUNDED FOLLOWING)   AS dept_min
FROM employees
WHERE dept_id IS NOT NULL
WINDOW w_desc AS (PARTITION BY dept_id ORDER BY salary DESC)
ORDER BY dept_id, salary DESC;


-- Q5. ROWS frame -> strict row-by-row running sum within each year.
WITH order_totals AS (
    SELECT o.order_id, o.order_date,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS total
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.order_date
)
SELECT EXTRACT(YEAR FROM order_date)::int                                    AS year,
       order_id,
       ROUND(total, 2)                                                       AS total,
       ROW_NUMBER() OVER (PARTITION BY EXTRACT(YEAR FROM order_date)
                          ORDER BY order_date)                               AS nth_in_year,
       ROUND(SUM(total) OVER (PARTITION BY EXTRACT(YEAR FROM order_date)
                              ORDER BY order_date ROWS UNBOUNDED PRECEDING), 2) AS running_year_revenue
FROM order_totals
ORDER BY order_date;


-- Q6. LEAD looks forward to the next order of the same customer.
WITH seq AS (
    SELECT customer_id, order_id, status, order_date,
           LEAD(order_id)   OVER w AS next_order_id,
           LEAD(order_date) OVER w AS next_order_date
    FROM orders
    WINDOW w AS (PARTITION BY customer_id ORDER BY order_date)
)
SELECT customer_id,
       order_id                                   AS cancelled_order,
       next_order_id,
       next_order_date::date - order_date::date   AS days_between
FROM seq
WHERE status = 'cancelled'
  AND next_order_id IS NOT NULL;                  -- customer 10 never ordered again


-- Q7. RANGE + INTERVAL counts by TIME, not by number of rows.
WITH rolling AS (
    SELECT customer_id, login_at,
           COUNT(*) OVER (PARTITION BY customer_id
                          ORDER BY login_at
                          RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW) AS logins_7d
    FROM logins
)
SELECT customer_id, MAX(logins_7d) AS peak_7_day_logins
FROM rolling
GROUP BY customer_id
ORDER BY peak_7_day_logins DESC, customer_id;
