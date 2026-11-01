# 08 · NULL Handling

## What NULL is
`NULL` means **"unknown / missing / not applicable"**. It is **not** zero, not an empty string, not FALSE.
It is the absence of a value — and SQL treats it with special rules that surprise everyone at first.

| Column | NULL might mean |
|---|---|
| `customers.phone` | the customer didn't give one |
| `orders.shipped_date` | not shipped *yet* |
| `employees.manager_id` | not applicable (the CEO) |
| `departments.budget` | not decided yet |

## Three-valued logic (3VL)
Any comparison with NULL yields **UNKNOWN** (which SQL represents as NULL), not TRUE or FALSE:
```
NULL = NULL   → UNKNOWN          NULL <> 5   → UNKNOWN
NULL + 10     → NULL             'a' || NULL → NULL
```
`WHERE` keeps only rows where the condition is **TRUE** — UNKNOWN rows are dropped, just like FALSE.

| AND | TRUE | FALSE | UNKNOWN |
|---|---|---|---|
| **TRUE** | TRUE | FALSE | UNKNOWN |
| **FALSE** | FALSE | FALSE | FALSE |
| **UNKNOWN** | UNKNOWN | FALSE | UNKNOWN |

| OR | TRUE | FALSE | UNKNOWN |
|---|---|---|---|
| **TRUE** | TRUE | TRUE | TRUE |
| **FALSE** | TRUE | FALSE | UNKNOWN |
| **UNKNOWN** | TRUE | UNKNOWN | UNKNOWN |

`NOT UNKNOWN` = UNKNOWN. So `WHERE NOT (x = 5)` does **not** return rows where x is NULL.

## Tools for NULLs
| Tool | Purpose | Example |
|---|---|---|
| `IS NULL` / `IS NOT NULL` | test for NULL (the **only** correct way) | `WHERE phone IS NULL` |
| `COALESCE(a, b, …)` | first non-NULL argument (standard SQL) | `COALESCE(city, 'Unknown')` |
| `NULLIF(a, b)` | NULL if a = b, else a | `x / NULLIF(y, 0)` avoids division by zero |
| `IS DISTINCT FROM` | NULL-safe "not equal" (NULL vs NULL = not distinct) | `WHERE a IS DISTINCT FROM b` |
| `IS NOT DISTINCT FROM` | NULL-safe equality | |
| `CASE WHEN x IS NULL THEN …` | custom logic | topic 02_medium/05 |

## NULLs in other clauses
| Clause | Behaviour |
|---|---|
| `COUNT(*)` | counts rows, NULLs included |
| `COUNT(col)`, `SUM`, `AVG`, `MIN`, `MAX` | **ignore NULLs** (AVG of 10, NULL, 20 = 15, not 10) |
| `GROUP BY` / `DISTINCT` | all NULLs form **one** group |
| `ORDER BY` | Postgres/Oracle: NULLs are *largest* (last in ASC). MySQL/SQL Server: *smallest*. Control with `NULLS FIRST/LAST` |
| `UNIQUE` | multiple NULLs allowed |
| `CHECK` | passes when the expression is NULL |
| Joins | `NULL = NULL` is not true → NULL keys never match (02_medium/01) |
| `NOT IN (…, NULL)` | returns **no rows ever** |

## The `NOT IN` + NULL trap (very common bug)
```sql
SELECT * FROM customers WHERE customer_id NOT IN (SELECT referred_by FROM customers);
-- referred_by contains NULLs → 0 rows!
```
`x NOT IN (1, NULL)` = `x <> 1 AND x <> NULL` = `… AND UNKNOWN` → never TRUE.
**Fix:** filter NULLs out of the subquery, or use `NOT EXISTS` (02_medium/03), which is NULL-safe.

## Significance
NULL bugs are silent: no error, just wrong numbers. A dashboard's "average budget" ignoring NULL
departments, a report that drops customers without a city, a `NOT IN` that returns nothing —
these ship to production all the time. Mastering NULL is a mark of a senior SQL developer.

## Design guidance
- Make columns `NOT NULL` unless "unknown" is a genuine, meaningful state.
- Don't use magic values (`-1`, `'N/A'`, `'1900-01-01'`) instead of NULL — they pollute averages and
  sorting just as badly, and nobody remembers the convention.
- Decide whether "unknown" should be *excluded* (default aggregate behaviour) or *treated as zero*
  (`COALESCE(x, 0)`) — they give different answers, and the business must choose.

## Common mistakes
- `WHERE col = NULL` → always zero rows. Use `IS NULL`.
- `WHERE col <> 'x'` silently excludes NULL rows.
- `AVG(col)` vs `SUM(col)/COUNT(*)` — different when NULLs exist.
- String concatenation with `||` turning a whole value NULL.
- `NOT IN (subquery)` with NULLs.

## Dialect notes
| | PostgreSQL | MySQL | SQL Server | Oracle |
|---|---|---|---|---|
| First non-null | `COALESCE` | `COALESCE`, `IFNULL` | `COALESCE`, `ISNULL` | `COALESCE`, `NVL` |
| NULL-safe equality | `IS NOT DISTINCT FROM` | `<=>` | `IS NOT DISTINCT FROM` (2022+) | `DECODE` trick |
| Empty string | `''` ≠ NULL | `''` ≠ NULL | `''` ≠ NULL | **`''` IS NULL!** |
