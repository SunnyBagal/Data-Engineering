-- =============================================================================
-- 02_medium/04 · Set Operations — SOLUTIONS
-- =============================================================================


-- Q1. Each branch can have its own joins; only the output shape must match.
--     UNION ALL: the type label makes rows distinct anyway, so no need to dedupe.
SELECT 'customer'                        AS person_type,
       first_name || ' ' || last_name    AS full_name,
       email,
       city                              AS location
FROM customers
UNION ALL
SELECT 'employee',
       e.first_name || ' ' || e.last_name,
       e.email,
       d.location
FROM employees e
LEFT JOIN departments d ON d.dept_id = e.dept_id      -- LEFT: CEO/contractor have no dept
ORDER BY full_name;


-- Q2.
SELECT first_name FROM customers
INTERSECT
SELECT first_name FROM employees;                     -- Meera

SELECT first_name FROM employees
EXCEPT
SELECT first_name FROM customers
ORDER BY first_name;                                  -- 19 names


-- Q3. EXCEPT on ids, then fetch names with IN.
SELECT first_name, last_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM orders WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'
    EXCEPT
    SELECT customer_id FROM orders WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
)
ORDER BY customer_id;


-- Q4. INTERSECT chains naturally.
SELECT customer_id FROM orders WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'
INTERSECT
SELECT customer_id FROM orders WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
INTERSECT
SELECT customer_id FROM orders WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'
ORDER BY customer_id;                                 -- 1, 3, 4, 12


-- Q5. UNION treats NULLs as equal and keeps ONE NULL row (Liam's unknown city),
--     so 16 named places + 1 NULL = 17 rows.
SELECT city AS place FROM customers
UNION
SELECT location FROM departments
ORDER BY place;

SELECT location FROM departments
EXCEPT
SELECT city FROM customers;                           -- Bengaluru


-- Q6. A sort_key column keeps TOTAL last; the outer query hides it.
SELECT status, orders, pct
FROM (
    SELECT status,
           COUNT(*)                                                   AS orders,
           ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 1) AS pct,
           1                                                          AS sort_key
    FROM orders
    GROUP BY status
    UNION ALL
    SELECT 'TOTAL', COUNT(*), 100.0, 2
    FROM orders
) t
ORDER BY sort_key, orders DESC;


-- Q7a. Orders that should have been paid, minus orders that have a payment.
SELECT order_id FROM orders WHERE status IN ('shipped', 'delivered', 'returned')
EXCEPT
SELECT order_id FROM payments;                        -- 44 (cash on delivery)

-- Q7b.
SELECT customer_id FROM logins
EXCEPT
SELECT customer_id FROM orders;                       -- 19
