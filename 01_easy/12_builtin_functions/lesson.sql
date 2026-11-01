-- =============================================================================
-- 01_easy/12 · Built-in Functions — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Changing case and trimming (cleaning)
-- -----------------------------------------------------------------------------

SELECT UPPER('sql') AS up,                     -- 'SQL'
       LOWER('SQL') AS low,                    -- 'sql'
       INITCAP('the silent ORBIT') AS title,   -- 'The Silent Orbit'
       TRIM('   padded   ') AS trimmed,        -- removes spaces on both sides
       TRIM(BOTH '-' FROM '--x--') AS custom;  -- trims any character you choose

-- Normalise before comparing: user-typed emails often have stray case/spaces.
SELECT customer_id FROM customers
WHERE LOWER(TRIM(email)) = LOWER(TRIM('  Aarav.Shah@MAIL.com '));


-- -----------------------------------------------------------------------------
-- 2. Extracting parts of strings
-- -----------------------------------------------------------------------------

SELECT email,
       STRPOS(email, '@')                      AS at_position,   -- 1-based position
       LEFT(email, STRPOS(email, '@') - 1)     AS username,      -- everything before @
       SPLIT_PART(email, '@', 1)               AS username_2,    -- same, simpler & clearer
       SPLIT_PART(email, '@', 2)               AS domain,
       SUBSTRING(email FROM 1 FOR 3)           AS first_three,   -- SQL strings start at 1, not 0
       RIGHT(email, 4)                         AS last_four
FROM employees
LIMIT 3;

-- Phone numbers: the country code is the part before the first '-'.
SELECT phone, SPLIT_PART(phone, '-', 1) AS country_code
FROM customers
WHERE phone IS NOT NULL;

-- Initials and formatted names.
SELECT first_name, last_name,
       LEFT(first_name, 1) || '. ' || UPPER(last_name) AS short_name,  -- 'A. SHAH'
       LENGTH(first_name || last_name)                 AS name_length
FROM customers
LIMIT 5;


-- -----------------------------------------------------------------------------
-- 3. Replacing, padding, regex
-- -----------------------------------------------------------------------------

-- Digits-only phone: regex \D = "any non-digit", 'g' = replace all occurrences.
SELECT phone, REGEXP_REPLACE(phone, '\D', '', 'g') AS digits_only
FROM customers WHERE phone IS NOT NULL LIMIT 3;

-- REPLACE for plain text substitution (no regex).
SELECT product_name, REPLACE(product_name, 'Laptop', 'Notebook') AS renamed
FROM products WHERE product_name LIKE '%Laptop%';

-- Zero-padded invoice numbers: 'INV-00007'. LPAD needs text input.
SELECT order_id, 'INV-' || LPAD(order_id::text, 5, '0') AS invoice_no
FROM orders LIMIT 3;

-- FORMAT builds strings safely with placeholders (%s = value, %L = quoted literal).
SELECT FORMAT('%s %s works as %s', first_name, last_name, job_title) AS sentence
FROM employees LIMIT 3;


-- -----------------------------------------------------------------------------
-- 4. Numeric functions
-- -----------------------------------------------------------------------------

SELECT ROUND(2.567, 2)  AS round_2,      -- 2.57   (rounds half away from zero)
       TRUNC(2.567, 2)  AS trunc_2,      -- 2.56   (just cuts)
       CEIL(2.1)        AS ceil_,        -- 3      (up)
       FLOOR(-2.1)      AS floor_,       -- -3     (down, toward -infinity)
       ROUND(1234.5, -2) AS to_hundreds, -- 1200   (negative digits round left of the point)
       ABS(-7)          AS abs_,
       MOD(17, 5)       AS mod_,         -- 2
       POWER(2, 10)     AS pow_,         -- 1024
       SQRT(144)        AS sqrt_;        -- 12

-- Price points: round UP to the next 10, and "charm pricing" ending in .99.
SELECT product_name, price,
       CEIL(price / 10) * 10   AS next_ten,
       CEIL(price) - 0.01      AS charm_price
FROM products
WHERE product_id IN (1, 5, 6, 18);

-- GREATEST / LEAST compare values WITHIN a row (MAX/MIN compare across rows).
-- Business rule: 30% sale, but never sell below cost.
SELECT product_name, price, cost,
       GREATEST(ROUND(price * 0.70, 2), cost) AS sale_price
FROM products
LIMIT 5;

-- Histogram buckets: price bands of 500 between 0 and 2500.
SELECT WIDTH_BUCKET(price, 0, 2500, 5) AS bucket, COUNT(*) AS products
FROM products
GROUP BY bucket
ORDER BY bucket;


-- -----------------------------------------------------------------------------
-- 5. Current date/time
-- -----------------------------------------------------------------------------

