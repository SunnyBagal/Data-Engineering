-- =============================================================================
-- 03_hard/03 · Recursive CTEs — SOLUTIONS
-- =============================================================================


-- Q1. The array of ids sorts depth-first (parent before its children).
WITH RECURSIVE org AS (
    SELECT emp_id, first_name, 1 AS level,
           first_name::text AS path, ARRAY[emp_id] AS sort_key
    FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.first_name, o.level + 1,
           o.path || ' > ' || e.first_name, o.sort_key || e.emp_id
    FROM employees e JOIN org o ON e.manager_id = o.emp_id
)
SELECT level, REPEAT('  ', level - 1) || first_name AS name, path
FROM org
ORDER BY sort_key;


-- Q2. Start the recursion from EVERY employee at once and carry the starting
--     employee (root) down; each root then collects its entire subtree.
WITH RECURSIVE subtree AS (
    SELECT emp_id AS root_id, emp_id, salary
    FROM employees
    UNION ALL
    SELECT s.root_id, e.emp_id, e.salary
    FROM employees e JOIN subtree s ON e.manager_id = s.emp_id
)
SELECT m.first_name || ' ' || m.last_name AS manager,
       COUNT(*) - 1                       AS people_below,       -- minus the manager themself
       SUM(s.salary) - m.salary           AS payroll_below
FROM subtree s
JOIN employees m ON m.emp_id = s.root_id
GROUP BY m.emp_id, m.first_name, m.last_name, m.salary
HAVING COUNT(*) > 1                                              -- managers only
ORDER BY people_below DESC, manager;


-- Q3. Walk up, then aggregate top-down (ORDER BY steps DESC inside STRING_AGG).
WITH RECURSIVE chain AS (
    SELECT emp_id, first_name, manager_id, 0 AS steps
    FROM employees WHERE emp_id = 20
    UNION ALL
    SELECT m.emp_id, m.first_name, m.manager_id, c.steps + 1
    FROM employees m JOIN chain c ON m.emp_id = c.manager_id
)
SELECT STRING_AGG(first_name, ' > ' ORDER BY steps DESC) AS reporting_line,
       MAX(steps)                                        AS levels_above
FROM chain;


-- Q4. Each category is a root of its own subtree; LEFT JOIN keeps empty ones.
WITH RECURSIVE paths AS (
    SELECT category_id, category_name::text AS full_path
    FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, p.full_path || ' / ' || c.category_name
    FROM categories c JOIN paths p ON c.parent_id = p.category_id
),
subtree AS (
    SELECT category_id AS root_id, category_id FROM categories
    UNION ALL
    SELECT s.root_id, c.category_id
    FROM categories c JOIN subtree s ON c.parent_id = s.category_id
)
SELECT pa.full_path,
       COUNT(p.product_id) AS products_incl_subcategories
FROM subtree s
JOIN paths pa        ON pa.category_id = s.root_id
LEFT JOIN products p ON p.category_id  = s.category_id
GROUP BY pa.full_path
ORDER BY pa.full_path;


-- Q5.
WITH RECURSIVE tree AS (
    SELECT customer_id, 0 AS generation FROM customers WHERE customer_id = 1
    UNION ALL
    SELECT c.customer_id, t.generation + 1
    FROM customers c JOIN tree t ON c.referred_by = t.customer_id
),
revenue AS (
    SELECT o.customer_id, SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS rev
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.customer_id
)
SELECT t.generation,
       STRING_AGG(c.first_name, ', ' ORDER BY c.first_name) AS customers,
       ROUND(COALESCE(SUM(r.rev), 0), 2)                    AS revenue
FROM tree t
JOIN customers c     ON c.customer_id = t.customer_id
LEFT JOIN revenue r  ON r.customer_id = t.customer_id
WHERE t.generation > 0
GROUP BY t.generation
ORDER BY t.generation;


-- Q6. A recursive date generator, then a LEFT JOIN calendar pattern.
WITH RECURSIVE days AS (
    SELECT DATE '2025-09-01' AS day
    UNION ALL
    SELECT day + 1 FROM days WHERE day < DATE '2025-09-30'
)
SELECT d.day, COUNT(l.login_id) AS logins
FROM days d
LEFT JOIN logins l ON l.login_at >= d.day AND l.login_at < d.day + 1
GROUP BY d.day
ORDER BY d.day;


-- Q7. Multiply quantities down the tree; leaves are parts that are never a parent.
CREATE TEMP TABLE parts (parent TEXT, child TEXT, qty INT);
INSERT INTO parts VALUES
    ('bike','frame',1), ('bike','wheel',2), ('wheel','spoke',32), ('wheel','rim',1),
    ('wheel','tyre',1), ('bike','handlebar',1), ('handlebar','grip',2);

WITH RECURSIVE bom AS (
    SELECT child AS part, qty * 10 AS needed          -- 10 bikes
    FROM parts WHERE parent = 'bike'
    UNION ALL
    SELECT p.child, b.needed * p.qty
    FROM parts p JOIN bom b ON p.parent = b.part
)
SELECT part, SUM(needed) AS total_needed
FROM bom
WHERE part NOT IN (SELECT parent FROM parts)          -- leaf parts only (parent is never NULL here)
GROUP BY part
ORDER BY total_needed DESC;
