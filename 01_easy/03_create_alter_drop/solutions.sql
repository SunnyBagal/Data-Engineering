-- =============================================================================
-- 01_easy/03 · CREATE, ALTER, DROP — SOLUTIONS
-- =============================================================================


-- Q1.
CREATE SCHEMA IF NOT EXISTS lab;

CREATE TABLE lab.warehouses (                         -- schema-qualified: no search_path needed
    warehouse_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code         CHAR(3)     NOT NULL UNIQUE,         -- fixed-length code -> CHAR(3)
    city         VARCHAR(50) NOT NULL,
    capacity_m3  INT,                                 -- optional -> nullable
    opened_on    DATE
);

INSERT INTO lab.warehouses (code, city, capacity_m3, opened_on) VALUES
    ('BLR', 'Bengaluru', 5000, '2021-04-01'),
    ('DEL', 'Delhi',     3200, '2022-09-15'),
    ('BOM', 'Mumbai',    NULL, NULL);


-- Q2. NOT NULL + DEFAULT together: the default back-fills existing rows,
--     so the NOT NULL rule is satisfied immediately.
ALTER TABLE lab.warehouses
    ADD COLUMN is_cold_storage BOOLEAN NOT NULL DEFAULT FALSE;

SELECT * FROM lab.warehouses;


-- Q3. INT -> NUMERIC is a safe widening conversion, so no USING clause is needed.
ALTER TABLE lab.warehouses ALTER COLUMN capacity_m3 TYPE NUMERIC(10,1);
ALTER TABLE lab.warehouses RENAME COLUMN capacity_m3 TO capacity;

SELECT column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_schema = 'lab' AND table_name = 'warehouses'
ORDER BY ordinal_position;


-- Q4. CTAS copies data + column types, but NOT constraints.
CREATE TABLE lab.stock_snapshot AS
SELECT product_id, product_name, stock_qty
FROM public.products
WHERE stock_qty = 0;

SELECT COUNT(*) FROM lab.stock_snapshot;                  -- 5

SELECT constraint_type FROM information_schema.table_constraints
WHERE table_schema = 'lab' AND table_name = 'stock_snapshot';  -- nothing (only NOT NULL checks, if any)

ALTER TABLE lab.stock_snapshot ADD PRIMARY KEY (product_id);


-- Q5. LIKE … INCLUDING ALL copies defaults, CHECKs, NOT NULLs, indexes, identity.
--     (Foreign keys are never copied by LIKE.)
CREATE TABLE lab.orders_template (LIKE public.orders INCLUDING ALL);

SELECT COUNT(*) FROM lab.orders_template;                 -- 0

-- INSERT INTO lab.orders_template (customer_id, order_date, status)
-- VALUES (1, now(), 'lost');   -- ERROR: violates check constraint "orders_status_check"


-- Q6.
BEGIN;
    TRUNCATE lab.warehouses;
    SELECT COUNT(*) AS during_tx FROM lab.warehouses;     -- 0
ROLLBACK;
SELECT COUNT(*) AS after_rollback FROM lab.warehouses;    -- 3
-- MySQL: TRUNCATE (like all DDL) causes an implicit COMMIT, so the rows would
-- be gone permanently and ROLLBACK would do nothing.


-- Q7.
DROP SCHEMA lab CASCADE;                                  -- CASCADE: drop all contained objects

SELECT COUNT(*) AS lab_exists
FROM information_schema.schemata
WHERE schema_name = 'lab';                                -- 0
