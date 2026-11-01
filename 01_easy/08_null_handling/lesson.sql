-- =============================================================================
-- 01_easy/08 · NULL Handling — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. NULL is not a value, so "=" doesn't work
-- -----------------------------------------------------------------------------

-- Every comparison with NULL is UNKNOWN (displayed as NULL / empty).
SELECT NULL = NULL      AS null_eq_null,      -- NULL (not TRUE!)
       NULL <> 1        AS null_neq_one,      -- NULL
       NULL + 10        AS arithmetic,        -- NULL: unknown + 10 is still unknown
       'a' || NULL      AS concat,            -- NULL
       NULL IS NULL     AS is_null_test;      -- TRUE: the correct test

-- WRONG: returns 0 rows, because "phone = NULL" is never TRUE.
SELECT first_name, phone FROM customers WHERE phone = NULL;

-- RIGHT: IS NULL / IS NOT NULL.
SELECT first_name, phone FROM customers WHERE phone IS NULL;       -- 7 rows
SELECT first_name, phone FROM customers WHERE phone IS NOT NULL;   -- 13 rows


-- -----------------------------------------------------------------------------
-- 2. Three-valued logic silently drops rows
-- -----------------------------------------------------------------------------

-- "Customers not in Mumbai": Liam (city NULL) is missing from BOTH lists,
-- because NULL = 'Mumbai' and NULL <> 'Mumbai' are both UNKNOWN.
SELECT COUNT(*) AS in_mumbai     FROM customers WHERE city =  'Mumbai';   -- 2
SELECT COUNT(*) AS not_in_mumbai FROM customers WHERE city <> 'Mumbai';   -- 17 (not 18!)

-- Include unknowns explicitly when the business wants them:
SELECT COUNT(*) FROM customers WHERE city <> 'Mumbai' OR city IS NULL;   -- 18

-- Or use the NULL-safe comparison IS DISTINCT FROM (treats NULL as a value):
SELECT COUNT(*) FROM customers WHERE city IS DISTINCT FROM 'Mumbai';     -- 18

-- Truth-table check: UNKNOWN AND FALSE = FALSE, UNKNOWN OR TRUE = TRUE.
SELECT (NULL AND FALSE) AS u_and_f,   -- false
       (NULL OR TRUE)   AS u_or_t,    -- true
       (NULL AND TRUE)  AS u_and_t;   -- NULL (unknown)


-- -----------------------------------------------------------------------------
-- 3. COALESCE: replace NULL with a fallback
-- -----------------------------------------------------------------------------

-- Returns the first non-NULL argument. Standard SQL -> works everywhere.
SELECT first_name,
       COALESCE(phone, 'no phone')       AS phone_display,
       COALESCE(city, 'Unknown city')    AS city_display
FROM customers;

-- Fallback chain: prefer phone, else email.
SELECT first_name, COALESCE(phone, email) AS best_contact FROM customers;

-- Treat a missing budget as 0 only when the business says "missing = none".
SELECT dept_name, budget, COALESCE(budget, 0) AS budget_or_zero FROM departments;

-- Concatenation that survives NULLs: CONCAT() ignores NULL arguments,
-- || does not. CONCAT_WS adds a separator and skips NULLs.
SELECT first_name || ' (' || city || ')'         AS with_pipes,     -- NULL for Liam
       CONCAT(first_name, ' (', city, ')')       AS with_concat,    -- 'Liam ()'
       CONCAT_WS(', ', first_name, city, country) AS with_ws        -- 'Liam, USA'
FROM customers
WHERE customer_id IN (1, 16);


-- -----------------------------------------------------------------------------
-- 4. NULLIF: turn a value INTO NULL (mostly to avoid division by zero)
-- -----------------------------------------------------------------------------

-- price / stock_qty fails for out-of-stock products (division by zero).
-- SELECT product_name, price / stock_qty FROM products;   -- ERROR: division by zero

-- NULLIF(stock_qty, 0) returns NULL when stock is 0; x / NULL = NULL, no error.
SELECT product_name,
       stock_qty,
       ROUND(price / NULLIF(stock_qty, 0), 2) AS price_per_unit_in_stock
FROM products;

-- Clean up "fake" values: treat empty strings as NULL.
SELECT NULLIF('', '') AS empty_becomes_null, NULLIF('x', '') AS stays_x;


-- -----------------------------------------------------------------------------
-- 5. NULLs and aggregate functions (preview of topic 10)
-- -----------------------------------------------------------------------------

SELECT COUNT(*)        AS all_rows,        -- 20: counts rows
       COUNT(phone)    AS with_phone,      -- 13: COUNT(col) skips NULLs
       COUNT(city)     AS with_city        -- 19
FROM customers;

-- AVG ignores NULL budgets: average of the 5 known budgets.
-- SUM / COUNT(*) treats the unknown budget as if it were 0. Different answers!
SELECT AVG(budget)                     AS avg_known,      -- 640000
       SUM(budget) / COUNT(*)          AS avg_null_as_0,  -- 533333.33
       AVG(COALESCE(budget, 0))        AS same_as_above
FROM departments;

-- Average days from order to shipment, computed only over shipped orders
-- (shipped_date - order_date is NULL for unshipped orders, so AVG skips them).
SELECT ROUND(AVG(shipped_date - order_date::date), 2) AS avg_days_to_ship FROM orders;


-- -----------------------------------------------------------------------------
-- 6. The NOT IN trap
-- -----------------------------------------------------------------------------

-- Goal: customers who never referred anyone.
-- referred_by contains NULLs -> "id NOT IN (..., NULL)" is never TRUE -> 0 rows.
SELECT customer_id, first_name
FROM customers
WHERE customer_id NOT IN (SELECT referred_by FROM customers);        -- 0 rows!

-- Fix 1: remove NULLs from the subquery.
SELECT customer_id, first_name
FROM customers
WHERE customer_id NOT IN (SELECT referred_by FROM customers
                          WHERE referred_by IS NOT NULL);           -- 12 rows

-- Fix 2 (preferred, NULL-safe by design): NOT EXISTS (02_medium/03).
SELECT c.customer_id, c.first_name
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM customers r WHERE r.referred_by = c.customer_id);


-- -----------------------------------------------------------------------------
-- 7. NULLs in sorting and DISTINCT
-- -----------------------------------------------------------------------------

-- Postgres sorts NULLs LAST in ascending order (as if NULL were the largest value).
SELECT dept_name, budget FROM departments ORDER BY budget;
-- Override when needed: missing budgets first, so someone fills them in.
SELECT dept_name, budget FROM departments ORDER BY budget NULLS FIRST;

-- DISTINCT and GROUP BY treat all NULLs as one group.
SELECT DISTINCT dept_id FROM employees ORDER BY dept_id;   -- one NULL row
