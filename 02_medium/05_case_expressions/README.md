# 05 · CASE Expressions — Conditional Logic

## What it is
`CASE` is SQL's **if / else-if / else**. It's an *expression*: it returns one value per row, so you can use
it anywhere a value is allowed — `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, inside aggregates,
in `UPDATE … SET`, in `CHECK` constraints.

### Searched CASE (most flexible)
```sql
CASE
    WHEN price < 50   THEN 'budget'
    WHEN price < 500  THEN 'mid-range'
    ELSE                   'premium'
END
```

### Simple CASE (compare one expression to values)
```sql
CASE status
    WHEN 'pending'   THEN 1
    WHEN 'shipped'   THEN 2
    ELSE                  9
END
```
Simple CASE uses `=`, so `CASE x WHEN NULL THEN …` **never matches** — use searched CASE with `x IS NULL`.

## How it evaluates
1. `WHEN` conditions are checked **top to bottom**; the **first TRUE one wins**, the rest are skipped.
   → Order from most specific to most general (`< 50` before `< 500`).
2. A condition that is FALSE or NULL (unknown) is skipped.
3. No match and no `ELSE` → result is **NULL**. Always write an `ELSE` (even `ELSE NULL`) to show intent.
4. All `THEN`/`ELSE` results must be of **compatible types** (`THEN 1 ELSE 'x'` → error).

## Where CASE shines
| Use | Example |
|---|---|
| **Bucketing / labelling** | price bands, salary grades, customer tiers |
| **Custom sort order** | `ORDER BY CASE status WHEN 'pending' THEN 1 … END` |
| **Conditional aggregation / pivots** | `SUM(CASE WHEN method = 'card' THEN amount ELSE 0 END)` (02_medium/12) |
| **Safe calculations** | `CASE WHEN qty = 0 THEN NULL ELSE total / qty END` |
| **Data cleaning / mapping** | `CASE WHEN country IN ('US','USA','United States') THEN 'USA' … END` |
| **Conditional updates** | one `UPDATE` with different rules per row instead of several statements |
| **Business rules in one place** | shipping speed SLA labels |

## CASE and its shortcuts
| Shortcut | Equivalent CASE |
|---|---|
| `COALESCE(a, b)` | `CASE WHEN a IS NOT NULL THEN a ELSE b END` |
| `NULLIF(a, b)` | `CASE WHEN a = b THEN NULL ELSE a END` |
| `GREATEST(a, b)` | `CASE WHEN a >= b THEN a ELSE b END` (NULL handling differs) |
| `agg(x) FILTER (WHERE cond)` | `agg(CASE WHEN cond THEN x END)` |

Prefer the shortcut when it exists — it's shorter and states intent.

## Significance
CASE lets you encode **business rules** directly in queries: what counts as a "VIP", a "late shipment",
a "high-risk transaction". It turns raw values into categories people understand, and it's the
building block of pivot tables and KPI reports.

## Performance
CASE itself is cheap (per-row CPU). But `WHERE CASE … END = 'x'` hides the column from indexes —
write the underlying condition directly in WHERE when filtering.
If the same CASE appears in many queries, consider a **generated column**, a **view**, or a
**lookup table** (bands as rows, joined with a range join) so the rule lives in one place.

## Common mistakes
- Wrong WHEN order (`WHEN price < 500` before `WHEN price < 50` → nothing is ever "budget").
- Missing `ELSE` → unexpected NULLs that then disappear in `COUNT(col)`/joins.
- `CASE x WHEN NULL` never matching.
- Mixed result types.
- Boundaries: is 50 "budget" or "mid"? Use consistent `<` vs `<=` and document it.
- Using `SUM(CASE … THEN 1 ELSE NULL END)` and getting NULL instead of 0 when nothing matches →
  use `ELSE 0` for counts.

## Dialect notes
- Standard and portable across all major databases.
- MySQL also has `IF(cond, a, b)`; SQL Server has `IIF(cond, a, b)`; Oracle has `DECODE(x, v1, r1, …)`.
  Prefer `CASE` for portability.
