-- =============================================================================
-- 01_easy/03 · CREATE, ALTER, DROP — EXERCISES
-- Uses: DDL + data types (02) + information_schema & transactions (01)
-- Do everything inside a schema called "lab" and drop it at the end.
-- =============================================================================


-- Q1. Create the schema "lab" (idempotently) and a table lab.warehouses with:
--       warehouse_id  auto-generated primary key
--       code          exactly 3 characters, required, unique   (e.g. 'BLR')
--       city          up to 50 characters, required
--       capacity_m3   whole number, optional
--       opened_on     date, optional
--     Insert three warehouses: BLR/Bengaluru/5000/2021-04-01,
--     DEL/Delhi/3200/2022-09-15, BOM/Mumbai/NULL/NULL.



-- Q2. The business now wants to know whether each warehouse is refrigerated.
--     Add a column is_cold_storage that is required and defaults to false.
--     Show the table: all three existing rows should have false.



-- Q3. capacity_m3 needs decimals (e.g. 5000.5). Change its type to NUMERIC(10,1).
--     Then rename it to capacity. Verify with information_schema.columns.



-- Q4. Create lab.stock_snapshot as a copy (CTAS) of product_id, product_name,
--     stock_qty for all products that are OUT of stock (stock_qty = 0).
--     How many rows does it have? Does it have a primary key? Add one.
--     Expected: 5 rows; no PK until you add it



-- Q5. Create lab.orders_template with the same structure as public.orders,
--     including defaults and constraints, but no rows. Prove it has 0 rows
--     and that it has a CHECK constraint on status (insert a bad status and
--     watch it fail — then comment that line out).



-- Q6. Inside a transaction: TRUNCATE lab.warehouses, show the count (0),
--     then ROLLBACK and show the count again (3). Write one sentence on why
--     this would behave differently in MySQL.



-- Q7. Clean up: drop the "lab" schema and everything in it with one statement.
--     Then confirm with information_schema.schemata that it no longer exists.
