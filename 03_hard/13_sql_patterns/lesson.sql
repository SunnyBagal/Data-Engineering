-- =============================================================================
-- 03_hard/13 · Interview & Real-World SQL Patterns — LESSON
-- Each section is a self-contained recipe on the practice data.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Top-N per group: the 2 most expensive products in each category
-- -----------------------------------------------------------------------------

WITH ranked AS (
    SELECT c.category_name, p.product_name, p.price,
           ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.price DESC, p.product_id) AS rn
    FROM products p JOIN categories c ON c.category_id = p.category_id
)
SELECT category_name, product_name, price
FROM ranked
WHERE rn <= 2
ORDER BY category_name, price DESC;


-- -----------------------------------------------------------------------------
-- 2. Deduplication: keep the newest row per business key
-- -----------------------------------------------------------------------------

-- A messy import with duplicate customers (same email, different case/spaces).
CREATE TEMP TABLE customer_import (email TEXT, name TEXT, imported_at TIMESTAMP);
INSERT INTO customer_import VALUES
    ('asha@mail.com',   'Asha',     '2025-01-01'),
    (' ASHA@mail.com',  'Asha R.',  '2025-02-01'),   -- same person, newer
    ('ben@mail.com',    'Ben',      '2025-01-05'),
    ('ben@mail.com',    'Ben',      '2025-01-05'),   -- exact duplicate
    ('chen@mail.com',   'Chen',     '2025-03-01');

WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email))       -- normalised key
                              ORDER BY imported_at DESC) AS rn       -- newest wins
    FROM customer_import
)
SELECT LOWER(TRIM(email)) AS email, name, imported_at
FROM ranked WHERE rn = 1
ORDER BY email;                                   -- 3 unique customers


-- -----------------------------------------------------------------------------
-- 3. Nth highest value: 3rd highest DISTINCT salary
-- -----------------------------------------------------------------------------

SELECT DISTINCT salary
FROM (SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS dr FROM employees) x
WHERE dr = 3;                                     -- 175000.00

-- Alternative without windows:
SELECT DISTINCT salary FROM employees ORDER BY salary DESC OFFSET 2 LIMIT 1;


-- -----------------------------------------------------------------------------
-- 4. Gaps & islands: login streaks (consecutive days)
-- -----------------------------------------------------------------------------

WITH login_days AS (                              -- step 1: one row per customer per day
    SELECT DISTINCT customer_id, login_at::date AS day
    FROM logins
),
grouped AS (                                      -- step 2: day - row_number is constant per streak
    SELECT customer_id, day,
           day - (ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY day))::int AS island_key
    FROM login_days
)
SELECT customer_id,                               -- step 3: one row per island
       MIN(day)  AS streak_start,
       MAX(day)  AS streak_end,
       COUNT(*)  AS streak_days
FROM grouped
GROUP BY customer_id, island_key
ORDER BY streak_days DESC, customer_id
LIMIT 5;                                          -- customer 1: 7 days; customer 6: 6 days (crosses a month)

-- The "gaps" side: periods with NO login between first and last login of customer 1.
WITH d AS (SELECT DISTINCT login_at::date AS day FROM logins WHERE customer_id = 1)
SELECT day + 1 AS gap_start, next_day - 1 AS gap_end, next_day - day - 1 AS gap_days
FROM (SELECT day, LEAD(day) OVER (ORDER BY day) AS next_day FROM d) x
WHERE next_day - day > 1;


-- -----------------------------------------------------------------------------
-- 5. Sessionization: a new session after 30 minutes of inactivity
-- -----------------------------------------------------------------------------

WITH flagged AS (
    SELECT customer_id, login_at,
           CASE WHEN LAG(login_at) OVER w IS NULL
                  OR login_at - LAG(login_at) OVER w > INTERVAL '30 minutes'
                THEN 1 ELSE 0 END AS is_new_session
    FROM logins
    WINDOW w AS (PARTITION BY customer_id ORDER BY login_at)
),
numbered AS (
    SELECT *,
           SUM(is_new_session) OVER (PARTITION BY customer_id ORDER BY login_at
                                     ROWS UNBOUNDED PRECEDING) AS session_no   -- running sum = id
    FROM flagged
)
SELECT customer_id, session_no,
       MIN(login_at) AS session_start,
       MAX(login_at) AS session_end,
       COUNT(*)      AS events
