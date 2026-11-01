# 08 · Advanced DML — UPSERT, INSERT…SELECT, UPDATE…FROM, DELETE…USING, RETURNING, MERGE

## What it is
The basic `INSERT/UPDATE/DELETE` (easy/05) change rows one rule at a time. Real systems need to
**change data based on other data**: load a feed, sync two tables, apply aggregated results, archive rows.

| Statement | Purpose |
|---|---|
| `INSERT … SELECT` | insert the result of a query (bulk copy, build summary tables) |
| `INSERT … ON CONFLICT DO NOTHING` | insert, silently skip rows that would violate a unique key (idempotent loads) |
| `INSERT … ON CONFLICT DO UPDATE` | **UPSERT**: insert new rows, update existing ones |
| `UPDATE … FROM` | update using values from other tables (a join in an UPDATE) |
| `DELETE … USING` | delete using conditions on other tables |
| `… RETURNING` | get the affected rows back (ids, new values) in the same statement |
| `MERGE` | standard SQL insert/update/delete in one statement based on a source (PG 15+, SQL Server, Oracle) |
| Writable CTEs | chain several modifications atomically (`WITH x AS (UPDATE … RETURNING …) INSERT …`) |

## UPSERT in Postgres
```sql
INSERT INTO products (product_id, product_name, price, …)
VALUES (…)
ON CONFLICT (product_id)                 -- needs a UNIQUE/PK constraint on these columns
DO UPDATE SET price = EXCLUDED.price     -- EXCLUDED = the row that failed to insert
WHERE products.price <> EXCLUDED.price;  -- optional: only update when something changed
```
- It is **atomic and concurrency-safe**: no race between "check if exists" and "insert".
- The naive alternative (`SELECT` then `INSERT` or `UPDATE` in app code) breaks under concurrency —
  two sessions both see "not exists" and both insert → duplicate key error.

## UPDATE … FROM / DELETE … USING
```sql
UPDATE products p
SET    stock_qty = p.stock_qty - s.qty
FROM   (SELECT product_id, SUM(quantity) AS qty FROM order_items … GROUP BY product_id) s
WHERE  s.product_id = p.product_id;
```
- The `FROM` list is joined to the target; `WHERE` is the join condition.
- ⚠️ If the join matches **multiple** source rows per target row, Postgres updates with an
  **arbitrary one** — aggregate the source first so it's 1:1.
- Portable alternative: correlated subquery in `SET` (`SET x = (SELECT … WHERE … = p.id)`), which
  also sets NULL when nothing matches — often not what you want; add `WHERE EXISTS (…)`.

## MERGE (SQL:2003, PostgreSQL 15+)
```sql
MERGE INTO products t
USING price_feed s ON s.product_id = t.product_id
WHEN MATCHED AND s.discontinued THEN DELETE
WHEN MATCHED THEN UPDATE SET price = s.price
WHEN NOT MATCHED THEN INSERT (product_id, price, …) VALUES (s.product_id, s.price, …);
```
Great for syncing a target from a staging table with several outcomes. Note: in Postgres, `MERGE`
is not as concurrency-safe as `ON CONFLICT` for pure upserts (it can raise unique violations under
concurrent inserts).

## Significance & use cases
- **ETL/ELT loads**: staging table → target with UPSERT or MERGE (incremental loads).
- **Idempotent pipelines**: re-running a job must not duplicate data (`ON CONFLICT DO NOTHING`).
- **Summary tables**: `INSERT INTO daily_sales SELECT … GROUP BY …`.
- **Inventory**: decrement stock from order lines with `UPDATE … FROM`.
- **Archiving**: `WITH moved AS (DELETE … RETURNING *) INSERT INTO archive SELECT * FROM moved`.
- **Audit trails**: capture old & new values of an update in one statement.

## Performance
- One set-based statement beats a loop of single-row statements by orders of magnitude.
- For millions of rows: batch (e.g. 10k rows per transaction) to limit lock time and WAL bursts.
- `ON CONFLICT DO UPDATE` writes a new row version even if values are unchanged — add the
  `WHERE … IS DISTINCT FROM …` clause to skip no-op updates.

## Common mistakes
- `ON CONFLICT (col)` without a unique index on exactly `col` → error.
- `UPDATE … FROM` with a non-unique join → nondeterministic results.
- Forgetting `WHERE` in the `UPDATE … FROM` → every target row joined to every source row.
- Using `RETURNING` values of an UPDATE expecting the *old* values (it returns the new ones;
  see the self-join trick in the lesson).

## Dialect notes
| | PostgreSQL | MySQL | SQL Server | Oracle |
|---|---|---|---|---|
| Upsert | `ON CONFLICT … DO UPDATE` | `ON DUPLICATE KEY UPDATE` | `MERGE` | `MERGE` |
| Insert-ignore | `ON CONFLICT DO NOTHING` | `INSERT IGNORE` | `MERGE` / `WHERE NOT EXISTS` | `MERGE` |
| Update with join | `UPDATE t … FROM s WHERE …` | `UPDATE t JOIN s ON … SET …` | `UPDATE t … FROM t JOIN s …` | `MERGE` / subquery |
| Delete with join | `DELETE FROM t USING s WHERE …` | `DELETE t FROM t JOIN s …` | `DELETE t FROM t JOIN s …` | subquery |
| Return rows | `RETURNING` | — | `OUTPUT` | `RETURNING INTO` (PL/SQL) |
