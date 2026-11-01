# 03 · CREATE, ALTER, DROP (DDL)

## What it is
**DDL — Data Definition Language** — creates and changes the *structure* of a database:
schemas, tables, columns, indexes, views. DDL describes *containers*; DML (topic 05) fills them.

| Statement | Purpose |
|---|---|
| `CREATE SCHEMA` | a namespace (folder) for tables |
| `CREATE TABLE` | define a new table: columns, types, constraints |
| `CREATE TABLE … AS SELECT` (CTAS) | create a table from a query result |
| `ALTER TABLE` | add / drop / rename / retype columns, add / drop constraints, rename table |
| `DROP TABLE` | delete the table **and all its data** |
| `TRUNCATE` | delete all rows, keep the structure (fast) |
| `COMMENT ON` | attach documentation to objects |

## How it works
```sql
CREATE TABLE [IF NOT EXISTS] schema.table_name (
    column_name  data_type  [column_constraints],
    ...,
    [table_constraints]
);
```
- **Schema** = namespace. `public` is Postgres' default. Use schemas to separate `staging`, `analytics`,
  `sandbox`… Fully qualified name: `schema.table`.
- **`IF NOT EXISTS` / `IF EXISTS`** make scripts **idempotent** (safe to re-run) — essential for migrations.
- **`CASCADE`** also drops dependent objects (views, FKs). **`RESTRICT`** (default) refuses if anything depends on it.

### `ALTER TABLE` actions you'll use most
```sql
ALTER TABLE t ADD COLUMN c TYPE [DEFAULT …] [NOT NULL];
ALTER TABLE t DROP COLUMN c;
ALTER TABLE t RENAME COLUMN a TO b;
ALTER TABLE t RENAME TO new_name;
ALTER TABLE t ALTER COLUMN c TYPE new_type [USING expression];
ALTER TABLE t ALTER COLUMN c SET DEFAULT v | DROP DEFAULT;
ALTER TABLE t ALTER COLUMN c SET NOT NULL | DROP NOT NULL;
ALTER TABLE t ADD CONSTRAINT name CHECK (…);
ALTER TABLE t DROP CONSTRAINT name;
```

### DROP vs TRUNCATE vs DELETE
| | `DELETE FROM t` | `TRUNCATE t` | `DROP TABLE t` |
|---|---|---|---|
| Removes | chosen rows (WHERE) | all rows | rows **and** structure |
| Speed on big tables | slow (row by row, logs each) | very fast (deallocates pages) | very fast |
| Fires row triggers | yes | no | no |
| Resets identity | no | with `RESTART IDENTITY` | n/a |
| Can be rolled back (Postgres) | yes | yes | yes |

## Significance
- Schema design is the **foundation**: a bad structure causes bugs and slow queries forever.
- In real teams, DDL lives in **migration files** (Flyway, Liquibase, Alembic, Rails, dbt) that are versioned
  in git and applied in order. Each migration must be idempotent and reversible.
- **Postgres has transactional DDL**: `BEGIN; ALTER…; ALTER…; ROLLBACK;` undoes the structure changes too.
  **MySQL and Oracle do not** — each DDL auto-commits. A half-applied migration in MySQL needs manual cleanup.

## Use cases
- Creating tables for a new feature (`CREATE TABLE`).
- Evolving a live schema without downtime (`ADD COLUMN` nullable / with default).
- Building snapshot / staging tables in ETL (`CREATE TABLE … AS SELECT`).
- Clearing staging tables between loads (`TRUNCATE`).

## Production considerations
- `ADD COLUMN … DEFAULT constant` is instant in Postgres 11+ (no table rewrite).
- `ALTER COLUMN TYPE` usually **rewrites the whole table** and takes an exclusive lock — dangerous on big tables.
- Renaming/dropping columns breaks running application code → use the **expand/contract** pattern:
  add new column → write to both → backfill → switch reads → drop old.
- Never `DROP` in production without a backup; prefer renaming to `_old` first.

## Common mistakes
- Forgetting `IF EXISTS` → migration scripts fail on second run.
- `CREATE TABLE AS` copies data and types, but **not** primary keys, defaults, indexes or constraints.
- Adding a `NOT NULL` column without a default to a table that has rows → error.
- Using reserved words as names (`user`, `order`, `group`) → you must quote them forever. Use `orders`, `app_user`.

## Naming conventions (pick one, be consistent)
- `snake_case`, lowercase, plural table names (`order_items`) or singular — just be consistent.
- PK: `id` or `<table>_id`; FK: `<referenced_table>_id`.
- Constraint names: `chk_<table>_<rule>`, `fk_<table>_<ref>`, `uq_<table>_<cols>`.

## Dialect notes
| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Rename column | `RENAME COLUMN a TO b` | same (8.0+) | `EXEC sp_rename 't.a', 'b'` |
| Change type | `ALTER COLUMN c TYPE x` | `MODIFY COLUMN c x` | `ALTER COLUMN c x` |
| CTAS | `CREATE TABLE t AS SELECT` | same | `SELECT … INTO t FROM …` |
| Transactional DDL | ✅ | ❌ | ✅ (mostly) |
