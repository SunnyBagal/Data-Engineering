-- =============================================================================
-- 03_hard/13 · Interview & Real-World SQL Patterns — SOLUTIONS
-- =============================================================================


-- Q1. Pattern: TOP-N PER GROUP (with ties -> RANK).
WITH spend AS (
    SELECT c.customer_id, c.country, c.first_name || ' ' || c.last_name AS customer,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS ltv
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.status NOT IN ('cancelled', 'returned')
    GROUP BY c.customer_id, c.country, c.first_name, c.last_name
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY country ORDER BY ltv DESC) AS rnk
    FROM spend
)
SELECT country, customer, ROUND(ltv, 2) AS ltv, rnk
FROM ranked
WHERE rnk <= 2
ORDER BY country, rnk;


-- Q2. Pattern: GAPS & ISLANDS, then MAX per group.
WITH days AS (
    SELECT DISTINCT customer_id, login_at::date AS day FROM logins      -- dedupe same-day logins
),
islands AS (
    SELECT customer_id,
           day - (ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY day))::int AS island_key
    FROM days
),
streaks AS (
    SELECT customer_id, COUNT(*) AS streak_days
    FROM islands
    GROUP BY customer_id, island_key
)
SELECT customer_id, MAX(streak_days) AS longest_streak
FROM streaks
GROUP BY customer_id
ORDER BY longest_streak DESC, customer_id;


-- Q3. Pattern: SESSIONIZATION (LAG -> flag -> running SUM).
WITH flagged AS (
    SELECT customer_id, login_at,
           CASE WHEN login_at - LAG(login_at) OVER w <= INTERVAL '30 minutes' THEN 0 ELSE 1 END AS new_session
           -- first row: LAG is NULL -> comparison is NULL -> ELSE 1 (a new session). Neat!
    FROM logins
    WINDOW w AS (PARTITION BY customer_id ORDER BY login_at)
),
sessions AS (
    SELECT customer_id,
           SUM(new_session) OVER (PARTITION BY customer_id ORDER BY login_at
                                  ROWS UNBOUNDED PRECEDING) AS session_no
    FROM flagged
)
SELECT customer_id,
       COUNT(DISTINCT session_no)                         AS sessions,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT session_no), 2) AS avg_events_per_session
FROM sessions
GROUP BY customer_id
ORDER BY customer_id;


-- Q4. Pattern: PERIOD-OVER-PERIOD per entity (pivot two years side by side).
WITH yearly AS (
    SELECT o.customer_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount))
               FILTER (WHERE o.order_date >= '2023-01-01' AND o.order_date < '2024-01-01') AS rev_2023,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount))
               FILTER (WHERE o.order_date >= '2024-01-01' AND o.order_date < '2025-01-01') AS rev_2024
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.customer_id
)
SELECT customer_id,
       ROUND(rev_2023, 2) AS rev_2023,
       ROUND(rev_2024, 2) AS rev_2024,
       ROUND(100 * (rev_2024 - rev_2023) / rev_2023, 1) AS growth_pct
FROM yearly
WHERE rev_2024 > rev_2023                    -- NULL in either year -> comparison NULL -> excluded
ORDER BY customer_id;


-- Q5. Pattern: COHORTS (first activity) + conditional aggregation.
WITH active AS (
    SELECT DISTINCT customer_id, EXTRACT(YEAR FROM order_date)::int AS year
    FROM orders WHERE status <> 'cancelled'
),
first_year AS (
    SELECT customer_id, MIN(year) AS first_year FROM active GROUP BY customer_id
)
SELECT a.year,
       COUNT(*) FILTER (WHERE a.year = f.first_year) AS new_customers,
       COUNT(*) FILTER (WHERE a.year > f.first_year) AS returning_customers
FROM active a
JOIN first_year f ON f.customer_id = a.customer_id
GROUP BY a.year
ORDER BY a.year;


-- Q6. Pattern: MARKET BASKET (self-join lines on the same order).
SELECT p.product_name AS also_bought, COUNT(*) AS times
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND b.product_id <> a.product_id
JOIN products p    ON p.product_id = b.product_id
WHERE a.product_id = 6
GROUP BY p.product_name
ORDER BY times DESC, also_bought;


-- Q7a. Pattern: MISSING VALUES (calendar anti-join).
SELECT d::date AS day_without_logins
FROM generate_series(DATE '2025-09-01', DATE '2025-09-30', INTERVAL '1 day') AS d
WHERE NOT EXISTS (SELECT 1 FROM logins l
                  WHERE l.login_at >= d AND l.login_at < d + INTERVAL '1 day')
ORDER BY 1;                                                         -- 15 days

-- Q7b. Pattern: RELATIONAL DIVISION (count distinct = count of all).
WITH RECURSIVE tree AS (
    SELECT category_id, category_id AS root_id FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, t.root_id FROM categories c JOIN tree t ON c.parent_id = t.category_id
)
SELECT o.customer_id
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN tree t         ON t.category_id = p.category_id
GROUP BY o.customer_id
HAVING COUNT(DISTINCT t.root_id) = (SELECT COUNT(*) FROM categories WHERE parent_id IS NULL);  -- 12

-- Q7c. Pattern: NTH PER GROUP (recursive tree + DENSE_RANK).
WITH RECURSIVE tree AS (
    SELECT category_id, category_id AS root_id FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, t.root_id FROM categories c JOIN tree t ON c.parent_id = t.category_id
),
ranked AS (
    SELECT r.category_name AS root_category, p.product_name, p.price,
           DENSE_RANK() OVER (PARTITION BY t.root_id ORDER BY p.price DESC) AS dr
    FROM products p
    JOIN tree t       ON t.category_id = p.category_id
    JOIN categories r ON r.category_id = t.root_id
)
SELECT root_category, product_name, price
FROM ranked
WHERE dr = 2
ORDER BY root_category;
