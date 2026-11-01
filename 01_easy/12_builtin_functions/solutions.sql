-- =============================================================================
-- 01_easy/12 · Built-in Functions — SOLUTIONS
-- =============================================================================


-- Q1. LEFT(…, 1) = first character; SPLIT_PART splits on '@' and takes part 1.
SELECT customer_id,
       LEFT(first_name, 1) || '. ' || UPPER(last_name) AS badge,
       SPLIT_PART(email, '@', 1)                       AS username
FROM customers
ORDER BY customer_id;


-- Q2a.
SELECT product_name, LENGTH(product_name) AS chars
FROM products
ORDER BY chars DESC
LIMIT 1;

-- Q2b. STRPOS(name, ' ') > 0 means "contains a space" -> more than one word.
SELECT product_name, SPLIT_PART(product_name, ' ', 1) AS first_word
FROM products
WHERE STRPOS(product_name, ' ') > 0
  AND LENGTH(SPLIT_PART(product_name, ' ', 1)) > 6;


-- Q3. A fixed reference date keeps the answer reproducible (CURRENT_DATE changes daily).
SELECT first_name, last_name, hire_date,
       EXTRACT(YEAR FROM AGE(DATE '2025-11-01', hire_date)) AS years
FROM employees
ORDER BY years DESC, hire_date;

SELECT COUNT(*) AS five_plus_years
FROM employees
WHERE AGE(DATE '2025-11-01', hire_date) >= INTERVAL '5 years';   -- compare intervals directly


-- Q4. 'FMDay' = weekday name without padding spaces.
SELECT TO_CHAR(order_date, 'FMDay') AS weekday,
       COUNT(*)                     AS orders
FROM orders
GROUP BY weekday
ORDER BY orders DESC, weekday;


-- Q5.
SELECT SPLIT_PART(phone, '-', 1) AS calling_code,
       COUNT(*)                  AS customers
FROM customers
WHERE phone IS NOT NULL                -- SPLIT_PART(NULL, …) is NULL -> would form a NULL group
GROUP BY calling_code
ORDER BY customers DESC;


-- Q6.
SELECT product_name,
       price,
       CEIL(price / 10) * 10 AS next_ten,
       CEIL(price) - 0.01    AS charm_price
FROM products
WHERE stock_qty > 0
ORDER BY product_id;

BEGIN;
UPDATE products
SET price = CEIL(price) - 0.01
WHERE category_id = 4
RETURNING product_name, price;         -- 89.99 stays 89.99; 25.00 -> 24.99; 39.50 -> 39.99 (!)
ROLLBACK;
-- Note: CEIL raises 39.50 to 40 first, so the "charm" price is HIGHER than before.
-- Always preview pricing rules — a formula that looks harmless can raise prices.


-- Q7. Group and sort by the truncated timestamp; TO_CHAR only for display.
--     Sorting by the label text would give Apr, Aug, Dec, Feb, ...
SELECT TO_CHAR(DATE_TRUNC('month', paid_at), 'Mon YYYY') AS month_label,
       SUM(amount)                                       AS collected
FROM payments
WHERE paid_at >= '2024-01-01' AND paid_at < '2025-01-01'
GROUP BY DATE_TRUNC('month', paid_at)
ORDER BY DATE_TRUNC('month', paid_at);
