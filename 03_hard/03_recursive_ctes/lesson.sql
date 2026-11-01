-- =============================================================================
-- 03_hard/03 · Recursive CTEs — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. The simplest recursion: counting
-- -----------------------------------------------------------------------------

-- Anchor produces 1; each iteration adds 1 to the previous row; stops at 10.
WITH RECURSIVE numbers AS (
    SELECT 1 AS n                         -- anchor
    UNION ALL
    SELECT n + 1 FROM numbers WHERE n < 10 -- recursive member + stop condition
)
SELECT n FROM numbers;


-- -----------------------------------------------------------------------------
-- 2. Walking DOWN a hierarchy: the whole org chart with levels and paths
-- -----------------------------------------------------------------------------

WITH RECURSIVE org AS (
    -- Anchor: the root (no manager).
    SELECT emp_id,
           first_name,
           job_title,
           1                     AS level,
           first_name::text      AS path,          -- ::text so anchor & recursive types match
           ARRAY[emp_id]         AS id_path        -- array path: useful for sorting & cycle checks
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    -- Recursive member: employees whose manager is in the previous level.
    SELECT e.emp_id,
           e.first_name,
           e.job_title,
           o.level + 1,
           o.path || ' > ' || e.first_name,
           o.id_path || e.emp_id
    FROM employees e
    JOIN org o ON e.manager_id = o.emp_id
)
SELECT REPEAT('    ', level - 1) || first_name AS org_chart,   -- indentation by level
       job_title, level, path
FROM org
ORDER BY id_path;                                 -- array order = depth-first tree order

-- Headcount per level.
WITH RECURSIVE org AS (
    SELECT emp_id, 1 AS level FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, o.level + 1 FROM employees e JOIN org o ON e.manager_id = o.emp_id
)
SELECT level, COUNT(*) AS people FROM org GROUP BY level ORDER BY level;   -- 1,4,5,9,1


-- -----------------------------------------------------------------------------
-- 3. Subtree of one node: everyone under Sara (emp 5), at any depth
-- -----------------------------------------------------------------------------

WITH RECURSIVE team AS (
    SELECT emp_id, first_name, salary, 0 AS depth
    FROM employees WHERE emp_id = 5               -- anchor: start at Sara, not at the root
    UNION ALL
    SELECT e.emp_id, e.first_name, e.salary, t.depth + 1
    FROM employees e JOIN team t ON e.manager_id = t.emp_id
)
SELECT first_name, depth FROM team ORDER BY depth, first_name;

-- Total cost of Sara's organisation (her own salary included).
WITH RECURSIVE team AS (
    SELECT emp_id, salary FROM employees WHERE emp_id = 5
    UNION ALL
    SELECT e.emp_id, e.salary FROM employees e JOIN team t ON e.manager_id = t.emp_id
)
SELECT COUNT(*) - 1 AS people_under_sara, SUM(salary) AS org_payroll FROM team;   -- 5 | 580000


-- -----------------------------------------------------------------------------
-- 4. Walking UP: the management chain of one employee
-- -----------------------------------------------------------------------------

-- Join direction flips: find the MANAGER of the row found in the previous step.
WITH RECURSIVE chain AS (
    SELECT emp_id, first_name, manager_id, 0 AS steps_up
    FROM employees WHERE emp_id = 9               -- Neha (Junior Engineer)
    UNION ALL
    SELECT m.emp_id, m.first_name, m.manager_id, c.steps_up + 1
    FROM employees m
    JOIN chain c ON m.emp_id = c.manager_id
)
SELECT steps_up, first_name FROM chain ORDER BY steps_up;   -- Neha, Arjun, Sara, Rahul, Anita

-- As one string, top-down:
WITH RECURSIVE chain AS (
    SELECT emp_id, first_name, manager_id, 0 AS steps_up FROM employees WHERE emp_id = 9
    UNION ALL
    SELECT m.emp_id, m.first_name, m.manager_id, c.steps_up + 1
    FROM employees m JOIN chain c ON m.emp_id = c.manager_id
)
SELECT STRING_AGG(first_name, ' > ' ORDER BY steps_up DESC) AS reporting_line FROM chain;


-- -----------------------------------------------------------------------------
-- 5. Category tree: full path, depth, and roll-up to the root
-- -----------------------------------------------------------------------------

WITH RECURSIVE tree AS (
    SELECT category_id, category_name, parent_id,
           category_name::text AS full_path,
           category_id         AS root_id,       -- carry the top-level ancestor down
           1                   AS depth
    FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, c.category_name, c.parent_id,
           t.full_path || ' / ' || c.category_name,
           t.root_id,
           t.depth + 1
    FROM categories c JOIN tree t ON c.parent_id = t.category_id
)
SELECT category_id, full_path, depth FROM tree ORDER BY full_path;

