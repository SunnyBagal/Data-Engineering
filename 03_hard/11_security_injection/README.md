# 11 · Security: Roles, Privileges, Row-Level Security & SQL Injection

## 1. Roles and privileges (DCL)
In PostgreSQL, **users and groups are both "roles"**. A role with `LOGIN` can connect (a user);
roles can be members of other roles (groups) and inherit their privileges.

```sql
CREATE ROLE analyst NOLOGIN;                          -- a group
CREATE ROLE asha LOGIN PASSWORD '…' IN ROLE analyst;  -- a user in that group
GRANT USAGE ON SCHEMA public TO analyst;              -- may look inside the schema
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analyst;
REVOKE SELECT ON payments FROM analyst;
```

| Privilege | On | Allows |
|---|---|---|
| `CONNECT` | database | connecting |
| `USAGE` | schema | accessing objects in it (still needs table privileges) |
| `CREATE` | schema / database | creating objects |
| `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` | table (some per column) | the corresponding operations |
| `USAGE` / `SELECT` | sequence | `nextval` (needed for INSERT with serial ids) |
| `EXECUTE` | function | calling it (granted to PUBLIC by default!) |

- **Column-level**: `GRANT SELECT (customer_id, city, country) ON customers TO analyst;`
- **Future objects**: `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO analyst;`
- **Ownership**: the owner can do anything with an object, including granting. Keep application tables
  owned by a dedicated owner role, not by the app's login role.
- **Superusers bypass all checks** (and RLS). Never let applications connect as a superuser.

### Principle of least privilege
| Role | Typical grants |
|---|---|
| `app_rw` (the backend) | SELECT/INSERT/UPDATE/DELETE on its tables, USAGE on sequences — **no DDL** |
| `analyst_ro` | SELECT on reporting views/tables; no PII columns |
| `etl_loader` | INSERT/UPDATE on staging; SELECT on sources |
| `migrator` / owner | DDL; used only by the migration tool |

## 2. Row-Level Security (RLS)
Restrict **which rows** a role can see or modify — multi-tenant SaaS, "reps see only their customers".
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY rep_sees_own ON orders
    FOR SELECT TO sales_rep
    USING (employee_id = current_setting('app.emp_id')::int);   -- rows visible
-- WITH CHECK (…)  -> rows allowed to be inserted/updated
```
- With RLS enabled and **no policy**, non-owners see **nothing** (default deny).
- Table owners and superusers bypass RLS unless `ALTER TABLE … FORCE ROW LEVEL SECURITY`.
- The current user can come from `current_user`, or an app setting (`SET app.tenant_id = '42'`) that the
  application sets per request/transaction.

Alternatives: **views** (with `security_barrier`) exposing only allowed rows/columns.

## 3. SQL injection
Happens when **user input is concatenated into SQL text**:
```python
query = "SELECT * FROM users WHERE name = '" + name + "'"
# name = "x' OR '1'='1"  ->  WHERE name = 'x' OR '1'='1'   -> every row
# name = "x'; DROP TABLE users; --"                         -> catastrophe
```
**Defenses (in order of importance):**
1. **Parameterized queries / prepared statements** — values are sent separately from the SQL text and
   can never change its structure. Every driver supports them (`$1`, `?`, `%s` placeholders — *not* Python `%` formatting!).
2. In dynamic SQL inside the DB: `format('%I', ident)` for identifiers, `format('%L', value)` or `EXECUTE … USING` for values.
3. **Allow-lists** for things that can't be parameters (ORDER BY column, sort direction, table names).
4. **Least privilege**: the app role can't `DROP` anything anyway; read-only endpoints use a read-only role.
5. ORMs help, but raw-SQL escape hatches (`.raw()`, string-built `ORDER BY`) reintroduce the risk.

Escaping quotes by hand is **not** a defense (encoding tricks, numeric contexts, second-order injection).

## 4. Protecting sensitive data
| Concern | Tool |
|---|---|
| Passwords | never store plain text; store a slow salted hash (`pgcrypto` `crypt(pw, gen_salt('bf'))`), ideally hashed in the app (bcrypt/argon2) |
| PII exposure | column privileges, views, masking, separate schema |
| Data in transit | TLS (`sslmode=require`/`verify-full`) |
| Data at rest | disk/volume encryption; column encryption with `pgcrypto` for very sensitive fields |
| Who did what | `log_statement`, `pgaudit` extension, audit triggers (03_hard/09) |
| Privileged functions | `SECURITY DEFINER` + `SET search_path = pg_catalog, public` + `REVOKE EXECUTE … FROM PUBLIC` |

## Significance
Data breaches are overwhelmingly caused by injection, over-privileged accounts and leaked credentials.
Database-level controls are the last line of defence when application code has a bug.

## Common mistakes
- App connecting as `postgres`/superuser.
- `GRANT ALL ON ALL TABLES … TO PUBLIC`.
- Forgetting sequence privileges (INSERT fails with "permission denied for sequence").
- RLS tested as a superuser/owner (bypass) — "it works for me".
- `SECURITY DEFINER` functions without a fixed `search_path`.
- Building `ORDER BY` / `LIMIT` from raw user input.
