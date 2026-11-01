-- =============================================================================
-- 01_easy/02 · Data Types — SOLUTIONS
-- =============================================================================


-- Q1. INT / INT -> INT (fraction is truncated, not rounded).
--     One NUMERIC operand -> NUMERIC result.
SELECT 7 / 2   AS int_div,      -- 3
       7 / 2.0 AS real_div,     -- 3.5000000000000000
       7 % 2   AS remainder;    -- 1


-- Q2.
SELECT pg_typeof(product_name)    AS product_name,     -- character varying
       pg_typeof(price)           AS price,            -- numeric
       pg_typeof(stock_qty)       AS stock_qty,        -- integer
       pg_typeof(is_discontinued) AS is_discontinued,  -- boolean
       pg_typeof(attributes)      AS attributes,       -- jsonb
       pg_typeof(created_at)      AS created_at        -- date
FROM products
LIMIT 1;


-- Q3. Each float addition rounds to the nearest binary fraction; errors add up.
SELECT SUM(0.10::float8)          AS float_total,
       SUM(0.10::float8) = 100    AS float_ok,      -- false
       SUM(0.10::numeric)         AS numeric_total,
       SUM(0.10::numeric) = 100   AS numeric_ok     -- true
FROM generate_series(1, 1000);


-- Q4. DATE - DATE returns an integer number of days.
--     DATE + INTERVAL returns a TIMESTAMP. Month arithmetic is calendar-aware.
SELECT DATE '2025-10-30' - DATE '2023-01-05'       AS days_between,   -- 1029
       DATE '2025-10-30' + INTERVAL '3 months'     AS plus_3_months;  -- 2026-01-30 00:00:00


-- Q5.
SELECT table_name, column_name, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_schema = 'public'
  AND data_type = 'numeric'
ORDER BY table_name, ordinal_position;


-- Q6.
--  a) VARCHAR(20)/TEXT — it's an identifier, not a number: never do maths on it,
--     and INT would lose '+', '-', spaces and leading zeros.
--  b) INT — whole number; add CHECK (stock >= 0). SMALLINT risks overflow at 32k.
--  c) NUMERIC(12,2) — money must be exact (NOT float).
--  d) TIMESTAMPTZ — stored in UTC, displayed per user time zone; no ambiguity.
--  e) CHAR(2) — always exactly 2 chars; a fair use of CHAR (or VARCHAR(2)).
--  f) BIGINT — INT tops out at ~2.1 billion.
--  g) REAL / DOUBLE PRECISION — measurement already has error; floats are compact & fast.


-- Q7.
CREATE TABLE product_reviews (   -- not TEMP: a temp table cannot have a FK to a permanent table
    review_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- auto id
    product_id   INT NOT NULL REFERENCES products(product_id),  -- must exist
    rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5), -- small range -> SMALLINT
    review_text  TEXT,                                           -- optional, unbounded
    is_verified  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO product_reviews (product_id, rating, review_text, is_verified) VALUES
    (1, 5, 'Fast and light, great battery.', TRUE),
    (1, 3, NULL, FALSE);                                         -- text is optional

SELECT * FROM product_reviews;

-- A value outside the CHECK fails — types + constraints protect data quality:
-- INSERT INTO product_reviews (product_id, rating) VALUES (1, 6);  -- ERROR: violates check

DROP TABLE product_reviews;
