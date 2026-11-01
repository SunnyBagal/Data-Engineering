# 06 · SELECT Basics

## What it is
`SELECT` reads data. It never changes anything, so it's always safe to run. Its result is itself
a **table** (rows × columns) — which is why queries can be nested and combined (topics 02_medium/03, 06).

```sql
SELECT [DISTINCT] expression [AS alias], ...
FROM   table [AS alias];
```

## The building blocks
### 1. Column list (projection)
- `SELECT *` — all columns. Fine for exploring; avoid in production code and views.
- `SELECT a, b` — only what you need, in the order you want.

### 2. Expressions — computed columns
Anything that produces a value can be selected:
- arithmetic: `price - cost`, `quantity * unit_price * (1 - discount)`
- string concatenation: `first_name || ' ' || last_name`
- functions: `UPPER(email)`, `ROUND(x, 2)` (topic 12)
- literals: `'USD' AS currency`, `1 AS one`

### 3. Column aliases — `AS`
- Rename output columns: `price - cost AS margin`.
- `AS` is optional (`price - cost margin`) but **write it** — it's clearer and prevents bugs
  (a missing comma `SELECT a b` silently becomes "a aliased as b").
- Aliases with spaces/uppercase need double quotes: `AS "Margin %"`. Prefer `snake_case` instead.
- An alias **cannot be used in `WHERE`** of the same query (WHERE runs before SELECT — see topic 01),
  but **can** be used in `ORDER BY`.

### 4. Table aliases
`FROM customers AS c` (or `FROM customers c`) then `c.email`. Essential once joins appear;
use short, meaningful aliases (`c`, `o`, `oi`), not `a, b, c`.

### 5. DISTINCT — remove duplicate rows
- `SELECT DISTINCT country FROM customers` → each country once.
- With multiple columns, distinctness is on the **whole combination**:
  `SELECT DISTINCT country, city` → each (country, city) pair once.
- NULLs are treated as equal by DISTINCT (one NULL row kept).
- **Postgres `DISTINCT ON (col)`** keeps the first row per value of `col` according to `ORDER BY` —
  a handy shortcut for "latest order per customer" (more in 03_hard/01).

## Why it matters
`SELECT` is 80–90% of the SQL you'll ever write — reporting, debugging, analytics, feeding apps.
Knowing how to shape the output (compute, rename, deduplicate) is the base for everything else.

## Use cases
- Building a report: `SELECT order_id, quantity * unit_price AS line_total …`
- Display formatting: `first_name || ' ' || last_name AS full_name`.
- Finding the set of values in a column: `SELECT DISTINCT status FROM orders`.
- Quick checks: `SELECT COUNT(*)`, `SELECT now()`.

## Performance notes
- `SELECT *` on wide tables reads and transfers unnecessary data and prevents **index-only scans**.
- `DISTINCT` requires a sort or hash over the whole result — on millions of rows it's expensive.
  If you need `DISTINCT` to "fix" duplicates, often the real bug is a wrong join (02_medium/01).

## Common mistakes
- Using an alias in `WHERE`: `SELECT price*2 AS p FROM products WHERE p > 100` → error.
- `DISTINCT` thinking it applies to one column: `SELECT DISTINCT a, b` is distinct on (a, b).
- `NULL` in concatenation: `'Mr ' || NULL` → `NULL` (use `CONCAT()` or `COALESCE`, topic 08).
- Integer division in computed columns (topic 02).
- Reserved words as aliases (`AS order`, `AS user`) — must be quoted; choose another name.

## Dialect notes
| | PostgreSQL | MySQL | SQL Server | Oracle |
|---|---|---|---|---|
| Concatenate | `a \|\| b` / `CONCAT` | `CONCAT(a,b)` (`\|\|` is OR by default!) | `a + b` / `CONCAT` | `a \|\| b` |
| First row per group | `DISTINCT ON` | window function | window function | window function |
| SELECT without FROM | ✅ | ✅ | ✅ | `FROM dual` |
