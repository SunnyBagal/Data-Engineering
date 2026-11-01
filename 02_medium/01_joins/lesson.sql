-- =============================================================================
-- 02_medium/01 · Joins — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. INNER JOIN: only rows that match on both sides
-- -----------------------------------------------------------------------------

-- Each order with its customer's name. o / c are table aliases; prefixing
-- every column with its alias makes the query unambiguous and readable.
SELECT o.order_id,
       o.order_date,
       c.first_name || ' ' || c.last_name AS customer
FROM orders o
JOIN customers c                         -- "JOIN" = "INNER JOIN"
  ON c.customer_id = o.customer_id       -- FK = PK: the relationship
ORDER BY o.order_id;                     -- 46 rows: every order has a customer

-- USING: shorthand when the column name is identical on both sides.
-- The join column appears ONCE in the output (no alias prefix needed for it).
SELECT order_id, customer_id, c.country
FROM orders
JOIN customers c USING (customer_id)
LIMIT 5;


-- -----------------------------------------------------------------------------
-- 2. Joining many tables: walk the relationships one step at a time
-- -----------------------------------------------------------------------------

-- order_items -> products -> categories  (+ orders for the date)
SELECT o.order_id,
       o.order_date::date                                        AS order_day,
       p.product_name,
       cat.category_name,
       oi.quantity,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount), 2) AS revenue
FROM order_items oi
JOIN orders     o   ON o.order_id      = oi.order_id
JOIN products   p   ON p.product_id    = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
ORDER BY o.order_id, p.product_name;

-- Join + GROUP BY: revenue per category NAME (the reason we joined).
SELECT cat.category_name,
       SUM(oi.quantity)                                               AS units,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2) AS revenue
FROM order_items oi
JOIN products   p   ON p.product_id    = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
GROUP BY cat.category_name
ORDER BY revenue DESC;                   -- Laptops 17710.00 first


-- -----------------------------------------------------------------------------
-- 3. LEFT JOIN: keep every row of the left table
-- -----------------------------------------------------------------------------

-- Every customer, with their orders if any. Nisha (19) and Lucas (20) have no
-- orders: they still appear, with NULL in the order columns.
SELECT c.customer_id, c.first_name, o.order_id, o.status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.customer_id, o.order_id;

-- ANTI-JOIN: keep only left rows that found NO match.
-- After a LEFT JOIN, the right side's PK is NULL exactly for unmatched rows.
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;                -- customers who never ordered: 19, 20

-- Products never sold (4 products).
SELECT p.product_id, p.product_name
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.product_id IS NULL;

-- Counting with LEFT JOIN: COUNT(*) counts the NULL-padded row as 1 for
-- Research. COUNT(e.emp_id) counts only real matches -> 0.
SELECT d.dept_name,
       COUNT(*)        AS wrong_count,   -- Research = 1 (!)
       COUNT(e.emp_id) AS headcount      -- Research = 0
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY d.dept_id;


-- -----------------------------------------------------------------------------
-- 4. ON vs WHERE with LEFT JOIN — the most common join bug
-- -----------------------------------------------------------------------------

-- Goal: ALL customers, plus their cancelled orders (if any).
-- Condition on the right table inside ON -> all 20 customers kept.
SELECT c.customer_id, c.first_name, o.order_id AS cancelled_order
FROM customers c
LEFT JOIN orders o
  ON o.customer_id = c.customer_id
 AND o.status = 'cancelled'              -- part of the MATCH rule
ORDER BY c.customer_id;                  -- 20 rows

-- Same condition in WHERE -> rows with NULL status are filtered out after the
-- join, so the LEFT JOIN silently behaves like an INNER JOIN.
SELECT c.customer_id, c.first_name, o.order_id AS cancelled_order
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status = 'cancelled'             -- filters the RESULT
ORDER BY c.customer_id;                  -- only 3 rows


-- -----------------------------------------------------------------------------
-- 5. Optional relationships: LEFT JOIN + COALESCE
-- -----------------------------------------------------------------------------

-- Orders with the sales rep's name; online orders have no rep.
-- An INNER JOIN to employees would DROP the 15 online orders.
SELECT o.order_id,
       COALESCE(e.first_name || ' ' || e.last_name, 'Online') AS handled_by
FROM orders o
LEFT JOIN employees e ON e.emp_id = o.employee_id
ORDER BY o.order_id;


-- -----------------------------------------------------------------------------
-- 6. RIGHT JOIN and FULL OUTER JOIN
-- -----------------------------------------------------------------------------

-- RIGHT JOIN = LEFT JOIN with sides swapped. These two are identical:
SELECT d.dept_name, e.first_name FROM employees e RIGHT JOIN departments d ON d.dept_id = e.dept_id;
SELECT d.dept_name, e.first_name FROM departments d LEFT JOIN employees e ON d.dept_id = e.dept_id;

-- FULL OUTER JOIN: unmatched rows from BOTH sides.
-- Shows Research (no employees) AND the CEO/contractor (no department).
SELECT d.dept_name, e.first_name, e.job_title
FROM departments d
FULL OUTER JOIN employees e ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL OR e.emp_id IS NULL;   -- only the unmatched ones (3 rows)


-- -----------------------------------------------------------------------------
-- 7. FAN-OUT: why joining two child tables inflates totals
-- -----------------------------------------------------------------------------

-- Order 6 has 1 item and 2 payments (675 + 675). Joining both children gives
-- 1 x 2 = 2 rows, so the item revenue is counted twice.
SELECT o.order_id,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue_wrong,  -- 2700 instead of 1350
       SUM(p.amount)                                        AS paid
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN payments    p  ON p.order_id  = o.order_id
WHERE o.order_id = 6
GROUP BY o.order_id;

-- Fix: aggregate each child table to ONE row per order first (derived tables,
-- 02_medium/03), then join the per-order results 1:1.
SELECT o.order_id, r.revenue, COALESCE(pay.paid, 0) AS paid
FROM orders o
JOIN (SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS revenue
      FROM order_items GROUP BY order_id) r   ON r.order_id = o.order_id
LEFT JOIN (SELECT order_id, SUM(amount) AS paid
      FROM payments GROUP BY order_id) pay    ON pay.order_id = o.order_id
WHERE o.order_id IN (6, 28, 41, 44)
ORDER BY o.order_id;


-- -----------------------------------------------------------------------------
-- 8. Joining to a generated calendar: fill gaps with zeros
-- -----------------------------------------------------------------------------

-- Daily logins for 1–10 Sep 2025, INCLUDING days with zero logins.
-- Grouping logins alone would simply omit empty days.
SELECT d::date            AS day,
       COUNT(l.login_id)  AS logins          -- COUNT(column) -> 0 for unmatched days
FROM generate_series(DATE '2025-09-01', DATE '2025-09-10', INTERVAL '1 day') AS d
LEFT JOIN logins l
       ON l.login_at >= d
      AND l.login_at <  d + INTERVAL '1 day' -- half-open range join
GROUP BY d
ORDER BY d;


-- -----------------------------------------------------------------------------
-- 9. Non-equi joins: matching on ranges, not equality
-- -----------------------------------------------------------------------------

-- Assign each product to a price band defined in an inline VALUES table.
SELECT p.product_name, p.price, b.band
FROM products p
JOIN (VALUES ('budget',     0,    100),
             ('mid-range',  100,  500),
             ('premium',    500,  100000)) AS b(band, low, high)
  ON p.price >= b.low AND p.price < b.high
ORDER BY p.price;
