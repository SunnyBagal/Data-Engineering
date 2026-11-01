-- =============================================================================
-- 03_hard/11 · Security — SOLUTIONS
-- =============================================================================

-- Idempotent cleanup from earlier runs.
DROP SCHEMA IF EXISTS lab CASCADE;
DO $$
DECLARE r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['course_reporting','course_checkout','course_tenant_user'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END $$;
CREATE SCHEMA lab;
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- Q1.
CREATE ROLE course_reporting NOLOGIN;
GRANT USAGE  ON SCHEMA public TO course_reporting;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO course_reporting;
REVOKE SELECT ON payments, customers FROM course_reporting;
GRANT SELECT (customer_id, first_name, last_name, city, country, signup_date, referred_by)
      ON customers TO course_reporting;

SELECT has_table_privilege ('course_reporting', 'orders', 'SELECT')               AS orders,
       has_table_privilege ('course_reporting', 'payments', 'SELECT')             AS payments,
       has_column_privilege('course_reporting', 'customers', 'email', 'SELECT')   AS cust_email,
       has_column_privilege('course_reporting', 'customers', 'country', 'SELECT') AS cust_country;

SET ROLE course_reporting;
SELECT country, COUNT(*) FROM customers GROUP BY country ORDER BY 2 DESC;   -- OK
-- SELECT email FROM customers;   -- ERROR: permission denied for table customers
RESET ROLE;


-- Q2. Column-level UPDATE privilege limits WHICH columns can change.
CREATE ROLE course_checkout NOLOGIN;
GRANT USAGE ON SCHEMA public TO course_checkout;
GRANT SELECT ON products, customers TO course_checkout;
GRANT INSERT ON orders, order_items, payments TO course_checkout;
GRANT SELECT ON orders, order_items, payments TO course_checkout;   -- needed for RETURNING / reads
GRANT UPDATE (status) ON orders TO course_checkout;
GRANT USAGE ON SEQUENCE orders_order_id_seq, payments_payment_id_seq TO course_checkout;

SET ROLE course_checkout;
BEGIN;
INSERT INTO orders (customer_id, order_date, status) VALUES (20, now(), 'pending') RETURNING order_id;
UPDATE orders SET status = 'shipped' WHERE customer_id = 20 AND status = 'pending';   -- allowed
-- UPDATE orders SET customer_id = 1 WHERE customer_id = 20;
--   ERROR: permission denied for table orders
ROLLBACK;
RESET ROLE;


-- Q3. current_setting('app.tenant', true): the second argument returns NULL
--     instead of erroring when the setting is missing -> no rows (fail closed).
CREATE TABLE lab.tenant_notes (
    note_id SERIAL PRIMARY KEY,
    tenant  TEXT NOT NULL,
    body    TEXT NOT NULL
);
INSERT INTO lab.tenant_notes (tenant, body) VALUES
    ('acme', 'Renew contract'), ('acme', 'Invoice overdue'), ('globex', 'New project kickoff');

CREATE ROLE course_tenant_user NOLOGIN;
GRANT USAGE ON SCHEMA lab TO course_tenant_user;
GRANT SELECT, INSERT ON lab.tenant_notes TO course_tenant_user;
GRANT USAGE ON SEQUENCE lab.tenant_notes_note_id_seq TO course_tenant_user;

ALTER TABLE lab.tenant_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON lab.tenant_notes
    TO course_tenant_user
    USING      (tenant = current_setting('app.tenant', true))
    WITH CHECK (tenant = current_setting('app.tenant', true));

SET ROLE course_tenant_user;
SET app.tenant = 'acme';
SELECT COUNT(*) AS acme_notes FROM lab.tenant_notes;            -- 2
-- INSERT INTO lab.tenant_notes (tenant, body) VALUES ('globex', 'sneaky');
--   ERROR: new row violates row-level security policy for table "tenant_notes"
SET app.tenant = 'globex';
SELECT COUNT(*) AS globex_notes FROM lab.tenant_notes;          -- 1
RESET app.tenant;
RESET ROLE;
-- In an app, run "SET LOCAL app.tenant = $1" at the start of each transaction
-- (SET LOCAL resets automatically at COMMIT — safe with connection pools).


-- Q4 + Q5 share lab.accounts.
CREATE TABLE lab.accounts (username TEXT PRIMARY KEY, pw_hash TEXT NOT NULL);
INSERT INTO lab.accounts VALUES
    ('asha', crypt('correct horse', gen_salt('bf', 8))),
    ('ravi', crypt('battery staple', gen_salt('bf', 8)));

-- Q4. Vulnerable: compares a plain-text password and concatenates input.
--     (A plain-text table is used here ON PURPOSE to show the bypass.)
CREATE TABLE lab.accounts_plain (username TEXT PRIMARY KEY, password TEXT NOT NULL);
INSERT INTO lab.accounts_plain VALUES ('asha', 'correct horse');

CREATE FUNCTION lab.login_unsafe(p_user TEXT, p_pass TEXT) RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE v_n INT;
BEGIN
    EXECUTE 'SELECT COUNT(*) FROM lab.accounts_plain WHERE username = ''' || p_user ||
            ''' AND password = ''' || p_pass || '''' INTO v_n;
    RETURN v_n > 0;
END $$;

SELECT lab.login_unsafe('asha', 'wrong')            AS wrong_password,   -- f
       lab.login_unsafe('asha', ''' OR ''1''=''1')  AS injected;         -- t  <- bypass!
-- The SQL became: ... AND password = '' OR '1'='1'  (always true)

CREATE FUNCTION lab.login_safe(p_user TEXT, p_pass TEXT) RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE v_n INT;
BEGIN
    EXECUTE 'SELECT COUNT(*) FROM lab.accounts_plain WHERE username = $1 AND password = $2'
       INTO v_n USING p_user, p_pass;                                    -- parameters
    RETURN v_n > 0;
END $$;
SELECT lab.login_safe('asha', ''' OR ''1''=''1') AS injected_safe;       -- f


-- Q5. Static SQL in a SQL function is parameterized automatically.
CREATE FUNCTION lab.check_login(p_user TEXT, p_pass TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        (SELECT pw_hash = crypt(p_pass, pw_hash) FROM lab.accounts WHERE username = p_user),
        FALSE);                                                          -- unknown user -> false
$$;

SELECT lab.check_login('asha', 'correct horse') AS ok,          -- t
       lab.check_login('asha', 'Correct horse') AS wrong_case,  -- f
       lab.check_login('nobody', 'x')           AS no_user;     -- f


-- Q6.
CREATE FUNCTION lab.payment_summary()
RETURNS TABLE (method TEXT, payments BIGINT, total NUMERIC)
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT method::text, COUNT(*), SUM(amount) FROM public.payments GROUP BY method ORDER BY 3 DESC;
$$;
REVOKE EXECUTE ON FUNCTION lab.payment_summary() FROM PUBLIC;
GRANT  USAGE   ON SCHEMA lab TO course_reporting;
GRANT  EXECUTE ON FUNCTION lab.payment_summary() TO course_reporting;

SET ROLE course_reporting;
SELECT * FROM lab.payment_summary();                -- works: aggregated only
-- SELECT * FROM payments;                          -- ERROR: permission denied
RESET ROLE;


-- Q7.
SELECT grantee, table_name, privilege_type, NULL AS column_name
FROM information_schema.role_table_grants
WHERE grantee LIKE 'course_%'
UNION ALL
SELECT grantee, table_name, privilege_type, column_name
FROM information_schema.column_privileges
WHERE grantee LIKE 'course_%'
ORDER BY grantee, table_name, privilege_type, column_name;

DROP SCHEMA lab CASCADE;
DROP OWNED BY course_reporting, course_checkout, course_tenant_user;   -- removes grants in this DB
DROP ROLE course_reporting, course_checkout, course_tenant_user;
