-- =============================================================================
-- 03_hard/11 · Security — EXERCISES
-- Uses: roles/GRANT/RLS + functions & dynamic SQL (08) + views (medium/07)
--       + transactions (medium/10)
-- Use role names starting with "course_" and a schema "lab"; clean up at the end.
-- =============================================================================


-- Q1. Create a group role course_reporting (no login) that can read every
--     table in public EXCEPT payments, and can read customers WITHOUT email
--     and phone. Verify with has_table_privilege / has_column_privilege and
--     by SET ROLE.
--     Expected: orders t, payments f, customers.email f, customers.country t



-- Q2. Create course_checkout (no login) for the web shop backend: it may read
--     products and customers, insert orders/order_items/payments (including
--     the identity sequences), update orders.status only (column-level
--     UPDATE), and nothing else. As that role, inside a transaction, insert an
--     order and try to UPDATE orders.customer_id (should fail). ROLLBACK.



-- Q3. Multi-tenant RLS: create lab.tenant_notes(note_id, tenant TEXT, body)
--     with notes for tenants 'acme' and 'globex'. Make every query by role
--     course_tenant_user see ONLY rows of the tenant stored in the session
--     setting app.tenant (SET app.tenant = 'acme'). Inserting a row for another
--     tenant must fail.
--     Expected: acme sees 2 notes, globex sees 1



-- Q4. Write an intentionally vulnerable function lab.login_unsafe(user, pass)
--     that builds SQL by concatenation against a lab.accounts table, show a
--     login bypass with the password  ' OR '1'='1 , then write the safe
--     version with EXECUTE … USING (or plain SQL with parameters).



-- Q5. Store passwords properly: lab.accounts(username, pw_hash) using pgcrypto
--     bcrypt. Write lab.check_login(username, password) RETURNS boolean.
--     Expected: correct password -> true, wrong -> false, unknown user -> false



-- Q6. Give course_reporting a SECURITY DEFINER function that returns the
--     number of payments and total amount per method (but not individual
--     payments). Make it safe (search_path, REVOKE from PUBLIC). Prove the
--     role can call it but can't SELECT from payments.



-- Q7. List every privilege held by course_* roles (tables + columns), then
--     remove everything: REVOKE/DROP OWNED, DROP ROLE, DROP SCHEMA lab.
