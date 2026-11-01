# 07 · Views

## What it is
A **view** is a **saved query with a name**. It looks and behaves like a table in `SELECT`s, but it stores
**no data** — every time you query it, the database runs the underlying query (merged with yours).

```sql
CREATE VIEW v_order_totals AS
SELECT o.order_id, o.customer_id, o.status,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS total
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

SELECT * FROM v_order_totals WHERE total > 1000;   -- used like a table
```

## Why use views
| Benefit | Example |
|---|---|
| **Reuse & consistency** | "Revenue" is defined once; every report uses the same formula |
| **Abstraction** | Apps/analysts query `v_customer_summary` without knowing the 4 joins behind it |
| **Security** | Expose `v_employee_directory` (no salary column) and grant access only to the view |
| **Backward compatibility** | Rename/split a table, keep a view with the old name so old code still works |
| **Simplify complex logic** | Build layers: `v_order_totals` → `v_customer_summary` → dashboard |

## Types of views
| Type | Stores data? | Always fresh? | Notes |
|---|---|---|---|
| **View** | ❌ | ✅ | Runs the query each time |
| **Materialized view** | ✅ | ❌ (until `REFRESH`) | Fast reads of expensive aggregates (03_hard/12) |
| **Updatable view** | ❌ | ✅ | `INSERT/UPDATE/DELETE` through the view hit the base table |
| **Recursive view** | ❌ | ✅ | `CREATE RECURSIVE VIEW` (shorthand for a recursive CTE) |

## Updatable views
Postgres makes a view **automatically updatable** if it is "simple":
- exactly one table in `FROM` (no joins),
- no `GROUP BY`, `HAVING`, `DISTINCT`, aggregates, window functions, `UNION`, `LIMIT`.

`WITH CHECK OPTION` rejects writes through the view that would produce rows the view can't see
(e.g. inserting an out-of-stock product through `v_in_stock_products`).
More complex views can be made writable with `INSTEAD OF` triggers (03_hard/09).

## Managing views
```sql
CREATE OR REPLACE VIEW v AS …;   -- replace the definition; may only ADD columns at the end,
                                  -- not rename/remove/retype existing ones
ALTER VIEW v RENAME TO v2;
DROP VIEW v;                     -- fails if other views depend on it
DROP VIEW v CASCADE;             -- also drops dependents
```
Views **depend on** their base tables: you can't drop a column a view uses, or change its type,
without dropping/recreating the view. (This is why some teams keep views in migration files.)

## Performance
- A plain view adds **no overhead** by itself: the planner inlines it, so filters you add outside are
  pushed into it (`SELECT … FROM v WHERE customer_id = 1` uses an index on customer_id).
- But a view can **hide expensive work**: querying one column of a 6-join view may still run all the joins
  (Postgres can remove unneeded LEFT JOINs to unique keys, not INNER joins).
- Views stacked on views on views → slow, hard-to-debug plans. Keep layers shallow.
- Need the result *precomputed*? → materialized view.

## Significance & use cases
- **Semantic layer** for BI tools (Metabase, Tableau, Power BI point at views, not raw tables).
- **Row/column-level access**: views per tenant/region, views without PII.
- **Soft-delete filtering**: `CREATE VIEW active_customers AS SELECT * FROM customers WHERE deleted_at IS NULL`.
- **Refactoring** without breaking consumers.

## Common mistakes
- `SELECT *` in a view definition: Postgres expands `*` at **creation time** — columns added to the table
  later do NOT appear in the view.
- `ORDER BY` inside a view — not guaranteed to be preserved by queries that use it; sort in the outer query.
- Treating a view as a performance optimization (it isn't; a materialized view is).
- Forgetting views when changing table structure.

## Naming
Prefix (`v_`, `vw_`) or a dedicated schema (`reporting.customer_summary`) so readers know it's not a table.
