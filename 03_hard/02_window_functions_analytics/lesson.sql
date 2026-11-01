-- =============================================================================
-- 03_hard/02 · Window Functions — Analytics — LESSON
-- =============================================================================


-- A reusable monthly series (collections per month in 2024) for sections 1–4.
-- A TEMP VIEW lives only for this session.
CREATE TEMP VIEW monthly_2024 AS
SELECT DATE_TRUNC('month', paid_at)::date AS month,
       SUM(amount)                        AS revenue
FROM payments
WHERE paid_at >= '2024-01-01' AND paid_at < '2025-01-01'
GROUP BY 1;


-- -----------------------------------------------------------------------------
-- 1. LAG / LEAD: previous and next rows
-- -----------------------------------------------------------------------------

SELECT month,
       revenue,
       LAG(revenue)  OVER (ORDER BY month)       AS prev_month,   -- NULL for the first row
       LEAD(revenue) OVER (ORDER BY month)       AS next_month,   -- NULL for the last row
       LAG(revenue, 1, 0) OVER (ORDER BY month)  AS prev_or_zero, -- 3rd arg = default instead of NULL
       LAG(revenue, 3) OVER (ORDER BY month)     AS three_months_ago
FROM monthly_2024
ORDER BY month;

-- Month-over-month growth %. NULLIF guards against division by zero.
SELECT month,
       revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER w) / NULLIF(LAG(revenue) OVER w, 0), 1) AS mom_pct
FROM monthly_2024
WINDOW w AS (ORDER BY month)
ORDER BY month;


-- -----------------------------------------------------------------------------
-- 2. Running totals and moving averages
-- -----------------------------------------------------------------------------

SELECT month,
       revenue,
       SUM(revenue) OVER (ORDER BY month ROWS UNBOUNDED PRECEDING)          AS running_total,
       ROUND(AVG(revenue) OVER (ORDER BY month
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m,
       SUM(revenue) OVER ()                                                 AS year_total,   -- whole partition
       ROUND(100 * revenue / SUM(revenue) OVER (), 1)                       AS pct_of_year
FROM monthly_2024
ORDER BY month;
-- The first two moving averages use fewer than 3 months (only what exists).


-- -----------------------------------------------------------------------------
-- 3. LAG with PARTITION BY: per-entity sequences
-- -----------------------------------------------------------------------------

-- Days since each customer's previous order. PARTITION BY stops LAG from
-- comparing one customer's first order with another customer's last order.
SELECT customer_id,
       order_id,
       order_date::date                                                    AS order_day,
       order_date::date - LAG(order_date::date) OVER (PARTITION BY customer_id
                                                      ORDER BY order_date) AS days_since_prev
FROM orders
WHERE customer_id IN (1, 3)
ORDER BY customer_id, order_date;

-- Per-customer running spend (cumulative lifetime value over time).
WITH order_totals AS (
    SELECT o.customer_id, o.order_id, o.order_date,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS total
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('cancelled', 'returned')
    GROUP BY o.customer_id, o.order_id, o.order_date
)
SELECT customer_id, order_id, order_date::date,
       ROUND(total, 2) AS total,
       ROUND(SUM(total) OVER (PARTITION BY customer_id ORDER BY order_date
                              ROWS UNBOUNDED PRECEDING), 2) AS lifetime_value_so_far,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_number
FROM order_totals
WHERE customer_id = 1
ORDER BY order_date;


-- -----------------------------------------------------------------------------
-- 4. FIRST_VALUE / LAST_VALUE / NTH_VALUE — and the frame trap
-- -----------------------------------------------------------------------------

SELECT month, revenue,
       FIRST_VALUE(revenue) OVER (ORDER BY month)                    AS first_month,
       -- TRAP: default frame ends at the CURRENT ROW, so this is just "revenue".
       LAST_VALUE(revenue)  OVER (ORDER BY month)                    AS last_wrong,
       -- Fix: extend the frame to the end of the partition.
       LAST_VALUE(revenue)  OVER (ORDER BY month
                                  ROWS BETWEEN UNBOUNDED PRECEDING
                                           AND UNBOUNDED FOLLOWING)  AS last_right,
       NTH_VALUE(revenue, 2) OVER (ORDER BY month
                                  ROWS BETWEEN UNBOUNDED PRECEDING
                                           AND UNBOUNDED FOLLOWING)  AS second_month
FROM monthly_2024
ORDER BY month;

-- Practical use: compare each employee with the best-paid person in their department.
SELECT first_name, dept_id, salary,
       FIRST_VALUE(first_name) OVER (PARTITION BY dept_id ORDER BY salary DESC) AS top_earner,
       salary - FIRST_VALUE(salary) OVER (PARTITION BY dept_id ORDER BY salary DESC) AS gap_to_top
FROM employees
WHERE dept_id IS NOT NULL
ORDER BY dept_id, salary DESC;


-- -----------------------------------------------------------------------------
-- 5. ROWS vs RANGE vs GROUPS: how ties and gaps are treated
-- -----------------------------------------------------------------------------

-- Two orders happened on 2023-11-24 (orders 17 and 18): a tie on the date.
WITH daily AS (
    SELECT order_id, order_date::date AS d, 1 AS one
    FROM orders
    WHERE order_date >= '2023-11-01' AND order_date < '2024-01-01'
)
SELECT order_id, d,
       SUM(one) OVER (ORDER BY d ROWS  UNBOUNDED PRECEDING) AS rows_running,   -- 1,2,3,4: row by row
       SUM(one) OVER (ORDER BY d RANGE UNBOUNDED PRECEDING) AS range_running,  -- 2,2,3,4: tie counted together
       SUM(one) OVER (ORDER BY d)                           AS default_running -- = RANGE (the default!)
FROM daily
ORDER BY d, order_id;

-- RANGE with an interval: a TRUE time window regardless of how many rows exist.
-- Number of logins by the same customer in the 3 days up to each login.
SELECT customer_id, login_at,
       COUNT(*) OVER (PARTITION BY customer_id
                      ORDER BY login_at
                      RANGE BETWEEN INTERVAL '3 days' PRECEDING AND CURRENT ROW) AS logins_last_3_days
FROM logins
WHERE customer_id = 1
ORDER BY login_at;


-- -----------------------------------------------------------------------------
-- 6. Change detection with LAG
-- -----------------------------------------------------------------------------

-- Orders that came right after a customer's cancelled order (did they come back?).
WITH seq AS (
    SELECT customer_id, order_id, status, order_date,
           LAG(status) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_status
    FROM orders
)
SELECT * FROM seq WHERE prev_status = 'cancelled';      -- 2 customers came back


-- -----------------------------------------------------------------------------
-- 7. Filling gaps before using LAG
-- -----------------------------------------------------------------------------

-- In 2025 not every month has payments for 'paypal'. LAG over the raw grouped
-- data would compare non-adjacent months. Build a full calendar first.
WITH months AS (
    SELECT generate_series(DATE '2025-01-01', DATE '2025-09-01', INTERVAL '1 month')::date AS month
),
paypal AS (
    SELECT DATE_TRUNC('month', paid_at)::date AS month, SUM(amount) AS amt
    FROM payments WHERE method = 'paypal' GROUP BY 1
)
SELECT m.month,
       COALESCE(p.amt, 0)                                 AS paypal,
       LAG(COALESCE(p.amt, 0)) OVER (ORDER BY m.month)    AS prev_month   -- truly the previous month
FROM months m
LEFT JOIN paypal p ON p.month = m.month
ORDER BY m.month;
