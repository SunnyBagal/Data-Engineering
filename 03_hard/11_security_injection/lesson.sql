-- =============================================================================
-- 03_hard/11 · Security: Roles, Privileges, RLS & SQL Injection — LESSON
-- Run as a superuser / database owner (the default on a local install).
-- Roles are SERVER-wide, so all demo roles are prefixed "course_" and removed
-- at the end. SET ROLE lets us test as another role without reconnecting.
-- =============================================================================

-- Idempotent cleanup in case a previous run stopped half-way.
DROP SCHEMA IF EXISTS secure CASCADE;
DO $$
DECLARE r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['course_kavya','course_james','course_sales_rep',
                             'course_analyst','course_app'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);   -- revoke its grants in this DB
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END $$;


-- -----------------------------------------------------------------------------
-- 1. Roles: groups and users
-- -----------------------------------------------------------------------------

CREATE ROLE course_analyst NOLOGIN;            -- group role: holds privileges
CREATE ROLE course_app     NOLOGIN;            -- (LOGIN PASSWORD '…' for real users)

SELECT rolname, rolcanlogin, rolsuper FROM pg_roles WHERE rolname LIKE 'course_%';


-- -----------------------------------------------------------------------------
-- 2. GRANT / REVOKE: least privilege
-- -----------------------------------------------------------------------------

-- Analyst: read-only on everything in public...
GRANT USAGE  ON SCHEMA public TO course_analyst;            -- needed to "see into" the schema
GRANT SELECT ON ALL TABLES IN SCHEMA public TO course_analyst;
-- ...except payments and the sensitive customer columns.
REVOKE SELECT ON payments  FROM course_analyst;
REVOKE SELECT ON customers FROM course_analyst;
GRANT  SELECT (customer_id, first_name, city, country, signup_date) ON customers TO course_analyst;

-- App: read catalog, write orders. Sequences are needed for identity inserts.
GRANT USAGE ON SCHEMA public TO course_app;
GRANT SELECT ON products, categories, customers TO course_app;
GRANT SELECT, INSERT, UPDATE ON orders, order_items, payments TO course_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO course_app;
-- No DELETE, no DDL: a compromised app can't wipe or alter tables.

-- Check privileges without switching roles.
SELECT has_table_privilege('course_analyst', 'orders',   'SELECT') AS analyst_reads_orders,     -- t
       has_table_privilege('course_analyst', 'payments', 'SELECT') AS analyst_reads_payments,   -- f
       has_column_privilege('course_analyst', 'customers', 'email', 'SELECT') AS analyst_reads_email, -- f
       has_table_privilege('course_app', 'orders', 'DELETE')       AS app_deletes_orders;       -- f

-- Test for real by becoming the role.
SET ROLE course_analyst;
SELECT current_user;
SELECT country, COUNT(*) FROM customers GROUP BY country;    -- allowed columns: OK
-- SELECT email FROM customers;     -- ERROR: permission denied for table customers
-- SELECT * FROM payments;          -- ERROR: permission denied for table payments
-- SELECT * FROM customers;         -- ERROR: * includes email/phone
RESET ROLE;                                                   -- back to ourselves


-- -----------------------------------------------------------------------------
-- 3. Row-Level Security: each sales rep sees only their own orders
-- -----------------------------------------------------------------------------

-- RLS is easier to demo on a copy owned by us (superusers/owners bypass it).
CREATE SCHEMA secure;
CREATE TABLE secure.rep_orders AS
SELECT o.order_id, o.employee_id, o.customer_id, o.status, o.order_date
FROM orders o WHERE o.employee_id IS NOT NULL;

-- Which login role belongs to which employee?
CREATE TABLE secure.rep_logins (role_name TEXT PRIMARY KEY, emp_id INT NOT NULL);
INSERT INTO secure.rep_logins VALUES ('course_kavya', 11), ('course_james', 12);

CREATE ROLE course_sales_rep NOLOGIN;
CREATE ROLE course_kavya NOLOGIN IN ROLE course_sales_rep;   -- members inherit privileges
CREATE ROLE course_james NOLOGIN IN ROLE course_sales_rep;
GRANT USAGE ON SCHEMA secure TO course_sales_rep;
GRANT SELECT, UPDATE ON secure.rep_orders TO course_sales_rep;
GRANT SELECT ON secure.rep_logins TO course_sales_rep;

ALTER TABLE secure.rep_orders ENABLE ROW LEVEL SECURITY;

-- USING: which existing rows are visible / updatable.
-- WITH CHECK: what a row may look like after INSERT/UPDATE (can't reassign
-- your order to another rep).
CREATE POLICY rep_own_orders ON secure.rep_orders
    FOR ALL
    TO course_sales_rep
    USING      (employee_id = (SELECT emp_id FROM secure.rep_logins WHERE role_name = current_user))
    WITH CHECK (employee_id = (SELECT emp_id FROM secure.rep_logins WHERE role_name = current_user));

SET ROLE course_kavya;
SELECT COUNT(*) AS kavya_sees FROM secure.rep_orders;          -- 12 (only her orders)
-- UPDATE secure.rep_orders SET employee_id = 12 WHERE order_id = 1;
--   ERROR: new row violates row-level security policy for table "rep_orders"
UPDATE secure.rep_orders SET status = status WHERE employee_id = 12;   -- UPDATE 0: James' rows are invisible
RESET ROLE;

SET ROLE course_james;
SELECT COUNT(*) AS james_sees FROM secure.rep_orders;          -- 10
RESET ROLE;

