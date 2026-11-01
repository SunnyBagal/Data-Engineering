-- =============================================================================
-- 02_medium/11 · Normalization & Design — LESSON
-- We build a flat, spreadsheet-like table, see its anomalies, then normalize it.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;


-- -----------------------------------------------------------------------------
-- 1. The un-normalized "spreadsheet"
-- -----------------------------------------------------------------------------

-- One row per order line, with every related fact copied into it.
CREATE TABLE sales_flat AS
SELECT o.order_id,
       o.order_date::date      AS order_date,
       c.email                 AS customer_email,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.city                  AS customer_city,
       p.product_name,
       cat.category_name,
       oi.unit_price,
       oi.quantity
FROM public.order_items oi
JOIN public.orders o       ON o.order_id = oi.order_id
JOIN public.customers c    ON c.customer_id = o.customer_id
JOIN public.products p     ON p.product_id = oi.product_id
JOIN public.categories cat ON cat.category_id = p.category_id;

SELECT * FROM sales_flat ORDER BY order_id LIMIT 6;

-- Redundancy: Aarav's name/city is stored once PER ORDER LINE.
SELECT customer_email, COUNT(*) AS copies_of_customer_data
FROM sales_flat
GROUP BY customer_email
ORDER BY copies_of_customer_data DESC
LIMIT 3;


-- -----------------------------------------------------------------------------
-- 2. The anomalies in action
-- -----------------------------------------------------------------------------

-- UPDATE ANOMALY: Aarav moves to Pune, but the update only hits some rows
-- (e.g. an app that updated just the latest order). The data now contradicts itself.
UPDATE sales_flat SET customer_city = 'Pune'
WHERE customer_email = 'aarav.shah@mail.com' AND order_id = 43;

SELECT customer_email, COUNT(DISTINCT customer_city) AS different_cities
FROM sales_flat
GROUP BY customer_email
HAVING COUNT(DISTINCT customer_city) > 1;          -- Aarav "lives" in 2 cities

-- DELETE ANOMALY: removing order 27 (Liam's only order) erases the fact that
-- Liam is a customer at all.
DELETE FROM sales_flat WHERE order_id = 27;
SELECT COUNT(*) AS liam_rows FROM sales_flat WHERE customer_name = 'Liam Taylor';   -- 0

-- INSERT ANOMALY: a brand-new product can't be recorded without an order:
-- INSERT INTO sales_flat (product_name, category_name) VALUES ('New Tablet', 'Computers');
-- -> works only by inventing NULL order data — the row isn't a "sale" at all.


-- -----------------------------------------------------------------------------
-- 3. 1NF: one value per cell
-- -----------------------------------------------------------------------------

-- Violation: tags packed into one text column.
CREATE TABLE product_tags_csv AS
SELECT product_id, product_name,
       array_to_string(ARRAY(SELECT jsonb_array_elements_text(attributes -> 'tags')), ',') AS tags
FROM public.products
WHERE attributes ? 'tags';                         -- ? = "JSON key exists"

SELECT * FROM product_tags_csv;

-- Questions like "which products are tagged 'premium'?" need fragile string
-- matching ('%premium%' would also match 'premium-plus').
SELECT product_name FROM product_tags_csv WHERE tags LIKE '%premium%';

-- 1NF fix: one row per (product, tag). string_to_table splits text into rows
-- (PG14+; on older versions use unnest(string_to_array(tags, ','))).
CREATE TABLE product_tags (
    product_id INT  NOT NULL,
    tag        TEXT NOT NULL,
    PRIMARY KEY (product_id, tag)                  -- no duplicate tag per product
);
INSERT INTO product_tags (product_id, tag)
SELECT product_id, unnest(string_to_array(tags, ','))
FROM product_tags_csv;

SELECT p.product_name
FROM product_tags t
JOIN public.products p ON p.product_id = t.product_id
WHERE t.tag = 'premium';                           -- exact, indexable, validatable

SELECT tag, COUNT(*) AS products FROM product_tags GROUP BY tag ORDER BY products DESC;


-- -----------------------------------------------------------------------------
-- 4. Normalizing sales_flat to 3NF
-- -----------------------------------------------------------------------------

-- Rebuild a clean copy of the flat table (the anomalies above damaged it).
DROP TABLE sales_flat;
CREATE TABLE sales_flat AS
SELECT o.order_id, o.order_date::date AS order_date,
       c.email AS customer_email, c.first_name || ' ' || c.last_name AS customer_name,
       c.city AS customer_city, p.product_name, cat.category_name,
       oi.unit_price, oi.quantity
FROM public.order_items oi
JOIN public.orders o       ON o.order_id = oi.order_id
JOIN public.customers c    ON c.customer_id = o.customer_id
JOIN public.products p     ON p.product_id = oi.product_id
JOIN public.categories cat ON cat.category_id = p.category_id;

-- Functional dependencies we found:
--   customer_email -> customer_name, customer_city      (customer facts)
--   product_name   -> category_name                     (product facts)
--   category_name  -> (nothing else)                    (category facts)
--   order_id       -> order_date, customer_email        (order facts)
--   (order_id, product_name) -> unit_price, quantity    (line facts)
-- Each determinant becomes the key of its own table.

CREATE TABLE n_categories (
    category_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- surrogate key
    category_name TEXT NOT NULL UNIQUE                            -- natural key stays unique
);
CREATE TABLE n_customers (
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    city        TEXT
);
CREATE TABLE n_products (
    product_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name TEXT NOT NULL UNIQUE,
    category_id  INT  NOT NULL REFERENCES n_categories
);
CREATE TABLE n_orders (
    order_id    INT PRIMARY KEY,                                   -- keep the business id
    order_date  DATE NOT NULL,
    customer_id INT  NOT NULL REFERENCES n_customers
);
CREATE TABLE n_order_lines (
    order_id   INT NOT NULL REFERENCES n_orders,
    product_id INT NOT NULL REFERENCES n_products,
    unit_price NUMERIC(10,2) NOT NULL,
    quantity   INT NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

-- Load each table with the DISTINCT facts from the flat table (parents first).
INSERT INTO n_categories (category_name)
SELECT DISTINCT category_name FROM sales_flat;

INSERT INTO n_customers (email, name, city)
SELECT DISTINCT customer_email, customer_name, customer_city FROM sales_flat;

INSERT INTO n_products (product_name, category_id)
SELECT DISTINCT f.product_name, c.category_id
FROM sales_flat f JOIN n_categories c ON c.category_name = f.category_name;

INSERT INTO n_orders (order_id, order_date, customer_id)
SELECT DISTINCT f.order_id, f.order_date, c.customer_id
FROM sales_flat f JOIN n_customers c ON c.email = f.customer_email;

INSERT INTO n_order_lines (order_id, product_id, unit_price, quantity)
SELECT f.order_id, p.product_id, f.unit_price, f.quantity
FROM sales_flat f JOIN n_products p ON p.product_name = f.product_name;

-- Each fact now lives once: 18 customers instead of 78 copies.
SELECT (SELECT COUNT(*) FROM n_customers) AS customers,
       (SELECT COUNT(*) FROM n_products)  AS products,
       (SELECT COUNT(*) FROM n_orders)    AS orders,
       (SELECT COUNT(*) FROM n_order_lines) AS lines;

-- The update anomaly is gone: a move is ONE row change.
UPDATE n_customers SET city = 'Pune' WHERE email = 'aarav.shah@mail.com';


-- -----------------------------------------------------------------------------
-- 5. Lossless decomposition: joining back reproduces the original
-- -----------------------------------------------------------------------------

UPDATE n_customers SET city = 'Mumbai' WHERE email = 'aarav.shah@mail.com';   -- undo the move

-- If both EXCEPTs return 0 rows, no information was lost or invented.
WITH rebuilt AS (
    SELECT o.order_id, o.order_date, c.email AS customer_email, c.name AS customer_name,
           c.city AS customer_city, p.product_name, cat.category_name, l.unit_price, l.quantity
    FROM n_order_lines l
    JOIN n_orders o       ON o.order_id = l.order_id
    JOIN n_customers c    ON c.customer_id = o.customer_id
    JOIN n_products p     ON p.product_id = l.product_id
    JOIN n_categories cat ON cat.category_id = p.category_id
)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM sales_flat EXCEPT SELECT * FROM rebuilt) a) AS missing,
       (SELECT COUNT(*) FROM (SELECT * FROM rebuilt EXCEPT SELECT * FROM sales_flat) b) AS extra;


