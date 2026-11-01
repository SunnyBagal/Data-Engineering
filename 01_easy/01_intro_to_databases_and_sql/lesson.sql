-- =============================================================================
-- 01_easy/01 · Introduction to Databases & SQL — LESSON
-- Run inside:  psql -d sql_course   then   \i 01_easy/01_intro_to_databases_and_sql/lesson.sql
-- Or run statements one by one (recommended) to see each result.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Your very first query
-- -----------------------------------------------------------------------------

-- SELECT does not need a table: the database can act as a calculator.
-- Useful to quickly test functions/expressions before using them on real data.
SELECT 1 + 1 AS result;

-- What server am I talking to? Handy when debugging "works on my machine" issues.
SELECT version();

-- Which database and user am I connected as?
SELECT current_database(), current_user;


-- -----------------------------------------------------------------------------
-- 2. Reading a table
-- -----------------------------------------------------------------------------

-- '*' means "all columns". Great for exploring, BAD in application code:
--  * it pulls columns you don't need (more I/O, more network)
--  * code silently changes behaviour when someone adds/reorders columns
SELECT * FROM departments;

-- Naming columns explicitly is the professional habit: self-documenting & stable.
SELECT dept_id, dept_name, location
FROM departments;

-- SQL is free-form: whitespace and line breaks don't matter.
-- One clause per line is the convention because it's easier to read and diff.
select dept_name from departments;    -- lowercase keywords also work


-- -----------------------------------------------------------------------------
-- 3. Exploring the schema (metadata is just more tables!)
-- -----------------------------------------------------------------------------

-- information_schema is an ANSI-standard set of views describing the database.
-- Same query works on MySQL, SQL Server, Snowflake... unlike psql's \dt.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'        -- 'public' is Postgres' default schema (namespace)
ORDER BY table_name;

-- Describe a table: column names, types and nullability.
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'orders'
ORDER BY ordinal_position;           -- the order columns were defined in

-- Which foreign keys exist? (= the relationships between tables)
SELECT tc.table_name, kcu.column_name, ccu.table_name AS references_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;


-- -----------------------------------------------------------------------------
-- 4. One example of each SQL sub-language
-- -----------------------------------------------------------------------------

-- DDL: define structure. TEMP tables vanish when the session ends, perfect for
-- experiments because they can't pollute the shared database.
CREATE TEMP TABLE notes (
    note_id  INT PRIMARY KEY,
    body     TEXT NOT NULL
);

-- DML: change data.
INSERT INTO notes (note_id, body) VALUES (1, 'SQL is declarative');

-- DQL: read data.
SELECT * FROM notes;

-- TCL: group changes into a transaction. ROLLBACK undoes everything since BEGIN.
BEGIN;
    DELETE FROM notes;                  -- table is empty inside the transaction...
    SELECT COUNT(*) AS inside_tx FROM notes;
ROLLBACK;                               -- ...and the delete is undone
SELECT COUNT(*) AS after_rollback FROM notes;   -- back to 1 row

-- DCL: permissions (needs a role to exist, so shown as a comment; see 03_hard/11).
-- GRANT SELECT ON customers TO analyst;

DROP TABLE notes;                       -- DDL again: remove the experiment


-- -----------------------------------------------------------------------------
-- 5. Syntax rules that trip up beginners
-- -----------------------------------------------------------------------------

-- Single quotes = string literal.
SELECT 'India' AS a_string;

-- Double quotes = identifier (a column/table name). This makes a column named India:
SELECT 'x' AS "India";
-- SELECT "India";   -- ERROR: column "India" does not exist  (classic mistake)

-- An apostrophe inside a string is escaped by doubling it.
SELECT 'O''Reilly' AS publisher;

/* Multi-line comment:
   useful for temporarily disabling a block of SQL while debugging. */


-- -----------------------------------------------------------------------------
-- 6. Seeing relationships in action (preview of JOINs, 02_medium/01)
-- -----------------------------------------------------------------------------

-- orders.customer_id stores the customer's PK. Matching the two columns
-- reconnects the data that normalization split into separate tables.
SELECT o.order_id, o.order_date, c.first_name, c.last_name
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_id = 1;
