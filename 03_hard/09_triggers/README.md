# 09 · Triggers

## What it is
A **trigger** makes the database automatically run a function when something happens to a table:
`INSERT`, `UPDATE`, `DELETE` (or `TRUNCATE`). The application doesn't have to remember — the database
guarantees it, for **every** writer.

In Postgres a trigger has two parts:
```sql
CREATE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();      -- modify the row about to be written
    RETURN NEW;
END $$;

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
```

## Timing × level
| | `FOR EACH ROW` | `FOR EACH STATEMENT` |
|---|---|---|
| **BEFORE** | can **change** `NEW` or **skip** the row (`RETURN NULL`) — validation, defaults, normalization | runs once before the statement |
| **AFTER** | sees the final row — audit logs, maintaining other tables, notifications | once after; can read all changed rows via **transition tables** |
| **INSTEAD OF** (views only) | performs the write on the underlying tables | — |

## Special variables (PL/pgSQL)
| Variable | Meaning |
|---|---|
| `NEW` | the new row (INSERT/UPDATE); NULL for DELETE |
| `OLD` | the old row (UPDATE/DELETE); NULL for INSERT |
| `TG_OP` | `'INSERT'`, `'UPDATE'`, `'DELETE'`, `'TRUNCATE'` |
| `TG_TABLE_NAME`, `TG_TABLE_SCHEMA` | which table fired it |
| `TG_WHEN`, `TG_LEVEL` | BEFORE/AFTER, ROW/STATEMENT |
| `TG_ARGV[]` | arguments passed in `CREATE TRIGGER … EXECUTE FUNCTION f('arg')` |

### Return value rules (row-level)
- BEFORE: return `NEW` (possibly modified) to proceed, `NULL` to silently **skip** this row.
- AFTER: return value is ignored (`RETURN NULL` by convention).
- BEFORE DELETE: return `OLD` to proceed.

## Useful options
- `WHEN (condition)` — fire only when needed: `WHEN (OLD.price IS DISTINCT FROM NEW.price)` (cheap filter, avoids calling the function).
- `UPDATE OF col1, col2` — only when those columns are in the SET list.
- `REFERENCING NEW TABLE AS new_rows OLD TABLE AS old_rows` — statement-level access to all affected rows (set-based!).
- Multiple triggers on the same event fire in **alphabetical order** of trigger name.
- `ALTER TABLE t DISABLE TRIGGER name | ALL` for bulk loads (carefully).

## Typical use cases
| Use case | Trigger type |
|---|---|
| `updated_at` timestamps | BEFORE UPDATE, row |
| **Audit trail** (who changed what, old/new values) | AFTER INSERT/UPDATE/DELETE, row |
| Complex validation (cross-table rules a CHECK can't express) | BEFORE, row |
| Maintain denormalized/cached values (order totals, counters) | AFTER, row or statement |
| Make complex views writable | INSTEAD OF |
| Event notifications (`pg_notify`) / outbox pattern | AFTER, row |
| History tables / soft-delete interception | BEFORE DELETE → UPDATE instead |

## Significance
Triggers enforce rules **centrally**: no app, script, or admin session can bypass them. They're how
many systems implement auditing for compliance (who changed a salary?) and keep caches consistent.

## The downsides (use with care)
- **Hidden logic**: developers don't see side effects in the SQL they write → surprises. Document them.
- **Performance**: row-level triggers run once per row; a 1M-row UPDATE runs the function 1M times.
- **Cascades & recursion**: a trigger that updates a table with another trigger… can loop. Guard with
  `WHEN`, `pg_trigger_depth()`, or design.
- **Ordering & debugging** become harder; errors abort the whole statement.
- Prefer constraints (CHECK, FK, UNIQUE, generated columns) when they can express the rule — they're
  declarative and faster.

## Common mistakes
- Forgetting `RETURN NEW` in a BEFORE trigger (returning NULL silently drops the row!).
- Modifying `NEW` in an AFTER trigger (has no effect).
- Updating the same table from its own row trigger (recursion).
- Audit triggers that log unchanged updates — add `WHEN (OLD IS DISTINCT FROM NEW)`.
- Business workflows hidden in chains of triggers.

## Dialect notes
MySQL: `CREATE TRIGGER … BEFORE INSERT ON t FOR EACH ROW BEGIN … END` (body inline; no statement-level
triggers). SQL Server: statement-level only, with `inserted`/`deleted` pseudo-tables; `INSTEAD OF` on tables
too. Oracle: row/statement + compound triggers.
