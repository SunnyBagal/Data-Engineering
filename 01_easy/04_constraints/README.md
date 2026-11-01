# 04 · Constraints

## What they are
**Constraints are rules the database enforces on every write.** If an `INSERT` or `UPDATE` would break a
rule, the whole statement fails and nothing is changed. They are the database's immune system.

| Constraint | Rule | Example |
|---|---|---|
| `NOT NULL` | value must be present | `email … NOT NULL` |
| `UNIQUE` | no two rows share the value(s) | `UNIQUE (email)` |
| `PRIMARY KEY` | `UNIQUE` + `NOT NULL`; the row's identity. One per table | `customer_id … PRIMARY KEY` |
| `FOREIGN KEY` | value must exist in the referenced table (or be NULL) | `customer_id REFERENCES customers` |
| `CHECK` | boolean expression must not be FALSE | `CHECK (price >= 0)` |
| `DEFAULT` | *(not strictly a constraint)* value used when none is supplied | `DEFAULT now()` |
| `EXCLUDE` | (Postgres) no two rows "overlap" by some operator | no double-booked rooms |

## Why they matter
- **Application code is not enough.** There are many writers: multiple services, scripts, admins,
  ETL jobs, a bug in version 2.3… Only the database sees every write.
- They **document** the data model: reading `CHECK (discount BETWEEN 0 AND 1)` tells you what discount means.
- The **optimizer uses them**: a known-unique column lets it skip work; FKs + NOT NULL can eliminate joins.
- Bad data is far more expensive to clean up later than to reject now.

## Column-level vs table-level syntax
```sql
CREATE TABLE t (
    a INT PRIMARY KEY,                    -- column-level: applies to one column
    b INT,
    c INT,
    CONSTRAINT uq_t_b_c UNIQUE (b, c),    -- table-level: needed for multi-column rules
    CONSTRAINT chk_t_b_lt_c CHECK (b < c) -- CHECK comparing two columns
);
```
**Name your constraints** (`CONSTRAINT name …`) — error messages become readable and you can drop them by name.

## Foreign keys in depth
`child.parent_id REFERENCES parent(id) ON DELETE <action> ON UPDATE <action>`

| Action | When the parent row is deleted… | Use when |
|---|---|---|
| `NO ACTION` / `RESTRICT` (default) | error if children exist | most cases — protects history (orders of a customer) |
| `CASCADE` | children are deleted too | children are meaningless alone (order_items of an order) |
| `SET NULL` | child FK becomes NULL | relationship is optional (employee's manager leaves) |
| `SET DEFAULT` | child FK becomes its default | rare |

- `RESTRICT` checks immediately; `NO ACTION` checks at end of statement (or transaction if `DEFERRABLE`).
- A NULL foreign key is allowed (means "no relationship") unless the column is `NOT NULL`.
- Postgres **does not auto-index FK columns** — index them yourself if you join on them or delete parents.

## Subtle but important behaviours
- **UNIQUE allows multiple NULLs** (NULL ≠ NULL). Postgres 15+: `UNIQUE NULLS NOT DISTINCT` changes this.
- **CHECK passes when the expression is NULL** — `CHECK (price > 0)` accepts `price = NULL`. Combine with
  `NOT NULL` when needed.
- CHECK can only see the **current row** (no subqueries). Cross-row/cross-table rules need FKs, triggers,
  or EXCLUDE constraints.
- Adding a constraint to a big existing table scans it. Postgres trick: `ADD CONSTRAINT … NOT VALID`
  (enforced for new rows only) then `VALIDATE CONSTRAINT` later with a weaker lock.
- `DEFERRABLE INITIALLY DEFERRED` checks FKs at `COMMIT` instead of per statement — needed for
  circular references or swapping values.

## Use cases
- `UNIQUE (email)` — no duplicate accounts.
- `CHECK (end_date >= start_date)` — no impossible ranges.
- `UNIQUE (order_id, product_id)` — a product appears once per order.
- FK `ON DELETE CASCADE` from `order_items` to `orders`.
- `EXCLUDE USING gist (room WITH =, during WITH &&)` — meeting-room booking without overlaps.

## Common mistakes
- No constraints "for flexibility" → duplicates and orphans everywhere.
- `ON DELETE CASCADE` on the wrong relationship → deleting one customer silently wipes their payments history.
- Forgetting NULLs pass CHECK and UNIQUE.
- Unnamed constraints → auto-generated names differ between environments, migrations break.

## Dialect notes
- MySQL < 8.0.16 **parsed but ignored CHECK constraints**.
- SQLite enforces foreign keys only after `PRAGMA foreign_keys = ON;`.
- SQL Server allows only **one NULL** in a UNIQUE column (use a filtered unique index for more).
- `EXCLUDE` constraints are Postgres-only.