SELECT COUNT(*) AS owner_sees FROM secure.rep_orders;          -- 31: we are the owner (bypass)


-- -----------------------------------------------------------------------------
-- 4. SQL injection: how it happens inside the database too
-- -----------------------------------------------------------------------------

-- VULNERABLE: user input concatenated into the SQL text.
CREATE FUNCTION secure.find_customer_unsafe(p_last_name TEXT)
RETURNS SETOF customers LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT * FROM public.customers WHERE last_name = ''' || p_last_name || '''';
END $$;

SELECT customer_id, last_name FROM secure.find_customer_unsafe('Shah');             -- 1 row: fine
-- Attacker input closes the quote and adds an always-true condition:
SELECT customer_id, last_name FROM secure.find_customer_unsafe('x'' OR ''1''=''1');  -- ALL 20 rows!
-- (With other inputs an attacker could UNION in data from other tables, e.g.
--  "x' UNION SELECT … FROM employees --", or call functions.)

-- SAFE: the value is passed as a PARAMETER ($1), never parsed as SQL.
CREATE FUNCTION secure.find_customer_safe(p_last_name TEXT)
RETURNS SETOF customers LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT * FROM public.customers WHERE last_name = $1' USING p_last_name;
END $$;

SELECT customer_id, last_name FROM secure.find_customer_safe('x'' OR ''1''=''1');   -- 0 rows

-- Also safe: format() with %L (quotes a literal) / %I (quotes an identifier).
SELECT format('SELECT * FROM %I WHERE last_name = %L', 'customers', 'x'' OR ''1''=''1') AS safe_sql;

-- Prepared statements: the same mechanism every application driver uses.
PREPARE find_by_country(TEXT) AS
    SELECT first_name, last_name FROM customers WHERE country = $1;
EXECUTE find_by_country('Germany');
EXECUTE find_by_country('Germany'' OR ''1''=''1');       -- 0 rows: just a strange country name
DEALLOCATE find_by_country;

-- Identifiers (table/column names, sort direction) can't be parameters: use an ALLOW-LIST.
CREATE FUNCTION secure.customers_sorted(p_sort_col TEXT)
RETURNS SETOF customers LANGUAGE plpgsql AS $$
BEGIN
    IF p_sort_col NOT IN ('last_name', 'signup_date', 'country') THEN
        RAISE EXCEPTION 'invalid sort column: %', p_sort_col;
    END IF;
    RETURN QUERY EXECUTE format('SELECT * FROM public.customers ORDER BY %I LIMIT 3', p_sort_col);
END $$;
SELECT customer_id, last_name FROM secure.customers_sorted('last_name');
-- SELECT * FROM secure.customers_sorted('1; DROP TABLE customers');   -- ERROR: invalid sort column


-- -----------------------------------------------------------------------------
-- 5. SECURITY DEFINER: a controlled window into restricted data
-- -----------------------------------------------------------------------------

-- Analysts can't read salaries, but may see AVERAGE salary per department.
-- The function runs with its OWNER's rights. SET search_path prevents an
-- attacker from shadowing objects with their own schema.
CREATE FUNCTION secure.avg_salary_by_dept()
RETURNS TABLE (dept_name TEXT, avg_salary NUMERIC)
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT d.dept_name::text, ROUND(AVG(e.salary), -3)        -- rounded to thousands
    FROM public.employees e JOIN public.departments d ON d.dept_id = e.dept_id
    GROUP BY d.dept_name
    HAVING COUNT(*) >= 2;                                      -- no groups small enough to identify a person
$$;
REVOKE EXECUTE ON FUNCTION secure.avg_salary_by_dept() FROM PUBLIC;   -- functions default to PUBLIC!
GRANT  USAGE   ON SCHEMA secure TO course_analyst;
GRANT  EXECUTE ON FUNCTION secure.avg_salary_by_dept() TO course_analyst;
REVOKE SELECT  ON employees FROM course_analyst;

SET ROLE course_analyst;
SELECT * FROM secure.avg_salary_by_dept();                    -- works
-- SELECT salary FROM employees;                              -- ERROR: permission denied
RESET ROLE;


-- -----------------------------------------------------------------------------
-- 6. Storing passwords: hash, never plain text (pgcrypto)
-- -----------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE secure.app_users (username TEXT PRIMARY KEY, pw_hash TEXT NOT NULL);

-- bcrypt ('bf') with a random salt: the same password hashes differently each time.
INSERT INTO secure.app_users VALUES ('asha', crypt('S3cret!pass', gen_salt('bf', 8)));
SELECT username, pw_hash FROM secure.app_users;               -- $2a$08$... (no plain text)

-- Verify: hash the attempt with the stored salt and compare.
SELECT username, pw_hash = crypt('S3cret!pass', pw_hash) AS correct_password,
                 pw_hash = crypt('guess123',    pw_hash) AS wrong_password
FROM secure.app_users;


-- -----------------------------------------------------------------------------
-- 7. Auditing privileges
-- -----------------------------------------------------------------------------

SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee LIKE 'course_%'
ORDER BY grantee, table_schema, table_name, privilege_type;


-- -----------------------------------------------------------------------------
-- Clean up: drop objects, then the roles (DROP OWNED removes their grants here)
-- -----------------------------------------------------------------------------
DROP SCHEMA secure CASCADE;
DROP OWNED BY course_kavya, course_james, course_sales_rep, course_analyst, course_app;
DROP ROLE course_kavya, course_james, course_sales_rep, course_analyst, course_app;
