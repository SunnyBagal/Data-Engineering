-- =============================================================================
-- 02_medium/12 · Conditional Aggregation & Pivoting — SOLUTIONS
-- =============================================================================


-- Q1.
SELECT EXTRACT(YEAR FROM order_date)::int                       AS year,
       COUNT(*)                                                 AS total,
       COUNT(*) FILTER (WHERE status = 'delivered')             AS delivered,
       COUNT(*) FILTER (WHERE status = 'cancelled')             AS cancelled,
       COUNT(*) FILTER (WHERE status = 'returned')              AS returned,
       COUNT(*) FILTER (WHERE status IN ('pending', 'shipped')) AS open
FROM orders
GROUP BY 1
ORDER BY 1;


-- Q2. Line-level CTE keeps the pivot SELECT readable.
WITH lines AS (
    SELECT cat.category_name, o.order_date,
           oi.quantity * oi.unit_price * (1 - oi.discount) AS revenue
    FROM order_items oi
    JOIN orders o       ON o.order_id      = oi.order_id
    JOIN products p     ON p.product_id    = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.status <> 'cancelled'
)
SELECT category_name,
       ROUND(COALESCE(SUM(revenue) FILTER (WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'), 0), 2) AS y2023,
       ROUND(COALESCE(SUM(revenue) FILTER (WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'), 0), 2) AS y2024,
       ROUND(COALESCE(SUM(revenue) FILTER (WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'), 0), 2) AS y2025,
       ROUND(SUM(revenue), 2) AS total
FROM lines
GROUP BY category_name
ORDER BY total DESC;


-- Q3. SUM(CASE … THEN 1 ELSE 0 END) = count of matching rows, 0 if none.
SELECT country,
       SUM(CASE WHEN EXTRACT(YEAR FROM signup_date) = 2022 THEN 1 ELSE 0 END) AS y2022,
       SUM(CASE WHEN EXTRACT(YEAR FROM signup_date) = 2023 THEN 1 ELSE 0 END) AS y2023,
       SUM(CASE WHEN EXTRACT(YEAR FROM signup_date) = 2024 THEN 1 ELSE 0 END) AS y2024,
       SUM(CASE WHEN EXTRACT(YEAR FROM signup_date) = 2025 THEN 1 ELSE 0 END) AS y2025
FROM customers
GROUP BY country
ORDER BY country;
-- EXTRACT on the column is fine here: it's computed per row inside an
-- aggregate, not used to filter with an index.


-- Q4.
SELECT e.first_name || ' ' || e.last_name                              AS rep,
       COUNT(*) FILTER (WHERE o.status = 'delivered')                  AS delivered,
       COUNT(*) FILTER (WHERE o.status = 'cancelled')                  AS cancelled,
       COUNT(*) FILTER (WHERE o.status = 'returned')                   AS returned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.status IN ('cancelled', 'returned'))
             / COUNT(*), 1)                                            AS problem_rate_pct
FROM orders o
JOIN employees e ON e.emp_id = o.employee_id
GROUP BY e.emp_id, e.first_name, e.last_name
ORDER BY problem_rate_pct DESC;


-- Q5. ISODOW 6 = Saturday, 7 = Sunday.
SELECT device,
       COUNT(*) FILTER (WHERE EXTRACT(ISODOW FROM login_at) NOT IN (6, 7)) AS weekday,
       COUNT(*) FILTER (WHERE EXTRACT(ISODOW FROM login_at) IN (6, 7))     AS weekend,
       ROUND(100.0 * COUNT(*) FILTER (WHERE EXTRACT(ISODOW FROM login_at) IN (6, 7))
             / COUNT(*), 1)                                                AS weekend_pct
FROM logins
GROUP BY device
ORDER BY device;


-- Q6. Build the pivot in a CTE, then compare its columns row-wise.
--     GREATEST is a row-wise max (unlike the MAX aggregate).
WITH p AS (
    SELECT EXTRACT(YEAR FROM paid_at)::int                         AS year,
           SUM(CASE WHEN method = 'card'          THEN amount ELSE 0 END) AS card,
           SUM(CASE WHEN method = 'upi'           THEN amount ELSE 0 END) AS upi,
           SUM(CASE WHEN method = 'paypal'        THEN amount ELSE 0 END) AS paypal,
           SUM(CASE WHEN method = 'bank_transfer' THEN amount ELSE 0 END) AS bank_transfer,
           SUM(CASE WHEN method = 'cash'          THEN amount ELSE 0 END) AS cash
    FROM payments
    GROUP BY 1
)
SELECT p.*,
       CASE GREATEST(card, upi, paypal, bank_transfer, cash)
            WHEN card          THEN 'card'
            WHEN upi           THEN 'upi'
            WHEN paypal        THEN 'paypal'
            WHEN bank_transfer THEN 'bank_transfer'
            ELSE                    'cash' END AS top_method
FROM p
ORDER BY year;


-- Q7. Unpivot with LATERAL VALUES, then drop zero rows.
WITH wide AS (
    SELECT EXTRACT(YEAR FROM order_date)::int                       AS year,
           COUNT(*) FILTER (WHERE status = 'delivered')             AS delivered,
           COUNT(*) FILTER (WHERE status = 'cancelled')             AS cancelled,
           COUNT(*) FILTER (WHERE status = 'returned')              AS returned,
           COUNT(*) FILTER (WHERE status IN ('pending', 'shipped')) AS open
    FROM orders GROUP BY 1
)
SELECT w.year, v.status_group, v.orders
FROM wide w
CROSS JOIN LATERAL (VALUES ('delivered', w.delivered),
                           ('cancelled', w.cancelled),
                           ('returned',  w.returned),
                           ('open',      w.open)) AS v(status_group, orders)
WHERE v.orders > 0
ORDER BY w.year, v.orders DESC;