FROM numbered
WHERE customer_id = 13
GROUP BY customer_id, session_no
ORDER BY session_no;                              -- 4 sessions for customer 13


-- -----------------------------------------------------------------------------
-- 6. Running balance: amount still owed per order after each payment
-- -----------------------------------------------------------------------------

WITH totals AS (
    SELECT order_id, ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS order_total
    FROM order_items GROUP BY order_id
)
SELECT p.order_id, p.paid_at, p.amount, t.order_total,
       t.order_total - SUM(p.amount) OVER (PARTITION BY p.order_id ORDER BY p.paid_at
                                           ROWS UNBOUNDED PRECEDING) AS balance_after_payment
FROM payments p JOIN totals t ON t.order_id = p.order_id
WHERE p.order_id IN (6, 28, 41)
ORDER BY p.order_id, p.paid_at;                    -- each order reaches 0 after its 2nd payment


-- -----------------------------------------------------------------------------
-- 7. Year-over-year growth
-- -----------------------------------------------------------------------------

WITH yearly AS (
    SELECT EXTRACT(YEAR FROM o.order_date)::int AS year,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS revenue
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY 1
)
SELECT year, ROUND(revenue, 2) AS revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY year))
             / LAG(revenue) OVER (ORDER BY year), 1) AS yoy_pct
FROM yearly ORDER BY year;                         -- 2024 +9.0 %, 2025 -36.4 % (partial year!)


-- -----------------------------------------------------------------------------
-- 8. Cohort retention: did customers come back the year after their first order?
-- -----------------------------------------------------------------------------

WITH first_order AS (
    SELECT customer_id, EXTRACT(YEAR FROM MIN(order_date))::int AS cohort_year
    FROM orders WHERE status <> 'cancelled'
    GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT customer_id, EXTRACT(YEAR FROM order_date)::int AS active_year
    FROM orders WHERE status <> 'cancelled'
)
SELECT f.cohort_year,
       COUNT(DISTINCT f.customer_id)                                              AS cohort_size,
       COUNT(DISTINCT a.customer_id) FILTER (WHERE a.active_year = f.cohort_year + 1) AS active_next_year,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE a.active_year = f.cohort_year + 1)
             / COUNT(DISTINCT f.customer_id), 1)                                  AS retention_pct
FROM first_order f
LEFT JOIN activity a ON a.customer_id = f.customer_id
GROUP BY f.cohort_year
ORDER BY f.cohort_year;                             -- 2023: 6/11 = 54.5 %


-- -----------------------------------------------------------------------------
-- 9. Funnel: signed up -> logged in -> ordered -> paid
-- -----------------------------------------------------------------------------

SELECT COUNT(*)                                                                      AS signed_up,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM logins l WHERE l.customer_id = c.customer_id)) AS logged_in,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)) AS ordered,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM orders o JOIN payments p ON p.order_id = o.order_id
                                      WHERE o.customer_id = c.customer_id))                       AS paid
FROM customers c;
-- (Logins only cover Sep–Oct 2025 in this dataset, so that step is not a true funnel stage —
--  in real funnels each step requires the previous one: add the earlier EXISTS to each FILTER.)


-- -----------------------------------------------------------------------------
-- 10. Market basket: products bought together
-- -----------------------------------------------------------------------------

SELECT pa.product_name AS product_a, pb.product_name AS product_b, COUNT(*) AS times_together
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND a.product_id < b.product_id   -- each pair once
JOIN products pa ON pa.product_id = a.product_id
JOIN products pb ON pb.product_id = b.product_id
GROUP BY pa.product_name, pb.product_name
HAVING COUNT(*) >= 2
ORDER BY times_together DESC, product_a;           -- 4 pairs bought together twice


-- -----------------------------------------------------------------------------
-- 11. Missing numbers in a sequence
-- -----------------------------------------------------------------------------

