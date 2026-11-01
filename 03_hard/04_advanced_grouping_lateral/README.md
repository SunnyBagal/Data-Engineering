# 04 · Advanced Grouping (ROLLUP, CUBE, GROUPING SETS) & LATERAL Joins

## Part 1 — Multiple grouping levels in one query

### What it is
Reports usually need **detail rows *and* subtotals *and* a grand total**. Instead of `UNION ALL`-ing
several `GROUP BY` queries, SQL can compute several groupings in a single pass.

| Syntax | Groupings produced | Example for (year, method) |
|---|---|---|
| `GROUPING SETS ((a,b), (a), ())` | exactly the listed sets | detail, per-year subtotal, grand total |
| `ROLLUP (a, b)` | `(a,b), (a), ()` — hierarchical subtotals | year → method drill-down |
| `CUBE (a, b)` | `(a,b), (a), (b), ()` — every combination | totals per year AND per method |

`ROLLUP(a, b, c)` = n+1 sets; `CUBE(a, b, c)` = 2ⁿ sets.

### Telling subtotal rows apart: `GROUPING()`
In subtotal rows, the rolled-up columns are **NULL**. But a column can also be NULL in the data
(e.g. `employee_id` NULL = online order) — ambiguous! `GROUPING(col)` returns **1** when the column was
aggregated away in that row, **0** when it's a real grouping value (NULL or not).
```sql
CASE WHEN GROUPING(method) = 1 THEN 'All methods' ELSE method END
```
`GROUPING(a, b)` returns a bitmask (a = 2, b = 1) to identify each level.

### Use cases
- Financial reports with subtotals per region/country/city.
- Pivot-table style summaries for BI exports.
- Computing many aggregations over a big table in **one scan** instead of several.

## Part 2 — LATERAL joins

### What it is
Normally, a subquery in `FROM` can't see the other tables in the same `FROM`. **`LATERAL`** lets a
subquery (or function) on the right **reference columns of tables on its left** — it runs
**once per left row**, like a correlated subquery that can return **many rows and many columns**.

```sql
SELECT c.first_name, t.order_id, t.total
FROM customers c
CROSS JOIN LATERAL (                      -- for EACH customer…
    SELECT o.order_id, SUM(...) AS total
    FROM orders o JOIN order_items oi USING (order_id)
    WHERE o.customer_id = c.customer_id   -- …refers to c (outer row)
    GROUP BY o.order_id
    ORDER BY total DESC
    LIMIT 2                               -- …its top 2 orders
) t;
```
- `CROSS JOIN LATERAL` drops left rows for which the subquery returns nothing (like INNER).
- `LEFT JOIN LATERAL (…) t ON TRUE` keeps them, with NULLs (like LEFT).
- Set-returning functions in `FROM` are implicitly lateral:
  `FROM products p, jsonb_array_elements_text(p.attributes -> 'tags') AS tag`.

### When LATERAL is the best tool
| Need | Why LATERAL |
|---|---|
| **Top-N per group** with an index | runs an index-backed `ORDER BY … LIMIT n` per group — can beat window functions on big tables |
| Several columns from a correlated subquery | a scalar subquery returns only one column |
| Unnest arrays / JSON arrays per row | `jsonb_array_elements`, `unnest`, `regexp_matches` |
| Reuse a computed expression | `CROSS JOIN LATERAL (SELECT price - cost AS margin) m` then use `m.margin` in WHERE/SELECT |
| Unpivot | `CROSS JOIN LATERAL (VALUES (…), (…))` (medium/12) |

### Dialect notes
| | PostgreSQL | SQL Server | Oracle | MySQL |
|---|---|---|---|---|
| LATERAL | `LATERAL` | `CROSS APPLY` / `OUTER APPLY` | `LATERAL` / `CROSS APPLY` | `LATERAL` (8.0.14+) |
| ROLLUP/CUBE/GROUPING SETS | ✅ | ✅ | ✅ | `WITH ROLLUP` only |

## Common mistakes
- Interpreting NULLs in ROLLUP output as data (use `GROUPING()`).
- `ORDER BY` that puts the subtotal rows in odd places — sort by `GROUPING(…)` too.
- CUBE on many columns → explosion of groupings (2ⁿ).
- `CROSS JOIN LATERAL` silently dropping rows that should appear with zeros → use `LEFT JOIN LATERAL … ON TRUE`.
- LATERAL per-row subqueries on huge left tables without an index → N slow lookups.
