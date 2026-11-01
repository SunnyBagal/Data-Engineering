-- =============================================================================
-- 01_easy/07 · WHERE — SOLUTIONS
-- =============================================================================


-- Q1.
SELECT first_name || ' ' || last_name AS full_name, salary
FROM employees
WHERE dept_id = 1
  AND salary > 90000;                 -- Rahul, Sara, Arjun, Emily, Vikram


-- Q2. Wrong: AND is evaluated first -> India (any year) OR (UK AND 2023).
SELECT first_name, country, signup_date FROM customers
WHERE country = 'India' OR country = 'UK'
  AND signup_date >= '2023-01-01' AND signup_date < '2024-01-01';   -- 10 rows

-- Right #1: parentheses group the OR.
SELECT first_name, country, signup_date FROM customers
WHERE (country = 'India' OR country = 'UK')
  AND signup_date >= '2023-01-01' AND signup_date < '2024-01-01';   -- 5 rows

-- Right #2: IN removes the OR entirely (preferred: shorter, no trap).
SELECT first_name, country, signup_date FROM customers
WHERE country IN ('India', 'UK')
  AND signup_date >= '2023-01-01' AND signup_date < '2024-01-01';   -- 5 rows


-- Q3. BETWEEN is inclusive on both ends.
SELECT product_name, price, price - cost AS margin
FROM products
WHERE NOT is_discontinued
  AND price BETWEEN 50 AND 400;


-- Q4. ILIKE ignores case, so 'Headphones' (lowercase "phone") matches too.
--     LIKE '%Phone%' requires capital P -> misses "Noise Cancelling Headphones".
SELECT product_name FROM products WHERE product_name ILIKE '%phone%';
-- Portable alternative (works in every database):
SELECT product_name FROM products WHERE LOWER(product_name) LIKE '%phone%';


-- Q5. "< '2025-01-01'" includes every moment of Dec 31. BETWEEN '2024-10-01'
--     AND '2024-12-31' would miss orders after midnight on Dec 31.
SELECT order_id, order_date, status
FROM orders
WHERE status = 'delivered'
  AND order_date >= '2024-10-01'
  AND order_date <  '2025-01-01';


-- Q6. The alias "revenue" can't be used in WHERE, so the formula is repeated.
SELECT order_id,
       product_id,
       discount,
       ROUND(quantity * unit_price * (1 - discount), 2) AS revenue
FROM order_items
WHERE discount > 0
  AND quantity * unit_price * (1 - discount) > 500;


-- Q7. '+' has no special meaning in LIKE (only % and _ do), so '+91%' is safe.
BEGIN;
SELECT customer_id, first_name, phone FROM customers WHERE phone LIKE '+91%';  -- 4 rows
UPDATE customers SET phone = NULL WHERE phone LIKE '+91%';                     -- UPDATE 4
SELECT COUNT(*) AS remaining FROM customers WHERE phone LIKE '+91%';           -- 0
ROLLBACK;
