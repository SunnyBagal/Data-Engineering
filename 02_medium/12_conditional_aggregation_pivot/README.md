# 12 · Conditional Aggregation & Pivoting

## What it is
**Conditional aggregation** computes several aggregates over **different subsets of rows in a single pass**.
**Pivoting** uses it to turn **row values into columns** — the "spreadsheet / cross-tab" layout people
expect in reports.

```
Long format (GROUP BY year, status)        Wide format (pivot)
year | status    | orders                year | delivered | cancelled | returned
2023 | delivered | 16           →         2023 |    16     |     2     |    2
2023 | cancelled |  2                     2024 |    13     |     1     |    0
2023 | returned  |  2                     …
```

## Two ways to write it
```sql
-- 1) FILTER clause (SQL standard; PostgreSQL, SQLite 3.30+)
COUNT(*)    FILTER (WHERE status = 'cancelled')           AS cancelled,
SUM(amount) FILTER (WHERE method = 'card')                AS card_total

-- 2) CASE inside the aggregate (works in EVERY database)
SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END)     AS cancelled,
SUM(CASE WHEN method = 'card' THEN amount ELSE 0 END)     AS card_total
COUNT(CASE WHEN status = 'cancelled' THEN 1 END)          AS cancelled_v2   -- COUNT ignores the NULLs
```
Subtle difference: `SUM(x) FILTER (…)` returns **NULL** when no row matches, `SUM(CASE … ELSE 0 END)`
returns **0**. Choose (or `COALESCE`) on purpose.

## Recipe for a pivot
1. `GROUP BY` the **row** dimension (e.g. year).
2. One conditional aggregate **per output column** (each status / method / category).
3. Optionally a total column (`COUNT(*)`) and ratio columns.

## Unpivot (wide → long)
The reverse: turn columns back into rows — needed when data arrives as spreadsheets (`jan, feb, mar…`).
- `UNION ALL` of one SELECT per column (portable),
- `CROSS JOIN LATERAL (VALUES ('jan', jan), ('feb', feb)) v(month, amount)` (Postgres, concise),
- `UNPIVOT` operator (SQL Server, Oracle, Snowflake).

## Dynamic pivots
SQL needs to know the output columns **when the query is written**. If the set of values changes
(new payment method → new column), you must:
- regenerate the SQL (in application code / dbt macro / PL/pgSQL `EXECUTE`), or
- use `crosstab()` from the `tablefunc` extension (still needs a column definition list), or
- keep the result **long** and let the BI tool pivot it (often the best option).

## Significance & use cases
- Report layouts: months as columns, KPIs side by side.
- Funnel metrics: viewers, carts, purchases per day in one row.
- Ratios within a group: cancellation rate per rep, % weekend logins per device.
- Feature engineering for ML: one row per customer with many conditional counts.
- Replacing N separate queries (one per status) with one table scan.

## Performance
One pass over the data with many `FILTER`s is far cheaper than many separate queries or self-joins.
Very wide pivots (hundreds of columns) are better left to BI/pandas.

## Common mistakes
- Forgetting `ELSE 0` and getting NULLs in the totals, or `ELSE 0` inside `COUNT(CASE …)` (counts every row!).
- Filtering with `WHERE status = 'x'` (removes rows for all other columns) instead of per-column FILTER.
- Hard-coding values that later change (a new status silently missing from the report) — add an
  "other" column: `COUNT(*) FILTER (WHERE status NOT IN (…))`.
- Dividing integer counts (`count_a / count_b` = 0) — multiply by `100.0` first.

## Dialect notes
| | PostgreSQL | SQL Server | Oracle | Snowflake | MySQL |
|---|---|---|---|---|---|
| `FILTER` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PIVOT` / `UNPIVOT` | ❌ (`crosstab`) | ✅ | ✅ | ✅ | ❌ |
| `SUM(CASE …)` | ✅ | ✅ | ✅ | ✅ | ✅ |
