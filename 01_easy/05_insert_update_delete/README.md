# 05 · INSERT, UPDATE, DELETE (DML)

## What it is
**DML — Data Manipulation Language** — changes the *rows* inside tables.

| Statement | Does | Basic form |
|---|---|---|
| `INSERT` | adds new rows | `INSERT INTO t (cols) VALUES (…), (…);` |
| `UPDATE` | changes values in existing rows | `UPDATE t SET col = expr WHERE …;` |
| `DELETE` | removes rows | `DELETE FROM t WHERE …;` |

Advanced forms (UPSERT, `INSERT … SELECT`, `UPDATE … FROM`, `MERGE`) are in **02_medium/08**.

## How it works
### INSERT
```sql
INSERT INTO customers (first_name, last_name, email, country, signup_date)
VALUES ('Asha', 'Rao', 'asha@mail.com', 'India', CURRENT_DATE);
```
- **Always list the columns.** `INSERT INTO t VALUES (…)` depends on column order and breaks when a column is added.
- Omitted columns get their `DEFAULT` (or NULL). Identity columns generate the next id.
- **Multi-row VALUES** is one statement → one round trip → much faster than N single inserts.
- `RETURNING` (Postgres, SQLite; `OUTPUT` in SQL Server) gives back generated ids without a second query.

### UPDATE
```sql
UPDATE products
SET    price = price * 1.10,         -- expressions can reference current values
       stock_qty = stock_qty - 1
WHERE  product_id = 5;
```
- All `SET` expressions see the **old** row values (so `SET a = b, b = a` swaps them).
- **No WHERE = every row is updated.** This is the #1 production accident.

### DELETE
```sql
DELETE FROM payments WHERE paid_at < '2023-01-01';
```
- **No WHERE = every row is deleted.**
- Blocked by foreign keys unless the FK has `ON DELETE CASCADE / SET NULL`.

## Safe-change workflow (use it every time on real data)
1. Write the `WHERE` as a **`SELECT`** first → check the rows and the count.
2. `BEGIN;`
3. Run the `UPDATE`/`DELETE` → check the reported row count (`UPDATE 3`) matches step 1.
4. Verify with a `SELECT`.
5. `COMMIT;` if right, `ROLLBACK;` if not.

Many teams also enable "safe update mode" in tools (MySQL Workbench refuses UPDATE/DELETE without a key in WHERE).

## Significance
- Every application feature that writes data — sign-up, checkout, cancel order — is DML.
- ETL pipelines are mostly bulk DML.
- Getting it wrong is costly: there is no "undo" after `COMMIT` except restoring a backup.

## Use cases
| Need | Pattern |
|---|---|
| Sign-up | `INSERT … RETURNING id` |
| Price increase for a category | `UPDATE … SET price = price * 1.05 WHERE category_id = …` |
| Soft delete | `UPDATE … SET is_active = FALSE` (keeps history) instead of `DELETE` |
| GDPR erasure | `UPDATE` personal columns to NULL / anonymised values, or `DELETE` |
| Purge old logs | `DELETE … WHERE created_at < now() - interval '90 days'` (in batches) |

## Soft delete vs hard delete
| | Hard delete (`DELETE`) | Soft delete (`is_active = FALSE` / `deleted_at`) |
|---|---|---|
| Data recoverable | no | yes |
| Foreign keys | may block / cascade | unaffected |
| Queries | simple | must remember `WHERE is_active` (use a view) |
| Storage | freed | grows |

## Performance notes
- Bulk-loading millions of rows: use `COPY` (Postgres) / `LOAD DATA` (MySQL) / `BULK INSERT` (SQL Server) — 10–100× faster than INSERT.
- Deleting millions of rows in one statement holds locks and bloats the log → delete **in batches**,
  or for "delete everything" use `TRUNCATE`.
- In Postgres, `UPDATE` writes a new row version (MVCC); old versions are cleaned by `VACUUM`.

## Common mistakes
- Missing `WHERE`.
- `WHERE` that matches more rows than expected (e.g. `WHERE last_name = 'Shah'` instead of the id).
- Inserting strings into numeric columns relying on implicit casts.
- Forgetting identity sequences after inserting explicit ids → duplicate-key errors later (see seed.sql).

## Dialect notes
| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Return inserted rows | `RETURNING *` | `LAST_INSERT_ID()` | `OUTPUT inserted.*` |
| Limit rows changed | (use subquery) | `DELETE … LIMIT 100` | `DELETE TOP (100) …` |
| Bulk load | `COPY` | `LOAD DATA INFILE` | `BULK INSERT` |
