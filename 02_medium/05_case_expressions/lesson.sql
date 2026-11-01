-- =============================================================================
-- 02_medium/05 · CASE Expressions — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Searched CASE: labels from ranges
-- -----------------------------------------------------------------------------

-- WHENs are tested top to bottom; the first TRUE wins. Ordering from the
-- smallest threshold up means "< 500" only sees prices that are already >= 50.
SELECT product_name,
       price,
       CASE
           WHEN price < 50  THEN 'budget'
           WHEN price < 500 THEN 'mid-range'
           ELSE                  'premium'      -- everything else (>= 500)
       END AS price_band
FROM products
ORDER BY price;

-- WRONG ORDER: the broad condition first swallows everything below 500,
-- so no product is ever labelled 'budget'.
SELECT product_name, price,
       CASE WHEN price < 500 THEN 'mid-range'
            WHEN price < 50  THEN 'budget'      -- unreachable
            ELSE 'premium' END AS broken_band
FROM products
WHERE price < 50;


-- -----------------------------------------------------------------------------
-- 2. Simple CASE: map one value to another
-- -----------------------------------------------------------------------------

-- Compares status to each WHEN value with "=". Good for code -> label mappings.
SELECT order_id,
       status,
       CASE status
           WHEN 'pending'   THEN 'Awaiting dispatch'
           WHEN 'shipped'   THEN 'On the way'
           WHEN 'delivered' THEN 'Completed'
           WHEN 'returned'  THEN 'Refund due'
           ELSE                  'Closed'
       END AS customer_message
FROM orders
WHERE order_id IN (1, 4, 8, 43, 45);

-- Simple CASE can't match NULL ("NULL = NULL" is unknown):
SELECT first_name, city,
       CASE city WHEN NULL THEN 'unknown' ELSE city END            AS never_matches,
       CASE WHEN city IS NULL THEN 'unknown' ELSE city END         AS correct,
       COALESCE(city, 'unknown')                                   AS shortcut
FROM customers
WHERE customer_id IN (15, 16);


-- -----------------------------------------------------------------------------
-- 3. Missing ELSE -> NULL
-- -----------------------------------------------------------------------------

-- Products that don't match any WHEN get NULL. Make it explicit with ELSE.
SELECT product_name,
       CASE WHEN stock_qty = 0 THEN 'out of stock'
            WHEN stock_qty < 10 THEN 'low' END       AS stock_flag_implicit_null,
       CASE WHEN stock_qty = 0 THEN 'out of stock'
            WHEN stock_qty < 10 THEN 'low'
            ELSE 'ok' END                            AS stock_flag
FROM products
ORDER BY stock_qty;


-- -----------------------------------------------------------------------------
-- 4. CASE with multiple columns and complex conditions
-- -----------------------------------------------------------------------------

-- Shipping-speed SLA per order. NULL check first: arithmetic with NULL is NULL,
-- and "NULL <= 2" is unknown, so unshipped orders would fall to ELSE ('slow').
SELECT order_id,
       status,
       shipped_date - order_date::date AS days,
       CASE
           WHEN shipped_date IS NULL                    THEN 'not shipped'
           WHEN shipped_date - order_date::date <= 2    THEN 'fast'
           WHEN shipped_date - order_date::date = 3     THEN 'normal'
           ELSE                                              'slow'
       END AS ship_speed
FROM orders
ORDER BY order_id;

-- Combining conditions with AND / OR inside WHEN.
SELECT first_name, last_name, job_title, salary, hire_date,
       CASE
           WHEN NOT is_active                                   THEN 'former'
           WHEN salary >= 150000                                THEN 'executive'
           WHEN salary >= 100000 OR job_title LIKE '%Manager%'  THEN 'senior'
           WHEN hire_date >= '2024-01-01'                       THEN 'new joiner'
           ELSE                                                      'staff'
       END AS segment
FROM employees;


-- -----------------------------------------------------------------------------
-- 5. CASE in GROUP BY: count per bucket
-- -----------------------------------------------------------------------------

-- Group by the CASE expression (or by its alias/position in Postgres).
SELECT CASE WHEN price < 50  THEN 'budget'
            WHEN price < 500 THEN 'mid-range'
            ELSE 'premium' END AS price_band,
       COUNT(*)                AS products,
       ROUND(AVG(price), 2)    AS avg_price
FROM products
GROUP BY price_band
ORDER BY MIN(price);                          -- sort bands by their cheapest member


-- -----------------------------------------------------------------------------
-- 6. CASE in ORDER BY: custom sort order
-- -----------------------------------------------------------------------------

-- Alphabetical status order is meaningless; sort by workflow stage instead.
SELECT order_id, status, order_date
FROM orders
ORDER BY CASE status
             WHEN 'pending'   THEN 1
             WHEN 'shipped'   THEN 2
             WHEN 'delivered' THEN 3
             WHEN 'returned'  THEN 4
             WHEN 'cancelled' THEN 5
         END,
         order_date DESC;

-- Pin one value to the top: India first, other countries alphabetically.
-- (GROUP BY instead of DISTINCT: with SELECT DISTINCT, every ORDER BY
--  expression must also appear in the select list.)
SELECT country
FROM customers
GROUP BY country
ORDER BY CASE WHEN country = 'India' THEN 0 ELSE 1 END, country;


-- -----------------------------------------------------------------------------
-- 7. CASE inside aggregates: conditional counts and sums
-- -----------------------------------------------------------------------------

-- Portable alternative to FILTER: count rows matching a condition per group.
SELECT country,
       COUNT(*)                                            AS customers,
       SUM(CASE WHEN phone IS NOT NULL THEN 1 ELSE 0 END)  AS with_phone,  -- ELSE 0, not NULL
       ROUND(100.0 * SUM(CASE WHEN phone IS NOT NULL THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                AS pct_with_phone
FROM customers
GROUP BY country
ORDER BY country;

-- Revenue split by discounted vs full-price lines.
SELECT ROUND(SUM(CASE WHEN discount > 0
                      THEN quantity * unit_price * (1 - discount) ELSE 0 END), 2) AS discounted_revenue,
       ROUND(SUM(CASE WHEN discount = 0
                      THEN quantity * unit_price ELSE 0 END), 2)                  AS full_price_revenue
FROM order_items;


-- -----------------------------------------------------------------------------
-- 8. CASE for safe calculations
-- -----------------------------------------------------------------------------

-- Avoid division by zero explicitly (NULLIF is the shorter alternative).
SELECT product_name, price, stock_qty,
       CASE WHEN stock_qty = 0 THEN NULL
            ELSE ROUND(price / stock_qty, 2) END AS price_per_unit
FROM products
WHERE product_id IN (4, 5, 9);


-- -----------------------------------------------------------------------------
-- 9. CASE in UPDATE: different rules per row, one statement
-- -----------------------------------------------------------------------------

BEGIN;
-- Restocking policy: empty -> 50 units, low (<10) -> +20, else unchanged.
-- Doing this as three UPDATEs would scan the table three times and risk
-- applying two rules to the same row.
UPDATE products
SET stock_qty = CASE
                    WHEN stock_qty = 0  THEN 50
                    WHEN stock_qty < 10 THEN stock_qty + 20
                    ELSE stock_qty
                END
WHERE NOT is_discontinued
  AND stock_qty < 10                     -- only touch rows that change
RETURNING product_name, stock_qty;
ROLLBACK;