SELECT CURRENT_DATE      AS today,
       now()             AS now_tx,      -- start time of the current TRANSACTION
       clock_timestamp() AS wall_clock,  -- actual current time (changes during a statement)
       CURRENT_TIME      AS time_now;


-- -----------------------------------------------------------------------------
-- 6. Extracting parts of dates
-- -----------------------------------------------------------------------------

SELECT order_date,
       EXTRACT(YEAR    FROM order_date) AS yr,
       EXTRACT(MONTH   FROM order_date) AS mon,
       EXTRACT(DAY     FROM order_date) AS dy,
       EXTRACT(HOUR    FROM order_date) AS hr,
       EXTRACT(QUARTER FROM order_date) AS qtr,
       EXTRACT(ISODOW  FROM order_date) AS iso_dow,   -- Monday = 1 ... Sunday = 7
       EXTRACT(EPOCH   FROM order_date) AS unix_secs  -- seconds since 1970-01-01
FROM orders
LIMIT 3;

-- Which weekday gets the most orders?
SELECT TO_CHAR(order_date, 'FMDay') AS weekday,
       COUNT(*)                     AS orders
FROM orders
GROUP BY weekday, EXTRACT(ISODOW FROM order_date)
ORDER BY EXTRACT(ISODOW FROM order_date);          -- sort by number, not by name text


-- -----------------------------------------------------------------------------
-- 7. DATE_TRUNC: the key to time-series reporting
-- -----------------------------------------------------------------------------

-- Truncates DOWN to the start of the unit, keeping a real timestamp
-- (so it sorts chronologically and keeps the year).
SELECT TIMESTAMP '2024-11-29 06:55:00' AS ts,
       DATE_TRUNC('year',  TIMESTAMP '2024-11-29 06:55:00') AS yr,
       DATE_TRUNC('month', TIMESTAMP '2024-11-29 06:55:00') AS mon,
       DATE_TRUNC('week',  TIMESTAMP '2024-11-29 06:55:00') AS wk,   -- Monday of that week
       DATE_TRUNC('hour',  TIMESTAMP '2024-11-29 06:55:00') AS hr;

-- Monthly payments in 2024 with human-friendly labels.
SELECT TO_CHAR(DATE_TRUNC('month', paid_at), 'Mon YYYY') AS month_label,
       SUM(amount)                                       AS collected
FROM payments
WHERE paid_at >= '2024-01-01' AND paid_at < '2025-01-01'
GROUP BY DATE_TRUNC('month', paid_at)
ORDER BY DATE_TRUNC('month', paid_at);     -- sort by the timestamp, not the text label


-- -----------------------------------------------------------------------------
-- 8. Date arithmetic and AGE
-- -----------------------------------------------------------------------------

SELECT DATE '2025-01-31' + INTERVAL '1 month'  AS plus_month,  -- 2025-02-28: clamps to month end
       DATE '2025-03-01' - INTERVAL '1 day'    AS minus_day,   -- 2025-02-28
       DATE '2025-03-01' - DATE '2025-02-01'   AS days_diff,   -- 28 (an integer)
       AGE(DATE '2025-11-01', DATE '2015-01-10') AS age_interval; -- 10 years 9 mons 22 days

-- Employee tenure in whole years, as of a FIXED date so results are reproducible.
SELECT first_name, hire_date,
       EXTRACT(YEAR FROM AGE(DATE '2025-11-01', hire_date)) AS years_of_service
FROM employees
ORDER BY years_of_service DESC;

-- Days between order and shipment.
SELECT order_id, shipped_date - order_date::date AS days_to_ship
FROM orders WHERE shipped_date IS NOT NULL LIMIT 5;


-- -----------------------------------------------------------------------------
-- 9. Formatting and parsing with TO_CHAR / TO_DATE
-- -----------------------------------------------------------------------------

SELECT TO_CHAR(TIMESTAMP '2025-03-21 14:05:00', 'DD Mon YYYY, HH24:MI') AS pretty,  -- 21 Mar 2025, 14:05
       TO_CHAR(TIMESTAMP '2025-03-21 14:05:00', 'YYYY-"Q"Q')            AS quarter, -- 2025-Q1
       TO_CHAR(1234567.891, 'FM9,999,999.00')                           AS money,   -- 1,234,567.89
       TO_DATE('21/03/2025', 'DD/MM/YYYY')                              AS parsed,  -- 2025-03-21
       MAKE_DATE(2025, 12, 25)                                          AS xmas;


-- -----------------------------------------------------------------------------
-- 10. generate_series for dates: build a calendar
-- -----------------------------------------------------------------------------

-- Every day of the first week of September 2025. Used to fill gaps in
-- time series (days with zero orders still need a row) — see 02_medium/01.
SELECT d::date AS day, TO_CHAR(d, 'Dy') AS weekday
FROM generate_series(DATE '2025-09-01', DATE '2025-09-07', INTERVAL '1 day') AS d;
