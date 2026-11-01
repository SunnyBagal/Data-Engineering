-- =============================================================================
-- 01_easy/03 · CREATE, ALTER, DROP — LESSON
-- Everything here happens inside a separate schema called "sandbox", which is
-- dropped at the end, so the shared practice tables are never touched.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Schemas: namespaces for tables
-- -----------------------------------------------------------------------------

-- IF NOT EXISTS makes the script idempotent: re-running it won't error.
CREATE SCHEMA IF NOT EXISTS sandbox;

-- search_path = the list of schemas searched for unqualified names.
-- Putting sandbox first means "CREATE TABLE suppliers" lands in sandbox,
-- while "products" (which only exists in public) is still found.
SET search_path TO sandbox, public;


-- -----------------------------------------------------------------------------
-- 2. CREATE TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- ALWAYS (vs BY DEFAULT) forbids manual ids -> prevents accidental clashes
    supplier_name VARCHAR(100) NOT NULL,
    country       VARCHAR(50),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()   -- DEFAULT fills it automatically
);

-- Document your schema inside the database itself; tools like DBeaver show it.
COMMENT ON TABLE  suppliers         IS 'Companies we buy products from';
COMMENT ON COLUMN suppliers.country IS 'Country of registration, free text for now';

INSERT INTO suppliers (supplier_name, country) VALUES
    ('Lumen Corp', 'Taiwan'),
    ('Cookmate Ltd', 'India'),
    ('Paperworks', 'USA');

SELECT * FROM suppliers;


-- -----------------------------------------------------------------------------
-- 3. ALTER TABLE — evolving a table that already has data
-- -----------------------------------------------------------------------------

-- 3a. Add a nullable column: instant, existing rows get NULL.
ALTER TABLE suppliers ADD COLUMN email VARCHAR(100);

-- 3b. Add a NOT NULL column WITH a default: existing rows get the default.
--     Without the DEFAULT this would fail, because existing rows would violate NOT NULL.
ALTER TABLE suppliers ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- 3c. Rename a column (cheap metadata change, but breaks queries using the old name).
ALTER TABLE suppliers RENAME COLUMN supplier_name TO name;

-- 3d. Change a type. USING tells Postgres HOW to convert existing values.
--     Here we turn free-text country into a 2-letter code.
ALTER TABLE suppliers
    ALTER COLUMN country TYPE CHAR(2)
    USING CASE country WHEN 'Taiwan' THEN 'TW'
                       WHEN 'India'  THEN 'IN'
                       WHEN 'USA'    THEN 'US' END;

-- 3e. Tighten rules once data is clean.
ALTER TABLE suppliers ALTER COLUMN country SET NOT NULL;

-- 3f. Add a named constraint (named = readable error messages & easy to drop later).
ALTER TABLE suppliers ADD CONSTRAINT uq_suppliers_name UNIQUE (name);

-- 3g. Change / remove a default.
ALTER TABLE suppliers ALTER COLUMN is_active SET DEFAULT FALSE;
ALTER TABLE suppliers ALTER COLUMN is_active DROP DEFAULT;

-- 3h. Drop a column (data in it is gone for good — no undo outside a transaction).
ALTER TABLE suppliers DROP COLUMN IF EXISTS email;

-- 3i. Rename the table.
ALTER TABLE suppliers RENAME TO vendors;

-- See the result of all our changes.
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'sandbox' AND table_name = 'vendors'
ORDER BY ordinal_position;


-- -----------------------------------------------------------------------------
-- 4. Generated (computed) columns
-- -----------------------------------------------------------------------------

-- STORED generated columns are computed on write and can't be set manually.
-- Better than computing margin in every query, and can't get out of sync.
CREATE TABLE price_list (
    sku     TEXT PRIMARY KEY,
    price   NUMERIC(10,2) NOT NULL,
    cost    NUMERIC(10,2) NOT NULL,
    margin  NUMERIC(10,2) GENERATED ALWAYS AS (price - cost) STORED
);
INSERT INTO price_list (sku, price, cost) VALUES ('A1', 100, 60);
SELECT * FROM price_list;                    -- margin = 40.00 automatically


-- -----------------------------------------------------------------------------
-- 5. CREATE TABLE AS (CTAS) and CREATE TABLE ... LIKE
-- -----------------------------------------------------------------------------

-- CTAS: snapshot a query result into a new table. Great for ETL staging and
-- "what did the data look like yesterday" backups.
CREATE TABLE india_customers AS
SELECT customer_id, first_name, last_name, city
FROM public.customers
WHERE country = 'India';

SELECT COUNT(*) FROM india_customers;        -- 8

-- Gotcha: CTAS copies columns & data but NOT the primary key, defaults or constraints.
SELECT COUNT(*) AS constraints_copied
FROM information_schema.table_constraints
WHERE table_schema = 'sandbox' AND table_name = 'india_customers'
  AND constraint_type = 'PRIMARY KEY';       -- 0

-- LIKE ... INCLUDING ALL copies the structure (defaults, constraints, indexes) without data.
CREATE TABLE customers_archive (LIKE public.customers INCLUDING ALL);
SELECT COUNT(*) FROM customers_archive;      -- 0 rows, same structure

-- WITH NO DATA: structure from a query, but empty.
CREATE TABLE empty_orders AS SELECT * FROM public.orders WITH NO DATA;


-- -----------------------------------------------------------------------------
-- 6. TRUNCATE vs DELETE vs DROP
-- -----------------------------------------------------------------------------

-- TRUNCATE: removes every row instantly. RESTART IDENTITY resets the id counter.
TRUNCATE TABLE vendors RESTART IDENTITY;
INSERT INTO vendors (name, country, is_active) VALUES ('New Co', 'DE', TRUE);
SELECT supplier_id, name FROM vendors;       -- supplier_id = 1 again

-- Transactional DDL (Postgres): even DROP can be undone inside a transaction.
BEGIN;
    DROP TABLE vendors;
    -- SELECT * FROM vendors;   -- would ERROR here: relation does not exist
ROLLBACK;
SELECT COUNT(*) AS vendors_still_there FROM vendors;   -- 1  (MySQL could NOT undo this)


-- -----------------------------------------------------------------------------
-- 7. DROP with dependencies: RESTRICT (default) vs CASCADE
-- -----------------------------------------------------------------------------

CREATE VIEW active_vendors AS SELECT * FROM vendors WHERE is_active;

-- DROP TABLE vendors;             -- ERROR: view active_vendors depends on table vendors
-- That error is a safety net. CASCADE removes the view too — use deliberately.
DROP TABLE vendors CASCADE;

-- IF EXISTS: no error if it's already gone (idempotent cleanup).
DROP TABLE IF EXISTS vendors;


-- -----------------------------------------------------------------------------
-- 8. Clean up: dropping the schema with CASCADE removes everything inside it.
-- -----------------------------------------------------------------------------
RESET search_path;
DROP SCHEMA sandbox CASCADE;