-- -----------------------------------------------------------------------------
-- 6. 3NF violation in a familiar shape: transitive dependency
-- -----------------------------------------------------------------------------

-- emp_id -> dept_id -> dept_name : dept_name depends on a NON-key column.
CREATE TABLE emp_bad AS
SELECT e.emp_id, e.first_name, e.dept_id, d.dept_name, d.location
FROM public.employees e LEFT JOIN public.departments d ON d.dept_id = e.dept_id;

-- Renaming a department means updating every employee row of that department:
SELECT dept_name, COUNT(*) AS rows_to_update FROM emp_bad GROUP BY dept_name ORDER BY 2 DESC;
-- Our real schema stores dept_name once in departments -> one-row update.


-- -----------------------------------------------------------------------------
-- 7. Deliberate denormalization: a star schema for analytics
-- -----------------------------------------------------------------------------

-- Dimension: one row per calendar day with handy attributes precomputed.
CREATE TABLE dim_date AS
SELECT d::date                         AS date_key,
       EXTRACT(YEAR FROM d)::int       AS year,
       EXTRACT(QUARTER FROM d)::int    AS quarter,
       EXTRACT(MONTH FROM d)::int      AS month,
       TO_CHAR(d, 'Mon')               AS month_name,
       EXTRACT(ISODOW FROM d) IN (6,7) AS is_weekend
FROM generate_series(DATE '2023-01-01', DATE '2025-12-31', INTERVAL '1 day') d;

-- Fact: one row per sale line, with keys to dimensions + numeric measures.
CREATE TABLE fact_sales AS
SELECT o.order_date::date                                AS date_key,
       oi.product_id,
       o.customer_id,
       oi.quantity,
       oi.quantity * oi.unit_price * (1 - oi.discount)   AS revenue
FROM public.order_items oi
JOIN public.orders o ON o.order_id = oi.order_id
WHERE o.status <> 'cancelled';

-- Typical BI query: simple joins from the fact to the dimensions.
SELECT d.year, d.quarter, ROUND(SUM(f.revenue), 2) AS revenue
FROM fact_sales f
JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

SELECT d.is_weekend, COUNT(*) AS lines, ROUND(SUM(f.revenue), 2) AS revenue
FROM fact_sales f JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.is_weekend;


-- -----------------------------------------------------------------------------
-- Clean up
-- -----------------------------------------------------------------------------
RESET search_path;
DROP SCHEMA sandbox CASCADE;
