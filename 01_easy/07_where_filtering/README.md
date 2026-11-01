# 07 · WHERE — Filtering Rows

## What it is
`WHERE` keeps only the rows for which a condition is **TRUE**. Rows where it is FALSE **or NULL (unknown)**
are discarded. It runs right after `FROM`, before grouping and before `SELECT`.

```sql
SELECT columns
FROM   table
WHERE  condition;            -- the same WHERE works in UPDATE and DELETE
```

## Operators
| Category | Operators | Example |
|---|---|---|
| Comparison | `=  <>  !=  <  <=  >  >=` | `price >= 100` |
| Logical | `AND  OR  NOT` | `country = 'India' AND city = 'Mumbai'` |
| Range | `BETWEEN a AND b` (inclusive both ends) | `price BETWEEN 50 AND 100` |
| List | `IN (…)`, `NOT IN (…)` | `status IN ('shipped','delivered')` |
| Pattern | `LIKE`, `ILIKE` (case-insensitive, Postgres) | `email LIKE '%@mail.com'` |
| Regex | `~`, `~*` (Postgres), `SIMILAR TO` | `phone ~ '^\+91'` |
| Null test | `IS NULL`, `IS NOT NULL` | `shipped_date IS NULL` (topic 08) |

### LIKE wildcards
| Pattern | Matches |
|---|---|
| `'A%'` | starts with A |
| `'%book%'` | contains "book" |
| `'%_Phone'` | at least one char, then "Phone" at the end |
| `'_a%'` | second character is "a" |
| `'50\%%'` | starts with literal "50%" (escape with `\`) |

`%` = any number of characters (incl. zero), `_` = exactly one character.

## Operator precedence — the classic bug
`NOT` binds tighter than `AND`, which binds tighter than `OR`.

```sql
WHERE country = 'India' OR country = 'UK' AND signup_date >= '2023-01-01'
-- is read as
WHERE country = 'India' OR (country = 'UK' AND signup_date >= '2023-01-01')
```
**Always use parentheses when mixing AND and OR** — or use `IN`, which avoids the problem.

## Filtering dates & timestamps correctly
`BETWEEN '2024-01-01' AND '2024-01-31'` on a **TIMESTAMP** column means "up to 2024-01-31 **00:00:00**"
and silently drops everything later that day. Use a **half-open range**:
```sql
WHERE order_date >= '2024-01-01' AND order_date < '2024-02-01'
```
It works for both DATE and TIMESTAMP, never double-counts boundaries, and can use an index.

## Sargability (performance)
A predicate is **sargable** (Search-ARGument-ABLE) when the database can use an index for it.
| Not sargable (scans every row) | Sargable rewrite |
|---|---|
| `WHERE EXTRACT(YEAR FROM order_date) = 2024` | `WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'` |
| `WHERE price * 1.1 > 110` | `WHERE price > 100` |
| `WHERE LOWER(email) = 'x@y.com'` | expression index on `LOWER(email)` (03_hard/06) |
| `WHERE name LIKE '%phone'` | (leading wildcard can't use a B-tree; consider trigram index) |

Rule: **keep the column bare** on one side of the comparison.

## Why it matters
Filtering is how you get from "all the data" to "the data that answers my question". In DML,
the `WHERE` clause is the difference between changing one row and changing every row.

## Use cases
- "Orders in the last 30 days": `order_date >= now() - interval '30 days'`
- "Active employees in Sales": `dept_id = 2 AND is_active`
- "Customers with Gmail": `email ILIKE '%@gmail.com'`
- "Exclude test accounts": `email NOT LIKE '%@test.%'`

## Common mistakes
- Mixing `AND`/`OR` without parentheses.
- `BETWEEN` on timestamps (see above). Also `BETWEEN 10 AND 1` returns nothing (low must come first).
- `= NULL` instead of `IS NULL` (always unknown → no rows) — topic 08.
- `NOT IN (subquery)` when the subquery returns a NULL → returns **no rows** (topic 08 / 02_medium/03).
- Case sensitivity: `LIKE` is case-sensitive in Postgres; MySQL's default collation is case-insensitive.
- Comparing text numbers: `'100' < '20'` is TRUE.

## Dialect notes
| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Case-insensitive LIKE | `ILIKE` | default collation is CI | default collation is CI |
| Regex | `~`, `~*` | `REGEXP` | (none built-in before 2025) |
| Not equal | `<>` and `!=` | both | both |
