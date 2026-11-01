-- =============================================================================
-- 02_medium/02 · Self Joins & Cross Joins — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Self join on a hierarchy: employee -> manager
-- -----------------------------------------------------------------------------

-- Two aliases of the same table: e = the employee, m = the manager.
-- LEFT JOIN keeps Anita (CEO), whose manager_id is NULL.
SELECT e.emp_id,
       e.first_name || ' ' || e.last_name               AS employee,
       e.job_title,
       COALESCE(m.first_name || ' ' || m.last_name, '—') AS manager
FROM employees e
LEFT JOIN employees m ON m.emp_id = e.manager_id
ORDER BY e.emp_id;                                   -- 20 rows

-- With an INNER JOIN the CEO vanishes (19 rows) — usually a bug.
SELECT COUNT(*) AS inner_rows
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id;

-- Direct reports per manager: group on the manager side of the join.
SELECT m.first_name || ' ' || m.last_name AS manager,
       COUNT(*)                           AS direct_reports,
       STRING_AGG(e.first_name, ', ' ORDER BY e.first_name) AS team
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id
GROUP BY m.emp_id, m.first_name, m.last_name
ORDER BY direct_reports DESC, manager;


-- -----------------------------------------------------------------------------
-- 2. Comparing a row with its parent row
-- -----------------------------------------------------------------------------

-- Salary gap between each employee and their manager.
SELECT e.first_name AS employee, e.salary,
       m.first_name AS manager,  m.salary AS manager_salary,
       m.salary - e.salary      AS gap
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id
ORDER BY gap;                                         -- Arjun is closest to his manager (20k)

-- Employees in a different department from their manager.
-- "<>" misses rows where either dept_id is NULL (CEO's direct reports, contractor);
-- IS DISTINCT FROM treats NULL as a comparable value.
SELECT e.first_name, e.dept_id, m.first_name AS manager, m.dept_id AS manager_dept
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id
WHERE e.dept_id IS DISTINCT FROM m.dept_id;           -- 6 rows (only 1 with <>)


-- -----------------------------------------------------------------------------
-- 3. Two levels up: chain self joins
-- -----------------------------------------------------------------------------

-- Category path "Grandparent > Parent > Child". Each extra level = one more join
-- (for unknown depth, see recursive CTEs in 03_hard/03).
SELECT c.category_name                                     AS category,
       CONCAT_WS(' > ', gp.category_name, p.category_name, c.category_name) AS path
FROM categories c
LEFT JOIN categories p  ON p.category_id  = c.parent_id
LEFT JOIN categories gp ON gp.category_id = p.parent_id
ORDER BY path;                                             -- CONCAT_WS skips NULL levels

-- Customer referral chains: who referred whom, and who referred the referrer.
SELECT c.first_name  AS customer,
       r.first_name  AS referred_by,
       g.first_name  AS referrer_of_referrer
FROM customers c
JOIN customers r      ON r.customer_id = c.referred_by
LEFT JOIN customers g ON g.customer_id = r.referred_by
ORDER BY c.customer_id;


-- -----------------------------------------------------------------------------
-- 4. Pairs within one table
-- -----------------------------------------------------------------------------

-- Customers who live in the same city. "a.customer_id < b.customer_id":
--   * excludes pairing a customer with themself
--   * lists each pair once, not as (1,13) AND (13,1)
SELECT a.city,
       a.first_name AS customer_a,
       b.first_name AS customer_b
FROM customers a
JOIN customers b
  ON a.city = b.city                                  -- NULL cities never match: good here
 AND a.customer_id < b.customer_id
ORDER BY a.city;                                      -- 4 pairs

-- Compare: "<>" returns every pair twice (8 rows).
SELECT COUNT(*) AS pairs_twice
FROM customers a JOIN customers b ON a.city = b.city AND a.customer_id <> b.customer_id;

-- Similar products: same category, price within 20.
SELECT a.product_name, a.price, b.product_name AS similar_to, b.price
FROM products a
JOIN products b
  ON a.category_id = b.category_id
 AND a.product_id  < b.product_id
 AND ABS(a.price - b.price) <= 20;


-- -----------------------------------------------------------------------------
-- 5. CROSS JOIN: every combination
-- -----------------------------------------------------------------------------

-- 3 sizes x 2 colors = 6 variants. VALUES lists act as tiny inline tables.
SELECT s.size, c.color, 'TSHIRT-' || s.size || '-' || UPPER(c.color) AS sku
FROM (VALUES ('S'), ('M'), ('L')) AS s(size)
CROSS JOIN (VALUES ('red'), ('blue')) AS c(color);

-- Row-count arithmetic: 6 departments x 20 customers = 120 rows.
SELECT COUNT(*) FROM departments CROSS JOIN customers;

-- The old comma syntax without WHERE is ALSO a cross join (often by accident):
SELECT COUNT(*) FROM departments, customers;          -- 120 as well


-- -----------------------------------------------------------------------------
-- 6. CROSS JOIN for complete report grids (zeros instead of missing rows)
-- -----------------------------------------------------------------------------

-- Plain GROUP BY only shows combinations that EXIST: bank_transfer in 2024 and
-- cash in 2025 are simply missing.
SELECT EXTRACT(YEAR FROM paid_at) AS year, method, SUM(amount) AS total
FROM payments
GROUP BY 1, 2
ORDER BY 1, 2;                                        -- 13 rows

-- Build the full grid (3 years x 5 methods), then LEFT JOIN the facts onto it.
SELECT y.year, m.method, COALESCE(SUM(p.amount), 0) AS total
FROM generate_series(2023, 2025) AS y(year)
CROSS JOIN (SELECT DISTINCT method FROM payments) AS m
LEFT JOIN payments p
       ON p.method = m.method
      AND p.paid_at >= MAKE_DATE(y.year, 1, 1)        -- sargable year range
      AND p.paid_at <  MAKE_DATE(y.year + 1, 1, 1)
GROUP BY y.year, m.method
ORDER BY y.year, m.method;                            -- 15 rows, zeros included


-- -----------------------------------------------------------------------------
-- 7. CROSS JOIN with a one-row result: compare every row with a global value
-- -----------------------------------------------------------------------------

-- The subquery returns exactly one row, so the cross join just "attaches"
-- the average to every product — no row multiplication.
SELECT p.product_name,
       p.price,
       ROUND(a.avg_price, 2)               AS avg_price,
       ROUND(p.price - a.avg_price, 2)     AS diff_from_avg
FROM products p
CROSS JOIN (SELECT AVG(price) AS avg_price FROM products) AS a
ORDER BY diff_from_avg DESC;
