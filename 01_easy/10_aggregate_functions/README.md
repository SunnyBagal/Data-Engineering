# 10 · Aggregate Functions

## What they are
An **aggregate function** takes many rows and returns **one value**: a count, a sum, an average…
Without `GROUP BY` (topic 11), the whole result set is one group → one output row.

| Function | Returns | NULLs |
|---|---|---|
| `COUNT(*)` | number of rows | counted |
| `COUNT(col)` | number of non-NULL values | ignored |
| `COUNT(DISTINCT col)` | number of different non-NULL values | ignored |
| `SUM(col)` | total | ignored; **SUM of zero rows is NULL**, not 0 |
| `AVG(col)` | arithmetic mean | ignored (not treated as 0!) |
| `MIN(col)` / `MAX(col)` | smallest / largest (works on numbers, text, dates) | ignored |
| `STRING_AGG(col, sep ORDER BY …)` | values joined into one string | ignored |
| `ARRAY_AGG(col ORDER BY …)` | values collected into an array | **kept** |
| `BOOL_AND` / `BOOL_OR` | TRUE if all / any are TRUE | ignored |
| `STDDEV`, `VARIANCE` | statistical spread | ignored |
| `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY col)` | median (interpolated) | ignored |
| `MODE() WITHIN GROUP (ORDER BY col)` | most frequent value | ignored |

## How it works
```sql
SELECT COUNT(*)              AS orders,
       MIN(order_date)       AS first_order,
       MAX(order_date)       AS last_order
FROM orders
WHERE status = 'delivered';   -- WHERE filters rows BEFORE they are aggregated
```
1. `FROM` + `WHERE` produce the input rows.
2. Each aggregate consumes all those rows.
3. One row comes out.

### The FILTER clause (standard SQL, Postgres 9.4+)
Aggregate only a subset of rows, several different subsets in one pass:
```sql
SELECT COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE status = 'delivered') AS delivered
FROM orders;
```
Other databases: `SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END)` (02_medium/12).

## Rules
- **You cannot mix aggregates with plain columns** without `GROUP BY`:
  `SELECT customer_id, COUNT(*) FROM orders` → error (which customer_id would it show for 46 rows?).
- **Aggregates are not allowed in `WHERE`** (WHERE runs before aggregation) → use `HAVING` (topic 11)
  or a subquery.
- Aggregates can be **nested in expressions**: `SUM(price) / COUNT(*)`, `ROUND(AVG(x), 2)`,
  `MAX(x) - MIN(x)`.
- They **can't be nested in each other** directly: `AVG(SUM(x))` → use a subquery/CTE.

## Significance
Aggregation turns data into **information**: revenue, active users, average order value, conversion rate.
Every dashboard and KPI is an aggregate. Data engineers spend much of their time building
pre-aggregated tables for fast reporting.

## Use cases
| Question | Aggregate |
|---|---|
| How many customers do we have? | `COUNT(*)` |
| How many customers ordered at least once? | `COUNT(DISTINCT customer_id)` on orders |
| Total revenue? | `SUM(quantity * unit_price * (1 - discount))` |
| Average order value (AOV)? | total revenue / number of orders |
| First and last sale? | `MIN`/`MAX(order_date)` |
| Median salary (robust to outliers)? | `PERCENTILE_CONT(0.5)` |
| Comma-separated list of tags? | `STRING_AGG` |

## Average vs median
The CEO's 250k salary pulls the **average** up; the **median** (middle value) is robust to outliers.
Report the median for "typical" values (salaries, house prices, response times), the average for totals
that need to add up (revenue per order × orders = revenue).

## Common mistakes
- Expecting `SUM` over no rows to be 0 — it's `NULL`. Wrap: `COALESCE(SUM(x), 0)`.
- `AVG(col)` vs `SUM(col)/COUNT(*)` differ when NULLs exist (topic 08).
- `COUNT(col)` when you meant `COUNT(*)` (silently skips NULLs).
- Integer averages: in Postgres `AVG(int)` returns numeric (fine), but `SUM(int)/COUNT(*)` is integer division.
- `COUNT(DISTINCT a, b)` isn't valid in Postgres → `COUNT(DISTINCT (a, b))`.
- Aggregating after a bad join that duplicated rows → inflated sums (02_medium/01).

## Dialect notes
| | PostgreSQL | MySQL | SQL Server | Oracle |
|---|---|---|---|---|
| String aggregation | `STRING_AGG` | `GROUP_CONCAT` | `STRING_AGG` (2017+) | `LISTAGG` |
| FILTER clause | ✅ | ❌ | ❌ | ❌ |
| Median | `PERCENTILE_CONT` | ❌ (window trick) | `PERCENTILE_CONT` (window form) | `MEDIAN()` |
| `AVG(int)` result | numeric | decimal | **int** (truncated!) | number |