-- Revenue rolled up to each ROOT category (products sit on leaf categories).
WITH RECURSIVE tree AS (
    SELECT category_id, category_id AS root_id FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, t.root_id FROM categories c JOIN tree t ON c.parent_id = t.category_id
)
SELECT r.category_name AS root_category,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2) AS revenue
FROM tree t
JOIN categories r   ON r.category_id = t.root_id
JOIN products p     ON p.category_id = t.category_id
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY r.category_name
ORDER BY revenue DESC;                         -- Electronics 28563.55, Home & Kitchen, Books


-- -----------------------------------------------------------------------------
-- 6. Referral network
-- -----------------------------------------------------------------------------

-- Everyone who joined thanks to Aarav, directly or indirectly.
WITH RECURSIVE referrals AS (
    SELECT customer_id, first_name, 0 AS generation
    FROM customers WHERE customer_id = 1
    UNION ALL
    SELECT c.customer_id, c.first_name, r.generation + 1
    FROM customers c JOIN referrals r ON c.referred_by = r.customer_id
)
SELECT generation, first_name FROM referrals WHERE generation > 0
ORDER BY generation, first_name;               -- 6 people across 3 generations


-- -----------------------------------------------------------------------------
-- 7. Cycles: protecting against infinite recursion
-- -----------------------------------------------------------------------------

-- A small graph of flights WITH a cycle (BLR -> DEL -> BOM -> BLR).
CREATE TEMP TABLE flights (src TEXT, dst TEXT, minutes INT);
INSERT INTO flights VALUES
    ('BLR','DEL',165), ('DEL','BOM',130), ('BOM','BLR',100),
    ('DEL','CCU',140), ('BOM','GOI',70),  ('CCU','GOI',190);

-- Track the visited airports in an array; never revisit one.
WITH RECURSIVE routes AS (
    SELECT src, dst, ARRAY[src, dst] AS path, minutes AS total_minutes, 1 AS hops
    FROM flights WHERE src = 'BLR'
    UNION ALL
    SELECT r.src, f.dst, r.path || f.dst, r.total_minutes + f.minutes, r.hops + 1
    FROM routes r
    JOIN flights f ON f.src = r.dst
    WHERE NOT f.dst = ANY(r.path)               -- cycle guard: skip already-visited airports
)
SELECT array_to_string(path, ' → ') AS route, hops, total_minutes
FROM routes
ORDER BY dst, total_minutes;

-- Fastest route from BLR to GOI.
WITH RECURSIVE routes AS (
    SELECT dst, ARRAY['BLR', dst] AS path, minutes AS total_minutes
    FROM flights WHERE src = 'BLR'
    UNION ALL
    SELECT f.dst, r.path || f.dst, r.total_minutes + f.minutes
    FROM routes r JOIN flights f ON f.src = r.dst
    WHERE NOT f.dst = ANY(r.path)
)
SELECT array_to_string(path, ' → ') AS route, total_minutes
FROM routes WHERE dst = 'GOI'
ORDER BY total_minutes
LIMIT 1;                                         -- BLR → DEL → BOM → GOI (365 min)

-- Postgres 14+ has a built-in CYCLE clause that does the bookkeeping for you.
WITH RECURSIVE reach AS (
    SELECT src, dst FROM flights WHERE src = 'BLR'
    UNION ALL
    SELECT f.src, f.dst FROM reach r JOIN flights f ON f.src = r.dst
) CYCLE dst SET is_cycle USING visited
SELECT DISTINCT dst FROM reach WHERE NOT is_cycle ORDER BY dst;


-- -----------------------------------------------------------------------------
-- 8. Recursion for row-by-row calculations
-- -----------------------------------------------------------------------------

-- Compound growth: each month's balance depends on the previous month's
-- COMPUTED balance (1% interest + 100 deposit) — not expressible with windows.
WITH RECURSIVE savings AS (
    SELECT 1 AS month, 1000.00::numeric(12,2) AS balance
    UNION ALL
    -- The recursive term must produce EXACTLY the anchor's types: ROUND() returns
    -- plain numeric, so cast back to numeric(12,2) (otherwise: "column 2 has
    -- type numeric(12,2) in non-recursive term but type numeric overall").
    SELECT month + 1, ROUND(balance * 1.01 + 100, 2)::numeric(12,2)
    FROM savings WHERE month < 12
)
SELECT * FROM savings;
