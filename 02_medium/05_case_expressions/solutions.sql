-- =============================================================================
-- 02_medium/05 · CASE Expressions — SOLUTIONS
-- =============================================================================


-- Q1. ORDER BY MIN(price) sorts bands by their cheapest member — more robust
--     than alphabetical (which would give budget, mid-range, premium by luck).
SELECT CASE WHEN price < 50  THEN 'budget'
            WHEN price < 500 THEN 'mid-range'
            ELSE                  'premium' END AS price_band,
       COUNT(*)             AS products,
       ROUND(AVG(price), 2) AS avg_price
FROM products
GROUP BY price_band
ORDER BY MIN(price);


-- Q2.
SELECT CASE WHEN salary >= 150000 THEN 'executive'
            WHEN salary >= 100000 THEN 'senior'
            WHEN salary >=  70000 THEN 'mid'
            ELSE                       'junior' END AS grade,
       COUNT(*) AS headcount
FROM employees
WHERE is_active
GROUP BY grade
ORDER BY MIN(salary) DESC;


-- Q3a. Order totals in a derived table; LEFT JOINs keep customers with no
--      qualifying orders; the status filter sits in ON so they aren't dropped.
SELECT c.first_name || ' ' || c.last_name           AS customer,
       ROUND(COALESCE(SUM(t.total), 0), 2)           AS spend,
       CASE WHEN COALESCE(SUM(t.total), 0) >= 3000 THEN 'gold'
            WHEN COALESCE(SUM(t.total), 0) >= 1000 THEN 'silver'
            WHEN COALESCE(SUM(t.total), 0) >  0    THEN 'bronze'
            ELSE                                        'none' END AS tier
FROM customers c
LEFT JOIN orders o
       ON o.customer_id = c.customer_id
      AND o.status NOT IN ('cancelled', 'returned')
LEFT JOIN (SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
           FROM order_items GROUP BY order_id) t ON t.order_id = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY spend DESC;

-- Q3b. Wrap Q3a in a derived table and count per tier.
SELECT tier, COUNT(*) AS customers
FROM (
    SELECT c.customer_id,
           CASE WHEN COALESCE(SUM(t.total), 0) >= 3000 THEN 'gold'
                WHEN COALESCE(SUM(t.total), 0) >= 1000 THEN 'silver'
                WHEN COALESCE(SUM(t.total), 0) >  0    THEN 'bronze'
                ELSE                                        'none' END AS tier
    FROM customers c
    LEFT JOIN orders o
           ON o.customer_id = c.customer_id
          AND o.status NOT IN ('cancelled', 'returned')
    LEFT JOIN (SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
               FROM order_items GROUP BY order_id) t ON t.order_id = o.order_id
    GROUP BY c.customer_id
) x
GROUP BY tier
ORDER BY CASE tier WHEN 'gold' THEN 1 WHEN 'silver' THEN 2 WHEN 'bronze' THEN 3 ELSE 4 END;
-- The duplicated CASE is ugly — CTEs (next topic) fix exactly this.


-- Q4. The NULL test must come first.
SELECT CASE WHEN shipped_date IS NULL                 THEN 'not shipped'
            WHEN shipped_date - order_date::date <= 2 THEN 'fast'
            WHEN shipped_date - order_date::date = 3  THEN 'normal'
            ELSE                                           'slow' END AS ship_speed,
       COUNT(*) AS orders
FROM orders
GROUP BY ship_speed
ORDER BY orders DESC;


-- Q5. IN inside WHEN keeps the rule compact.
SELECT order_id, status, order_date,
       CASE WHEN status IN ('pending', 'shipped', 'returned') THEN 'yes' ELSE 'no' END AS needs_action
FROM orders
ORDER BY CASE status WHEN 'pending'   THEN 1
                     WHEN 'shipped'   THEN 2
                     WHEN 'delivered' THEN 3
                     WHEN 'returned'  THEN 4
                     WHEN 'cancelled' THEN 5 END,
         order_date DESC;


-- Q6. ELSE 0 so a country with no phones shows 0, not NULL.
SELECT country,
       COUNT(*)                                                         AS customers,
       SUM(CASE WHEN phone IS NOT NULL THEN 1 ELSE 0 END)               AS with_phone,
       ROUND(100.0 * SUM(CASE WHEN phone IS NOT NULL THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                             AS pct_with_phone
FROM customers
GROUP BY country
ORDER BY pct_with_phone DESC, country;


-- Q7. The WHERE clause restricts the update to rows the policy changes; the
--     CASE then picks the rule. Discontinued products are excluded up front,
--     so the CASE doesn't need a branch for them.
BEGIN;
UPDATE products
SET price = CASE WHEN stock_qty = 0   THEN ROUND(price * 1.05, 2)
                 WHEN stock_qty > 100 THEN ROUND(price * 0.90, 2)
                 ELSE price END
WHERE NOT is_discontinued
  AND (stock_qty = 0 OR stock_qty > 100)
RETURNING product_name, stock_qty, price;
ROLLBACK;
