-- =============================================================================
-- 03_hard/04 · Advanced Grouping & LATERAL — SOLUTIONS
-- =============================================================================


-- Q1. A CTE with the year column keeps the GROUPING() expressions short.
WITH p AS (
    SELECT EXTRACT(YEAR FROM paid_at)::int AS year, method, amount FROM payments
)
SELECT CASE WHEN GROUPING(year)   = 1 THEN 'All years'   ELSE year::text END AS year,
       CASE WHEN GROUPING(method) = 1 THEN 'All methods' ELSE method    END AS method,
       SUM(amount) AS total
FROM p
GROUP BY ROLLUP (year, method)
ORDER BY GROUPING(year), p.year, GROUPING(method), method;


-- Q2. CUBE(country, status): detail combos + per-country + per-status + total.
WITH c AS (
    SELECT cu.country, o.status
    FROM orders o JOIN customers cu ON cu.customer_id = o.customer_id
)
SELECT CASE WHEN GROUPING(country) = 1 THEN '(all)' ELSE country END AS country,
       CASE WHEN GROUPING(status)  = 1 THEN '(all)' ELSE status  END AS status,
       COUNT(*) AS orders
FROM c
GROUP BY CUBE (country, status)
ORDER BY GROUPING(country), GROUPING(status), orders DESC;
-- Country totals (status = '(all)'): India 19 is the largest.
-- Status totals (country = '(all)'): delivered 36 is the most common.


-- Q3.
WITH lines AS (
    SELECT EXTRACT(YEAR FROM o.order_date)::int                     AS year,
           cat.category_name,
           oi.quantity * oi.unit_price * (1 - oi.discount)          AS revenue
    FROM order_items oi
    JOIN orders o       ON o.order_id = oi.order_id
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.status <> 'cancelled'
)
SELECT CASE GROUPING(year, category_name)
            WHEN 1 THEN 'year'          -- category aggregated away -> per-year row
            WHEN 2 THEN 'category'      -- year aggregated away     -> per-category row
            ELSE        'total' END     AS breakdown,
       year, category_name,
       ROUND(SUM(revenue), 2) AS revenue
FROM lines
GROUP BY GROUPING SETS ((year), (category_name), ())
ORDER BY breakdown DESC, year, revenue DESC;


-- Q4.
WITH RECURSIVE tree AS (
    SELECT category_id, category_id AS root_id FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, t.root_id FROM categories c JOIN tree t ON c.parent_id = t.category_id
)
SELECT CASE WHEN GROUPING(r.category_name) = 1 THEN 'GRAND TOTAL' ELSE r.category_name END AS root,
       CASE WHEN GROUPING(leaf.category_name) = 1 AND GROUPING(r.category_name) = 0
            THEN 'subtotal' ELSE leaf.category_name END                               AS category,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2)                 AS revenue
FROM order_items oi
JOIN products p      ON p.product_id     = oi.product_id
JOIN categories leaf ON leaf.category_id = p.category_id
JOIN tree t          ON t.category_id    = leaf.category_id
JOIN categories r    ON r.category_id    = t.root_id
GROUP BY ROLLUP (r.category_name, leaf.category_name)
ORDER BY GROUPING(r.category_name), r.category_name, GROUPING(leaf.category_name), revenue DESC;


-- Q5a. LATERAL top-2.
SELECT c.customer_id, t.order_id, ROUND(t.total, 2) AS total
FROM customers c
CROSS JOIN LATERAL (
    SELECT o.order_id, SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS total
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id = c.customer_id
    GROUP BY o.order_id
    ORDER BY total DESC, o.order_id
    LIMIT 2
) t
ORDER BY c.customer_id, t.total DESC;                       -- 34 rows

-- Q5b. Window version — identical rows when the tie-breaker matches.
WITH totals AS (
    SELECT o.customer_id, o.order_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS total
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id, o.order_id
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total DESC, order_id) AS rn
    FROM totals
)
SELECT customer_id, order_id, ROUND(total, 2) AS total
FROM ranked WHERE rn <= 2
ORDER BY customer_id, total DESC;                           -- 34 rows


-- Q6a. Implicit lateral: functions in FROM can reference earlier tables.
SELECT tag, COUNT(*) AS products
FROM products p
CROSS JOIN LATERAL jsonb_array_elements_text(p.attributes -> 'tags') AS tag
GROUP BY tag
ORDER BY products DESC, tag;                                -- 7 tags

-- Q6b. LEFT JOIN LATERAL keeps products whose tags array is missing.
SELECT p.product_name
FROM products p
LEFT JOIN LATERAL jsonb_array_elements_text(p.attributes -> 'tags') AS t(tag) ON TRUE
WHERE t.tag IS NULL
ORDER BY p.product_name;                                    -- 16 products


-- Q7. LAG must be computed over ALL employees of the department before LIMIT,
--     so it's calculated in an inner query, then the newest 2 are taken.
SELECT d.dept_name, x.first_name, x.hire_date, x.days_after_previous_hire
FROM departments d
LEFT JOIN LATERAL (
    SELECT *
    FROM (SELECT e.first_name, e.hire_date,
                 e.hire_date - LAG(e.hire_date) OVER (ORDER BY e.hire_date) AS days_after_previous_hire
          FROM employees e
          WHERE e.dept_id = d.dept_id) h
    ORDER BY h.hire_date DESC
    LIMIT 2
) x ON TRUE
ORDER BY d.dept_id, x.hire_date DESC;                       -- 10 rows
