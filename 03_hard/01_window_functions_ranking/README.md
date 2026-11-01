# 01 · Window Functions — Ranking

## What it is
A **window function** computes a value for each row using a **set of related rows** (its *window*) —
**without collapsing them** like `GROUP BY` does. You keep every detail row *and* get group-level
information next to it.

```sql
SELECT first_name, dept_id, salary,
       RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rank_in_dept
FROM employees;
```

| | GROUP BY | Window function |
|---|---|---|
| Output rows | one per group | one per input row |
| Detail columns available | only grouped/aggregated ones | all of them |
| Typical question | "total per department" | "each employee's rank / share **within** the department" |

## Anatomy of `OVER (…)`
```
function() OVER (
    PARTITION BY a, b      -- split rows into independent groups (optional; default = all rows)
    ORDER BY c DESC        -- order rows inside each partition (needed for ranking)
    ROWS BETWEEN …         -- frame (for aggregate/value windows — next topic)
)
```
Reuse a definition with the `WINDOW` clause:
`… OVER w … WINDOW w AS (PARTITION BY dept_id ORDER BY salary DESC)`.

## Ranking functions
For salaries 180, 140, 120, **95, 95**, 70:

| Function | Result | Behaviour on ties |
|---|---|---|
| `ROW_NUMBER()` | 1 2 3 4 5 6 | unique numbers; tie order is **arbitrary** unless you add a tie-breaker |
| `RANK()` | 1 2 3 4 4 **6** | ties share a rank; **gaps** after ties (Olympic ranking) |
| `DENSE_RANK()` | 1 2 3 4 4 **5** | ties share a rank; **no gaps** |
| `NTILE(n)` | buckets 1..n | splits rows into n near-equal groups (quartiles, deciles) |
| `PERCENT_RANK()` | 0 … 1 | `(rank − 1) / (rows − 1)` |
| `CUME_DIST()` | (0, 1] | fraction of rows ≤ current row |

### Which one to use?
- "Exactly one row per group" (latest order, dedup) → `ROW_NUMBER()` + a deterministic ORDER BY.
- "Top 3 including ties" → `RANK()` or `DENSE_RANK()`.
- "2nd highest **distinct** salary" → `DENSE_RANK() = 2`.
- Percentiles / segments → `NTILE`, `PERCENT_RANK`.

## Where window functions can be used
They're evaluated **after** `WHERE`, `GROUP BY` and `HAVING`, right before `DISTINCT`/`ORDER BY`/`LIMIT`:
```
FROM → WHERE → GROUP BY → HAVING → [WINDOW FUNCTIONS] → SELECT list → DISTINCT → ORDER BY → LIMIT
```
Consequences:
- ❌ Not allowed in `WHERE` / `GROUP BY` / `HAVING` → filter in an outer query or CTE:
  `WITH r AS (SELECT …, ROW_NUMBER() OVER (…) AS rn FROM …) SELECT * FROM r WHERE rn = 1;`
- ✅ They can be applied **on top of aggregates**: `RANK() OVER (ORDER BY SUM(revenue) DESC)` in a grouped query.
- `WHERE` filters rows **before** the ranking is computed (affects the ranks).

## Classic patterns
| Pattern | Recipe |
|---|---|
| **Top-N per group** | `ROW_NUMBER()/RANK() OVER (PARTITION BY group ORDER BY metric DESC)` → `WHERE rn <= N` |
| **Latest row per key** | `ROW_NUMBER() OVER (PARTITION BY key ORDER BY ts DESC)` → `rn = 1` |
| **Deduplication** | `ROW_NUMBER() OVER (PARTITION BY <dup columns> ORDER BY <keep-preference>)` → delete `rn > 1` |
| **Nth highest** | `DENSE_RANK() … = N` |
| **Segmentation** | `NTILE(4) OVER (ORDER BY spend DESC)` → quartiles |

## Significance
Window functions are the biggest jump in SQL expressiveness after joins. They replace slow, complex
correlated subqueries and self-joins with a single pass, and they're asked in nearly every
data-engineering/analytics interview (top-N per group, dedup, Nth highest).

## Performance
Each distinct `PARTITION BY/ORDER BY` combination requires a **sort** (or a matching index).
Several window functions sharing the same window reuse one sort — use the same `WINDOW` definition.
For "latest row per key" on huge tables, an index on `(key, ts DESC)` helps; Postgres' `DISTINCT ON`
is an alternative.

## Common mistakes
- `ROW_NUMBER()` without a unique tie-breaker → nondeterministic results between runs.
- Trying to filter on the window result in `WHERE`.
- Forgetting `PARTITION BY` → ranking across the whole table instead of per group.
- Using `RANK` when you need exactly N rows (ties can return more).
- `NTILE` with fewer rows than buckets → some buckets are empty; buckets differ in size by one.

## Dialect notes
Supported by PostgreSQL, MySQL 8+, SQL Server 2012+, Oracle, SQLite 3.25+, all cloud warehouses.
Snowflake/BigQuery/Databricks add `QUALIFY` to filter on window results directly:
`SELECT … QUALIFY ROW_NUMBER() OVER (…) = 1` (not available in Postgres).
