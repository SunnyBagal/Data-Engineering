# 09 · ORDER BY & LIMIT — Sorting and Pagination

## What it is
- `ORDER BY` sorts the result rows.
- `LIMIT n` / `FETCH FIRST n ROWS ONLY` returns only the first *n* rows.
- `OFFSET k` skips the first *k* rows.

```sql
SELECT …
FROM …
WHERE …
ORDER BY col1 [ASC|DESC] [NULLS FIRST|LAST], col2 …
LIMIT n OFFSET k;                        -- Postgres / MySQL / SQLite
-- standard SQL:  OFFSET k ROWS FETCH FIRST n ROWS ONLY
```

## The most important fact
> **Without `ORDER BY`, row order is undefined.** The database may return rows in insertion order today
> and in a different order tomorrow (after an update, a parallel scan, a new index, a version upgrade).

So `LIMIT` without `ORDER BY` returns "some n rows", not "the first n rows".

## How ORDER BY works
- Default direction is `ASC` (smallest first). `DESC` reverses **per column**: `ORDER BY a DESC, b` = a descending, b ascending.
- Multiple sort keys: ties on the first key are broken by the second, and so on.
- You can sort by: a column, an **expression** (`price - cost`), an **alias** from SELECT,
  or a **column position** (`ORDER BY 2` — avoid in real code; it breaks silently when the SELECT list changes).
- You can sort by a column you don't select (except with `DISTINCT`).
- **NULLs:** Postgres/Oracle treat NULL as larger than any value (last in ASC, first in DESC).
  MySQL/SQL Server treat it as smaller. Be explicit with `NULLS FIRST` / `NULLS LAST`.
- Text order depends on **collation** (`'a' < 'B'`? depends). Use `COLLATE "C"` for byte order.

## Deterministic ordering
If the sort key has ties, the order **among tied rows is random**. With pagination this causes rows
to appear on two pages or on none. Always add a unique **tie-breaker** (usually the PK):
```sql
ORDER BY price DESC, product_id
```

## FETCH … WITH TIES
`FETCH FIRST 3 ROWS WITH TIES` returns the first 3 rows **plus any rows tied with the 3rd** —
"top 3 salaries" without arbitrarily cutting off someone who earns the same.

## Pagination: OFFSET vs keyset
| | OFFSET pagination | Keyset (seek) pagination |
|---|---|---|
| Query | `ORDER BY id LIMIT 20 OFFSET 10000` | `WHERE id > :last_seen_id ORDER BY id LIMIT 20` |
| Cost | reads & throws away 10 000 rows — gets slower every page | uses an index to jump straight there — constant speed |
| Rows inserted/deleted while browsing | items shift → duplicates / gaps | stable |
| Jump to page 57 | easy | not possible (only next/prev) |
| Use for | admin tables, small data | infinite scroll, APIs, large tables |

Keyset with a non-unique sort key uses a **row-value comparison**:
`WHERE (order_date, order_id) > ('2024-07-01 08:15', 28) ORDER BY order_date, order_id LIMIT 10`.

## Significance & use cases
- Top-N reports: "10 best-selling products", "3 most recent orders".
- Leaderboards, feeds, search results.
- API pagination.
- Finding extremes with the row attached (the *row* of the max, not just the max value).

## Performance notes
- Sorting large results is expensive (memory → disk spill). An index on the sort columns lets the
  database read rows **already in order** and stop after `LIMIT` rows ("top-N heapsort" or index scan).
- `ORDER BY random() LIMIT 1` sorts the whole table — fine for small tables only; use `TABLESAMPLE` for big ones.

## Common mistakes
- Relying on "natural" order without `ORDER BY`.
- Pagination without a unique tie-breaker.
- `ORDER BY 1, 2` positional references breaking after a refactor.
- Expecting text numbers to sort numerically (`'10' < '9'`).
- Forgetting MySQL/SQL Server put NULLs first in ASC.

## Dialect notes
| | PostgreSQL | MySQL | SQL Server | Oracle |
|---|---|---|---|---|
| First n rows | `LIMIT n` / `FETCH FIRST` | `LIMIT n` | `TOP n` / `OFFSET 0 ROWS FETCH NEXT n ROWS ONLY` | `FETCH FIRST n ROWS ONLY` (12c+) |
| WITH TIES | `FETCH … WITH TIES` (13+) | ❌ | `TOP n WITH TIES` | `FETCH … WITH TIES` |
| NULLS FIRST/LAST | ✅ | ❌ (use `ORDER BY col IS NULL, col`) | ❌ (use CASE) | ✅ |
