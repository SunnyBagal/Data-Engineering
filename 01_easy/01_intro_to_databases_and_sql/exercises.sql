-- =============================================================================
-- 01_easy/01 · Introduction to Databases & SQL — EXERCISES
-- -----------------------------------------------------------------------------
-- Database: sql_course (see 00_setup/README.md for all tables)
-- Write your query under each question, run it, compare with solutions.sql.
-- "Expected" hints let you self-check without peeking.
-- =============================================================================


-- Q1. Use SELECT as a calculator: show the result of (17 * 3) - 4 with the
--     column name  answer.
--     Expected: 47



-- Q2. Show every column and every row of the categories table.
--     Expected: 12 rows



-- Q3. Show only the first name, last name and job title of all employees.
--     Expected: 20 rows, 3 columns



-- Q4. Using information_schema, list all columns of the products table with
--     their data type, in the order they were defined.
--     Expected: 9 rows, first is product_id / integer



-- Q5. Using information_schema, count how many columns each of our tables has.
--     (Hint: GROUP BY is coming in topic 11; for now, list table_name and
--      column_name for the 'customers' and 'orders' tables and count by eye.)
--     Expected: customers has 9 columns, orders has 6



-- Q6. Without running it, predict: which of these statements fail and why?
--       a) SELECT 'Mumbai';
--       b) SELECT "Mumbai";
--       c) select dept_name FROM DEPARTMENTS;
--       d) SELECT 'It's here';
--     Then run them to check.



-- Q7. Classify each statement as DDL, DML, DQL, DCL or TCL:
--       CREATE INDEX ...;  UPDATE ...;  REVOKE ...;  SELECT ...;
--       COMMIT;  TRUNCATE ...;  INSERT ...;  ALTER TABLE ...;
--     Then: inside a transaction, insert a new department called 'Legal',
--     show that it exists, and roll back so the shared data is untouched.
