-- =============================================================================
-- 01_easy/01 · Introduction to Databases & SQL — SOLUTIONS
-- =============================================================================


-- Q1. SELECT without FROM evaluates the expression once. Normal operator
--     precedence applies (* before -), parentheses only for readability.
SELECT (17 * 3) - 4 AS answer;          -- 47


-- Q2. SELECT * is fine for exploration.
SELECT * FROM categories;               -- 12 rows


-- Q3. Explicit column list: returns only what's needed, in the order we choose.
SELECT first_name, last_name, job_title
FROM employees;


-- Q4. information_schema.columns has one row per column of every table.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'products'
ORDER BY ordinal_position;              -- definition order


-- Q5. Filter to the two tables and sort so each table's columns are together.
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('customers', 'orders')
ORDER BY table_name, ordinal_position;

-- Preview of topic 11 — the "proper" way to count:
SELECT table_name, COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_name
ORDER BY table_name;


-- Q6.
--  a) works  -> returns the string 'Mumbai'
--  b) FAILS  -> double quotes mean an identifier: column "Mumbai" does not exist
--  c) works  -> keywords and unquoted identifiers are case-insensitive
--               (DEPARTMENTS is folded to departments)
--  d) FAILS  -> the apostrophe ends the string early; escape it by doubling:
SELECT 'It''s here' AS fixed;


-- Q7.
--  CREATE INDEX -> DDL      UPDATE   -> DML      REVOKE -> DCL
--  SELECT       -> DQL      COMMIT   -> TCL      TRUNCATE -> DDL (*)
--  INSERT       -> DML      ALTER TABLE -> DDL
--  (*) TRUNCATE removes all rows like DELETE, but it's classed as DDL because it
--      deallocates the table's storage instead of deleting row by row.

BEGIN;                                                  -- TCL: start transaction
INSERT INTO departments (dept_name, location, budget)   -- DML; dept_id auto-generated
VALUES ('Legal', 'Delhi', 150000);
SELECT * FROM departments WHERE dept_name = 'Legal';   -- visible inside our transaction
ROLLBACK;                                               -- TCL: undo -> Legal is gone
SELECT COUNT(*) AS departments_after FROM departments; -- still 6
