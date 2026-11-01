-- =============================================================================
-- 01_easy/02 · Data Types — EXERCISES
-- Uses: data types + topic 01 (SELECT, information_schema, transactions)
-- =============================================================================


-- Q1. Show the result of 7 / 2, 7 / 2.0 and 7 % 2 in one row with the column
--     names int_div, real_div, remainder. Explain the difference.
--     Expected: 3 | 3.5000000000000000 | 1



-- Q2. Use pg_typeof() to show the data type of these products columns:
--     product_name, price, stock_qty, is_discontinued, attributes, created_at.
--     (one row is enough)



-- Q3. A colleague stored prices as DOUBLE PRECISION. Demonstrate the problem:
--     sum the value 0.10 one thousand times as float8 and as numeric
--     (use generate_series), and show whether each equals 100.
--     Expected: float_ok = false, numeric_ok = true



-- Q4. How many days passed between the first order (2023-01-05) and the
--     last order (2025-10-30)? Use DATE literals and subtraction.
--     Then show 2025-10-30 plus an interval of 3 months.
--     Expected: 1029 days | 2026-01-30 00:00:00



-- Q5. Using information_schema.columns, list every column in the database
--     whose data_type is 'numeric', with its table name, precision and scale
--     (numeric_precision, numeric_scale).
--     Expected: 7 rows (budget, salary, price, cost, unit_price, discount, amount)



-- Q6. For each of these values pick the best PostgreSQL type and explain why
--     (write your answers as comments):
--       a) a customer's phone number "+91-98000 00001"
--       b) the number of items in stock
--       c) an invoice total in euros
--       d) the exact moment a payment was captured, users in 12 countries
--       e) an ISO country code like 'IN', 'US'
--       f) a page-view counter on a site with billions of views
--       g) a temperature sensor reading



-- Q7. Create a table "product_reviews" with sensible types for:
--     review_id (auto id), product_id (must reference products), rating (1–5),
--     review_text (long text, optional), is_verified (yes/no, default false),
--     created_at (moment in time, default now).
--     Insert two reviews for product 1, select them, then drop the table.