CREATE TEMP TABLE invoices (invoice_no INT PRIMARY KEY);
INSERT INTO invoices SELECT g FROM generate_series(1, 20) g WHERE g NOT IN (4, 9, 10, 17);

-- (a) Every missing number, via an anti-join with the full range.
SELECT g AS missing_invoice
FROM generate_series((SELECT MIN(invoice_no) FROM invoices), (SELECT MAX(invoice_no) FROM invoices)) g
WHERE NOT EXISTS (SELECT 1 FROM invoices i WHERE i.invoice_no = g);

-- (b) Gap ranges, via LEAD (scales to huge tables: no series needed).
SELECT invoice_no + 1 AS gap_from, next_no - 1 AS gap_to
FROM (SELECT invoice_no, LEAD(invoice_no) OVER (ORDER BY invoice_no) AS next_no FROM invoices) x
WHERE next_no - invoice_no > 1;


-- -----------------------------------------------------------------------------
-- 12. Overlapping intervals: double-booked meeting rooms
-- -----------------------------------------------------------------------------

CREATE TEMP TABLE bookings (booking_id INT, room TEXT, starts_at TIMESTAMP, ends_at TIMESTAMP);
INSERT INTO bookings VALUES
    (1, 'A', '2025-11-03 09:00', '2025-11-03 10:00'),
    (2, 'A', '2025-11-03 09:30', '2025-11-03 11:00'),   -- overlaps 1
    (3, 'A', '2025-11-03 11:00', '2025-11-03 12:00'),   -- touches 2 (not an overlap: half-open)
    (4, 'B', '2025-11-03 09:00', '2025-11-03 12:00');

-- Two intervals overlap iff each starts before the other ends.
SELECT a.booking_id, b.booking_id AS conflicts_with, a.room
FROM bookings a
JOIN bookings b ON a.room = b.room
               AND a.booking_id < b.booking_id
               AND a.starts_at < b.ends_at
               AND b.starts_at < a.ends_at;        -- only (1, 2)

-- Prevent it at write time with an EXCLUDE constraint (needs btree_gist for "room WITH =").
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE TEMP TABLE bookings_safe (
    room   TEXT,
    during TSRANGE,
    EXCLUDE USING gist (room WITH =, during WITH &&)   -- && = ranges overlap
);
INSERT INTO bookings_safe VALUES ('A', '[2025-11-03 09:00, 2025-11-03 10:00)');
-- INSERT INTO bookings_safe VALUES ('A', '[2025-11-03 09:30, 2025-11-03 11:00)');
--   ERROR: conflicting key value violates exclusion constraint


-- -----------------------------------------------------------------------------
-- 13. Relational division: customers who bought from EVERY root category
-- -----------------------------------------------------------------------------

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
HAVING COUNT(DISTINCT t.root_id) = (SELECT COUNT(*) FROM categories WHERE parent_id IS NULL)
ORDER BY o.customer_id;                             -- bought Electronics AND Home AND Books


-- -----------------------------------------------------------------------------
-- 14. "A but not B": bought a laptop, never bought an accessory
-- -----------------------------------------------------------------------------

SELECT c.customer_id, c.first_name
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
              JOIN products p ON p.product_id = oi.product_id
              WHERE o.customer_id = c.customer_id AND p.category_id = 3)
  AND NOT EXISTS (SELECT 1 FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
                  JOIN products p ON p.product_id = oi.product_id
                  WHERE o.customer_id = c.customer_id AND p.category_id = 4)
ORDER BY c.customer_id;


-- -----------------------------------------------------------------------------
-- 15. Median & percentiles
-- -----------------------------------------------------------------------------

WITH totals AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items GROUP BY order_id
)
SELECT ROUND(AVG(total), 2)                                          AS mean_order,
       PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY total)           AS median_order,  -- 374: the mean is skewed by laptops
       PERCENTILE_CONT(0.9)  WITHIN GROUP (ORDER BY total)           AS p90_order,
       PERCENTILE_DISC(0.5)  WITHIN GROUP (ORDER BY total)           AS median_actual_value
FROM totals;
