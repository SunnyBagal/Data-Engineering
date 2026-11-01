-- =============================================================================
-- 01_easy/02 · Data Types — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Inspect types: pg_typeof() tells you the type of any expression
-- -----------------------------------------------------------------------------

SELECT pg_typeof(42)            AS int_literal,       -- integer
       pg_typeof(42.5)          AS decimal_literal,   -- numeric (exact!), not float
       pg_typeof('hello')       AS text_literal,      -- unknown -> resolved to text when used
       pg_typeof(TRUE)          AS bool_literal,
       pg_typeof(now())         AS now_type;          -- timestamp with time zone

-- Types of real columns in our database.
SELECT pg_typeof(price), pg_typeof(attributes), pg_typeof(created_at)
FROM products
LIMIT 1;


-- -----------------------------------------------------------------------------
-- 2. Exact vs approximate numbers  (why money is NUMERIC)
-- -----------------------------------------------------------------------------

-- FLOAT8 (double precision) stores binary fractions; 0.1 has no exact binary form.
SELECT 0.1::float8 + 0.2::float8           AS float_sum,     -- 0.30000000000000004
       0.1::numeric + 0.2::numeric         AS numeric_sum,   -- 0.3 exactly
       (0.1::float8 + 0.2::float8) = 0.3   AS float_equal;   -- FALSE !

-- Summing many small float values accumulates error. NUMERIC never drifts.
SELECT SUM(0.01::float8)  AS float_total,     -- not exactly 100
       SUM(0.01::numeric) AS numeric_total    -- exactly 100.00
FROM generate_series(1, 10000);               -- generate_series: makes 10,000 rows on the fly

-- NUMERIC(p,s) rounds to s decimal places on storage, and errors if too many digits.
SELECT 123.456::NUMERIC(5,2) AS rounded;      -- 123.46
-- SELECT 1234.5::NUMERIC(5,2);               -- ERROR: numeric field overflow (max 999.99)


-- -----------------------------------------------------------------------------
-- 3. Integer division — a bug factory
-- -----------------------------------------------------------------------------

SELECT 5 / 2          AS int_div,        -- 2   (both ints -> int result, truncated)
       5 / 2.0        AS numeric_div,    -- 2.5 (one numeric operand promotes the result)
       5::numeric / 2 AS cast_div,       -- 2.5 (explicit cast: clearest intent)
       5 % 2          AS remainder;      -- 1   (modulo)

-- Real example: share of orders that were cancelled.
-- WRONG: integer / integer = 0
SELECT 3 / 46 AS wrong_ratio;
-- RIGHT: cast first, then round for display.
SELECT ROUND(3::numeric / 46 * 100, 2) AS cancelled_pct;   -- 6.52


-- -----------------------------------------------------------------------------
-- 4. Text types
-- -----------------------------------------------------------------------------

-- CHAR(n) pads with spaces to n characters; VARCHAR/TEXT do not.
SELECT octet_length('ab'::CHAR(5))    AS char_bytes,     -- 5: stored padded to 'ab   '
       length('ab'::CHAR(5))          AS char_length,    -- 2: length() ignores the padding
       'ab'::CHAR(5) || '|'           AS char_concat,    -- 'ab|': padding is dropped on conversion to text
       octet_length('ab'::VARCHAR(5)) AS varchar_bytes;  -- 2: VARCHAR stores exactly what you gave
-- This padding weirdness is why CHAR(n) is rarely used outside fixed-width codes.

-- VARCHAR(n) enforces a maximum length: a free validation rule.
-- SELECT 'too long for five'::VARCHAR(5);   -- explicit cast silently truncates to 'too l'
-- INSERT of a too-long value into a VARCHAR(5) column raises an ERROR instead (safer).

-- Text sorts alphabetically, character by character -> '10' < '9'.
SELECT '10' < '9'  AS text_compare,     -- TRUE
        10  <  9   AS int_compare;      -- FALSE


-- -----------------------------------------------------------------------------
-- 5. Dates, timestamps and intervals
-- -----------------------------------------------------------------------------

SELECT DATE '2024-02-29'                  AS leap_day,        -- typed literal: unambiguous
       DATE '2024-02-29' + 1              AS next_day,        -- date + int = date (days)
       DATE '2024-03-01' - DATE '2024-02-01' AS days_between,  -- date - date = int (29)
       TIMESTAMP '2025-01-01 10:00' + INTERVAL '90 minutes' AS plus_interval,
       AGE(DATE '2025-11-01', DATE '2022-01-15')           AS age_interval;

-- Invalid dates are rejected — this is why dates must not be stored as text.
-- SELECT DATE '2023-02-29';   -- ERROR: date/time field value out of range

-- TIMESTAMP vs TIMESTAMPTZ: TIMESTAMPTZ is stored in UTC and converted to the
-- session time zone on display. Same instant, different wall-clock text.
SET TIME ZONE 'Asia/Kolkata';
SELECT TIMESTAMPTZ '2025-01-01 12:00:00+00' AS shown_in_india;      -- 17:30 +05:30
SET TIME ZONE 'America/New_York';
SELECT TIMESTAMPTZ '2025-01-01 12:00:00+00' AS shown_in_new_york;   -- 07:00 -05:00
RESET TIME ZONE;


-- -----------------------------------------------------------------------------
-- 6. Booleans
-- -----------------------------------------------------------------------------

-- Postgres accepts several spellings on input, always displays t/f.
SELECT 'yes'::boolean, 'off'::boolean, 't'::boolean, 1::boolean;

-- A boolean column can be used directly as a condition (no "= TRUE" needed).
SELECT product_name FROM products WHERE is_discontinued;


-- -----------------------------------------------------------------------------
-- 7. Casting
-- -----------------------------------------------------------------------------

SELECT CAST('42' AS INT) + 1      AS standard_cast,   -- portable to every database
       '42'::INT + 1              AS pg_cast,         -- Postgres shorthand
       '2025-05-01'::DATE         AS text_to_date,
       123.789::INT               AS rounds_not_truncates,   -- 124 (rounds!)
       TRUNC(123.789)             AS truncated;              -- 123

-- Bad casts fail loudly — good: you find dirty data instead of storing it.
-- SELECT 'abc'::INT;   -- ERROR: invalid input syntax for type integer


-- -----------------------------------------------------------------------------
-- 8. A table that uses good type choices (TEMP = disappears at session end)
-- -----------------------------------------------------------------------------

CREATE TEMP TABLE type_demo (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- BIGINT: won't overflow in a big table
    sku         CHAR(8),             -- fixed-length code: CHAR is a fair fit
    title       VARCHAR(120) NOT NULL, -- max length is a real business rule
    description TEXT,                -- unbounded free text
    price       NUMERIC(10,2),       -- exact money
    weight_kg   REAL,                -- measured value: approximation is fine
    in_stock    BOOLEAN DEFAULT TRUE,
    released_on DATE,
    updated_at  TIMESTAMPTZ DEFAULT now(),  -- moment in time -> TZ-aware
    tags        TEXT[],              -- Postgres array
    external_id UUID DEFAULT gen_random_uuid()  -- gen_random_uuid() is built in since PG 13
);

INSERT INTO type_demo (sku, title, price, weight_kg, released_on, tags)
VALUES ('AB-12345', 'Desk Lamp', 29.99, 1.25, '2025-03-01', ARRAY['home','lighting']);

SELECT * FROM type_demo;

-- Arrays are 1-indexed; ANY() checks membership.
SELECT tags[1] AS first_tag, 'home' = ANY(tags) AS is_home FROM type_demo;

DROP TABLE type_demo;
