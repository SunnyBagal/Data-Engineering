-- =============================================================================
-- 03_hard/04 · Advanced Grouping & LATERAL — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. The problem: detail + subtotals + total
-- -----------------------------------------------------------------------------

-- The "old" way: three GROUP BYs glued with UNION ALL -> three scans, verbose.
SELECT EXTRACT(YEAR FROM paid_at)::int AS year, method, SUM(amount) AS total
FROM payments GROUP BY 1, 2
UNION ALL
SELECT EXTRACT(YEAR FROM paid_at)::int, NULL, SUM(amount) FROM payments GROUP BY 1
UNION ALL
SELECT NULL, NULL, SUM(amount) FROM payments
ORDER BY 1 NULLS LAST, 2 NULLS LAST;


-- -----------------------------------------------------------------------------
-- 2. ROLLUP: hierarchical subtotals in one pass
-- -----------------------------------------------------------------------------

-- ROLLUP (year, method) = GROUPING SETS ((year, method), (year), ()).
SELECT EXTRACT(YEAR FROM paid_at)::int AS year,
       method,
       SUM(amount)                     AS total
FROM payments
GROUP BY ROLLUP (EXTRACT(YEAR FROM paid_at)::int, method)
ORDER BY 1 NULLS LAST, 2 NULLS LAST;          -- 17 rows: 13 detail + 3 year totals + 1 grand total


-- -----------------------------------------------------------------------------
-- 3. GROUPING(): label the subtotal rows correctly
-- -----------------------------------------------------------------------------

SELECT CASE WHEN GROUPING(EXTRACT(YEAR FROM paid_at)::int) = 1 THEN 'All years'
            ELSE EXTRACT(YEAR FROM paid_at)::int::text END             AS year,
       CASE WHEN GROUPING(method) = 1 THEN 'All methods' ELSE method END AS method,
       SUM(amount)                                                      AS total,
       GROUPING(EXTRACT(YEAR FROM paid_at)::int, method)                AS level   -- 0 detail, 1 year total, 3 grand total
FROM payments
GROUP BY ROLLUP (EXTRACT(YEAR FROM paid_at)::int, method)
ORDER BY GROUPING(EXTRACT(YEAR FROM paid_at)::int),           -- grand total last
         EXTRACT(YEAR FROM paid_at)::int,
         GROUPING(method),                                     -- year total after its details
         method;

-- Why GROUPING() matters: employee_id is NULL for ONLINE orders. In a ROLLUP
-- the total row ALSO has NULL — only GROUPING() can tell them apart.
SELECT employee_id,
       GROUPING(employee_id) AS is_total_row,
       CASE WHEN GROUPING(employee_id) = 1 THEN 'TOTAL'
            WHEN employee_id IS NULL       THEN 'online'
            ELSE 'rep ' || employee_id END AS label,
       COUNT(*) AS orders
FROM orders
GROUP BY ROLLUP (employee_id)
ORDER BY GROUPING(employee_id), employee_id NULLS FIRST;


-- -----------------------------------------------------------------------------
-- 4. CUBE: every combination of subtotals
-- -----------------------------------------------------------------------------

-- Totals per (year, method), per year, per METHOD (across years), and overall.
SELECT EXTRACT(YEAR FROM paid_at)::int AS year,
       method,
       SUM(amount)                     AS total,
       GROUPING(EXTRACT(YEAR FROM paid_at)::int, method) AS level
FROM payments
GROUP BY CUBE (EXTRACT(YEAR FROM paid_at)::int, method)
ORDER BY level, year, method;                 -- 22 rows (13 + 3 + 5 + 1)


-- -----------------------------------------------------------------------------
-- 5. GROUPING SETS: pick exactly the groupings you want
-- -----------------------------------------------------------------------------

