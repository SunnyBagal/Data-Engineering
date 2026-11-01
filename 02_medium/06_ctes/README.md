# 06 · CTEs — Common Table Expressions (`WITH`)

## What it is
A **CTE** is a named, temporary result set defined at the start of a query with `WITH`, and used by
the main query like a table. It exists only for the duration of that single statement.

```sql
WITH order_totals AS (                         -- step 1: name a sub-result
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS total
    FROM order_items
    GROUP BY order_id
),
big_orders AS (                                -- step 2: can use step 1
    SELECT * FROM order_totals WHERE total > 1000
)
SELECT COUNT(*) FROM big_orders;               -- main query
```

## Why use CTEs (vs nested subqueries)
| Benefit | Explanation |
|---|---|
| **Readability** | Logic reads top-to-bottom as named steps instead of inside-out nesting |
| **Reuse** | A CTE can be referenced several times in the main query (a derived table must be repeated) |
| **Debuggability** | Run the query up to any step: `… SELECT * FROM step2;` |
| **Recursion** | `WITH RECURSIVE` walks hierarchies/graphs (03_hard/03) — impossible with plain subqueries |
| **Data-modifying pipelines** | `WITH moved AS (DELETE … RETURNING *) INSERT INTO archive SELECT * FROM moved` |

## How the database executes them
- **PostgreSQL 12+**: a CTE referenced **once** (and without side effects) is **inlined** — optimized
  exactly like a subquery. A CTE referenced **more than once** is **materialized** (computed once,
  stored in memory/temp).
- You can force either: `WITH x AS MATERIALIZED (…)` / `AS NOT MATERIALIZED (…)`.
- **PostgreSQL ≤ 11** always materialized CTEs — an "optimization fence" that blocked predicate
  push-down. Old advice "CTEs are slow" comes from this.
- SQL Server / Snowflake / BigQuery generally inline CTEs (and re-execute them per reference).

## CTE vs subquery vs view vs temp table
| | Scope | Reusable across queries | Stored | Indexable |
|---|---|---|---|---|
| Subquery / derived table | one place in one query | ❌ | ❌ | ❌ |
| **CTE** | one statement | ❌ | sometimes (materialized) | ❌ |
| View (02_medium/07) | database object | ✅ | ❌ (query is stored) | ❌ |
| Materialized view | database object | ✅ | ✅ | ✅ |
| Temp table | session | ✅ (in the session) | ✅ | ✅ |

Use a CTE to structure **one** complex query; a view to **share** logic; a temp table when an
intermediate result is huge, reused by many statements, or needs an index.

## Significance & use cases
CTEs are the standard style of analytical SQL (dbt models, Airflow transforms, BI queries):
- Multi-step metrics: order totals → customer spend → tiers → tier counts.
- "Compare with the total": compute the grand total once, divide each group by it.
- Top-per-group without window functions: per-group max in one CTE, join back.
- Funnels and cohorts: one CTE per stage.
- Safe data migrations with `DELETE … RETURNING` feeding an `INSERT`.

## Style tips
- Name CTEs like tables describing their content: `order_totals`, `customer_spend`, not `cte1`, `t`.
- One responsibility per CTE; keep them small.
- Put filters as early as possible (in the first CTE that can apply them).
- End with a simple `SELECT` from the final CTE.

## Common mistakes
- Comma after the last CTE (`… ), SELECT` → syntax error) or missing comma between CTEs.
- Expecting a CTE to persist to the next statement — it doesn't.
- Assuming a CTE is computed once in every database (it may be re-executed per reference).
- Very large materialized CTEs without indexes being joined repeatedly → consider a temp table.
- In data-modifying CTEs, all sub-statements see the **same snapshot**: a CTE that UPDATEs a row
  and a main query that reads it won't see the update (use `RETURNING` to pass data along).
