-- =============================================================================
-- 02_medium/06 · CTEs — SOLUTIONS
-- =============================================================================


-- Q1. The tier CASE is written ONCE, then grouped — compare with topic 05.
WITH order_totals AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items
    GROUP BY order_id
),
customer_spend AS (
    SELECT c.customer_id, COALESCE(SUM(ot.total), 0) AS spend
    FROM customers c
    LEFT JOIN orders o        ON o.customer_id = c.customer_id
                             AND o.status NOT IN ('cancelled', 'returned')
    LEFT JOIN order_totals ot ON ot.order_id = o.order_id
    GROUP BY c.customer_id
),
tiers AS (
    SELECT customer_id, spend,
           CASE WHEN spend >= 3000 THEN 'gold'
                WHEN spend >= 1000 THEN 'silver'
                WHEN spend >  0    THEN 'bronze'
                ELSE                    'none' END AS tier
    FROM customer_spend
)
SELECT tier, COUNT(*) AS customers
FROM tiers
GROUP BY tier
ORDER BY MIN(spend) DESC;


-- Q2. "stats" holds one row; CROSS JOIN attaches it to every month.
WITH order_totals AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items GROUP BY order_id
),
monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month, SUM(ot.total) AS revenue
    FROM orders o
    JOIN order_totals ot ON ot.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.order_date >= '2024-01-01' AND o.order_date < '2025-01-01'
    GROUP BY 1
),
stats AS (SELECT AVG(revenue) AS avg_revenue FROM monthly)
SELECT TO_CHAR(m.month, 'Mon YYYY')  AS month,
       ROUND(m.revenue, 2)           AS revenue,
       ROUND(s.avg_revenue, 2)       AS avg_month
FROM monthly m CROSS JOIN stats s
WHERE m.revenue > s.avg_revenue
ORDER BY m.month;


-- Q3. Compute the share in one CTE, label it in the final SELECT.
WITH category_revenue AS (
    SELECT cat.category_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM order_items oi
    JOIN products p     ON p.product_id    = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    GROUP BY cat.category_name
),
shares AS (
    SELECT category_name, revenue,
           100 * revenue / (SELECT SUM(revenue) FROM category_revenue) AS share
    FROM category_revenue
)
SELECT category_name,
       ROUND(revenue, 2) AS revenue,
       ROUND(share, 1)   AS share_pct,
       CASE WHEN share >= 15 THEN 'core' ELSE 'niche' END AS segment
FROM shares
ORDER BY revenue DESC;


-- Q4. Per-customer spend -> per-country max -> join back to find who has it.
WITH order_totals AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items GROUP BY order_id
),
spend AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer, c.country,
           SUM(ot.total) AS spend
    FROM customers c
    JOIN orders o        ON o.customer_id = c.customer_id
    JOIN order_totals ot ON ot.order_id   = o.order_id
    WHERE o.status NOT IN ('cancelled', 'returned')
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country
),
country_max AS (
    SELECT country, MAX(spend) AS max_spend FROM spend GROUP BY country
)
SELECT s.country, s.customer, ROUND(s.spend, 2) AS spend
FROM spend s
JOIN country_max m ON m.country = s.country AND m.max_spend = s.spend
ORDER BY s.spend DESC;


-- Q5. COUNT(*) FILTER inside one SELECT over the per-customer CTE.
WITH customer_orders AS (
    SELECT customer_id, COUNT(*) AS orders
    FROM orders
    WHERE status <> 'cancelled'
    GROUP BY customer_id
)
SELECT COUNT(*) FILTER (WHERE orders > 1)                              AS repeat_customers,
       COUNT(*)                                                        AS buying_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 1) AS repeat_rate_pct
FROM customer_orders;


-- Q6. LEFT JOIN from products keeps never-sold items; COALESCE turns NULLs to 0.
WITH sales AS (
    SELECT product_id,
           SUM(quantity)                               AS units,
           SUM(quantity * unit_price * (1 - discount)) AS revenue
    FROM order_items
    GROUP BY product_id
),
scorecard AS (
    SELECT p.product_name,
           COALESCE(s.units, 0)                       AS units,
           COALESCE(s.revenue, 0)                     AS revenue,
           COALESCE(s.revenue - s.units * p.cost, 0)  AS gross_profit,
           s.product_id IS NULL                       AS never_sold
    FROM products p
    LEFT JOIN sales s ON s.product_id = p.product_id
)
SELECT product_name, units, ROUND(revenue, 2) AS revenue, ROUND(gross_profit, 2) AS gross_profit,
       CASE WHEN never_sold           THEN 'never sold'
            WHEN gross_profit >= 1000 THEN 'top seller'
            ELSE                           'regular' END AS status
FROM scorecard
ORDER BY gross_profit DESC;


-- Q7. All sub-statements of a WITH run on the SAME snapshot, and the FK check
--     on orders' delete happens at the end of the statement — by which time the
--     payments CTE has also deleted the referencing rows. So deleting payments
--     in an earlier CTE DOES work here, in a single atomic statement.
BEGIN;
CREATE TEMP TABLE orders_returned (LIKE orders);

WITH gone_payments AS (
    DELETE FROM payments
    WHERE order_id IN (SELECT order_id FROM orders WHERE status = 'returned')
    RETURNING order_id
),
moved AS (
    DELETE FROM orders
    WHERE status = 'returned'
    RETURNING *
)
INSERT INTO orders_returned
SELECT * FROM moved;

SELECT order_id, customer_id, status FROM orders_returned ORDER BY order_id;   -- 4, 20, 37
ROLLBACK;
-- In real life you'd archive the payments too (another CTE inserting from
-- gone_payments' full rows) — deleting financial history is rarely acceptable.