-- Orders by country, by sales channel, and the grand total — three unrelated
-- breakdowns in one result (no (country, channel) detail rows).
SELECT c.country,
       CASE WHEN o.employee_id IS NULL THEN 'online' ELSE 'sales rep' END AS channel,
       COUNT(*) AS orders,
       GROUPING(c.country, CASE WHEN o.employee_id IS NULL THEN 'online' ELSE 'sales rep' END) AS level
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY GROUPING SETS (
    (c.country),
    (CASE WHEN o.employee_id IS NULL THEN 'online' ELSE 'sales rep' END),
    ()
)
ORDER BY level, country, channel;

-- Hierarchy rollup: root category > leaf category, with the recursive tree
-- from topic 03 providing the root of each leaf.
WITH RECURSIVE tree AS (
    SELECT category_id, category_id AS root_id FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, t.root_id FROM categories c JOIN tree t ON c.parent_id = t.category_id
)
SELECT COALESCE(r.category_name, '== TOTAL ==')                          AS root_category,
       CASE WHEN GROUPING(leaf.category_name) = 1 AND GROUPING(r.category_name) = 0
            THEN '-- subtotal --' ELSE leaf.category_name END             AS category,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2)     AS revenue
FROM order_items oi
JOIN products p      ON p.product_id = oi.product_id
JOIN categories leaf ON leaf.category_id = p.category_id
JOIN tree t          ON t.category_id = leaf.category_id
JOIN categories r    ON r.category_id = t.root_id
GROUP BY ROLLUP (r.category_name, leaf.category_name)
ORDER BY GROUPING(r.category_name), r.category_name, GROUPING(leaf.category_name), revenue DESC;


-- -----------------------------------------------------------------------------
-- 6. LATERAL: a subquery that can see the row to its left
-- -----------------------------------------------------------------------------

-- Each customer's 2 largest orders. The subquery runs once per customer and
-- can use ORDER BY ... LIMIT (top-N per group without window functions).
SELECT c.customer_id, c.first_name, t.order_id, ROUND(t.total, 2) AS total
FROM customers c
CROSS JOIN LATERAL (
    SELECT o.order_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id = c.customer_id            -- reference to the outer row "c"
    GROUP BY o.order_id
    ORDER BY total DESC
    LIMIT 2
) AS t
ORDER BY c.customer_id, t.total DESC;              -- customers without orders are dropped

-- LEFT JOIN LATERAL ... ON TRUE keeps outer rows with no match (Research dept).
SELECT d.dept_name, newest.first_name, newest.hire_date
FROM departments d
LEFT JOIN LATERAL (
    SELECT e.first_name, e.hire_date
    FROM employees e
    WHERE e.dept_id = d.dept_id
    ORDER BY e.hire_date DESC
    LIMIT 2
) AS newest ON TRUE
ORDER BY d.dept_id, newest.hire_date DESC;


-- -----------------------------------------------------------------------------
-- 7. LATERAL to return SEVERAL columns from a correlated computation
-- -----------------------------------------------------------------------------

-- A scalar subquery can return only one value; LATERAL returns a whole row.
SELECT c.first_name, s.orders, s.first_order, s.last_order
FROM customers c
CROSS JOIN LATERAL (
    SELECT COUNT(*)          AS orders,
           MIN(o.order_date) AS first_order,
           MAX(o.order_date) AS last_order
    FROM orders o
    WHERE o.customer_id = c.customer_id
) AS s                                             -- aggregates always return 1 row,
ORDER BY s.orders DESC;                            -- so nobody is dropped here


-- -----------------------------------------------------------------------------
-- 8. LATERAL with set-returning functions and computed columns
-- -----------------------------------------------------------------------------

-- Explode each product's JSON "tags" array into rows (one row per tag).
SELECT p.product_name, tag
FROM products p
CROSS JOIN LATERAL jsonb_array_elements_text(p.attributes -> 'tags') AS tag
ORDER BY tag, p.product_name;

-- Name an expression once and reuse it in SELECT, WHERE and ORDER BY.
SELECT p.product_name, m.margin, m.margin_pct
FROM products p
CROSS JOIN LATERAL (SELECT p.price - p.cost                           AS margin,
                           ROUND(100 * (p.price - p.cost) / p.price, 1) AS margin_pct) AS m
WHERE m.margin_pct > 60
ORDER BY m.margin_pct DESC;
