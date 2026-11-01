-- =============================================================================
-- 01_easy/08 · NULL Handling — SOLUTIONS
-- =============================================================================


-- Q1. Since we filter on phone IS NULL, COALESCE(phone, email) would always
--     return email here; selecting email directly is simpler and clearer.
SELECT first_name || ' ' || last_name AS full_name,
       email                          AS contact
FROM customers
WHERE phone IS NULL;


-- Q2. Two conditions: NULL test + exclusion of a status.
SELECT order_id, status, order_date
FROM orders
WHERE shipped_date IS NULL
  AND status <> 'cancelled';


-- Q3. COUNT(*) counts rows; COUNT(col) counts non-NULL values.
SELECT COUNT(*)                AS total,
       COUNT(phone)            AS with_phone,
       COUNT(city)             AS with_city,
       COUNT(referred_by)      AS referred,
       COUNT(*) - COUNT(phone) AS without_phone
FROM customers;


-- Q4. Buggy: referred_by contains NULLs. "x NOT IN (a, b, NULL)" expands to
--     x <> a AND x <> b AND x <> NULL; the last part is UNKNOWN, so the whole
--     condition can never be TRUE -> no rows.
SELECT customer_id, first_name FROM customers
WHERE customer_id NOT IN (SELECT referred_by FROM customers);           -- 0 rows

-- Fixed (exclude NULLs inside the subquery):
SELECT customer_id, first_name FROM customers
WHERE customer_id NOT IN (SELECT referred_by FROM customers WHERE referred_by IS NOT NULL);

-- Fixed (NOT EXISTS — NULL-safe by design, usually the best choice):
SELECT c.customer_id, c.first_name FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM customers r WHERE r.referred_by = c.customer_id);


-- Q5. For products with no 'color' key (or NULL attributes), ->> returns NULL.
--     NULL <> 'black' is UNKNOWN -> those rows are dropped.
SELECT product_name, attributes ->> 'color' AS color
FROM products WHERE attributes ->> 'color' <> 'black';                   -- 3 rows

--     IS DISTINCT FROM treats NULL as a comparable value: NULL is distinct from 'black'.
SELECT product_name, attributes ->> 'color' AS color
FROM products WHERE attributes ->> 'color' IS DISTINCT FROM 'black';     -- 22 rows


-- Q6. order_date is a TIMESTAMP; ::date drops the time so DATE - DATE = whole days.
--     COALESCE needs both arguments of the same type, hence the ::text cast.
SELECT order_id,
       status,
       shipped_date - order_date::date                              AS days_to_ship,
       COALESCE((shipped_date - order_date::date)::text || ' days',
                'not shipped')                                      AS ship_label
FROM orders;
-- Note: (NULL)::text || ' days' is NULL, so COALESCE falls through to 'not shipped'.

SELECT ROUND(AVG(shipped_date - order_date::date), 2) AS avg_days_to_ship   -- 2.44
FROM orders;                                       -- AVG skips the 5 unshipped orders


-- Q7.
BEGIN;
UPDATE customers SET phone = '' WHERE phone IS NULL;           -- the mistake (UPDATE 7)
SELECT COUNT(phone) AS after_mistake FROM customers;           -- 20: '' is NOT NULL

UPDATE customers SET phone = NULLIF(phone, '')                 -- '' -> NULL, others unchanged
WHERE phone = '';                                              -- touch only broken rows
SELECT COUNT(phone) AS after_repair FROM customers;            -- 13
ROLLBACK;
-- Lesson: empty string and NULL are different values in Postgres, MySQL and
-- SQL Server (Oracle is the exception: it stores '' as NULL).
-- A constraint like CHECK (phone <> '') would have prevented the mistake.
