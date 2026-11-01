# 11 · GROUP BY & HAVING

## What it is
- `GROUP BY` splits rows into **groups** that share the same value(s), then aggregates **each group**
  separately → one output row **per group**.
- `HAVING` filters **groups** (after aggregation), the way `WHERE` filters **rows** (before aggregation).

```sql
SELECT   country, COUNT(*) AS customers      -- one row per country
FROM     customers
WHERE    signup_date >= '2023-01-01'          -- 1. filter rows
GROUP BY country                              -- 2. form groups
HAVING   COUNT(*) >= 2                        -- 3. filter groups
ORDER BY customers DESC;                      -- 4. sort the result
```

## Logical query processing order (memorise this!)
```
1. FROM / JOIN      build the input rows
2. WHERE            keep rows that match             (no aggregates allowed)
3. GROUP BY         collapse rows into groups
4. HAVING           keep groups that match           (aggregates allowed)
5. SELECT           compute output columns & aliases
6. DISTINCT         remove duplicate output rows
7. ORDER BY         sort                             (aliases allowed)
8. LIMIT / OFFSET   cut
```
Consequences:
- `WHERE COUNT(*) > 1` → error (groups don't exist yet).
- `HAVING` can't use a SELECT alias in standard SQL (Postgres doesn't allow it either; MySQL does).
- `ORDER BY` can use aliases.

## The golden rule of GROUP BY
> Every column in `SELECT` must either be **in the GROUP BY** or **inside an aggregate function**.

Why: a group of 8 Indian customers has one country but 8 different first names — which one would SQL show?
Exception: if you group by a table's **primary key**, Postgres knows all other columns of that table are
functionally dependent and lets you select them (standard SQL:1999 feature).
(MySQL with `ONLY_FULL_GROUP_BY` disabled lets you break the rule and returns an arbitrary value — a bug source.)

## WHERE vs HAVING
| | WHERE | HAVING |
|---|---|---|
| Filters | individual rows | groups |
| Runs | before grouping | after grouping |
| Aggregates allowed | ❌ | ✅ |
| Performance | reduces work early ✅ | operates on already-grouped data |

**Rule:** a condition that doesn't need an aggregate belongs in `WHERE` — it's clearer and faster
(fewer rows to group).

## Grouping by expressions
You can group by any expression: `GROUP BY EXTRACT(YEAR FROM order_date)`,
`GROUP BY DATE_TRUNC('month', order_date)`, `GROUP BY price > 100`. The same expression (or its alias /
position, in Postgres) is then used in SELECT.

## Significance
`GROUP BY` is the engine of reporting: "revenue **per** month", "orders **per** customer",
"average salary **by** department". Most analytical questions contain the word *per* or *by* → `GROUP BY`.

## Use cases
- Time series: orders per day/month/year.
- Segmentation: customers per country, products per category.
- Data quality: `GROUP BY email HAVING COUNT(*) > 1` → find duplicates.
- Leaderboards: top sales reps by revenue.

## Performance
The database groups by **sorting** (then scanning neighbours) or by **hashing** (hash table of groups).
Grouping large tables is memory-intensive; filtering early with `WHERE` and grouping by narrow columns
(ids rather than long text) helps. Indexes on the grouping column can enable sorted grouping.

## Common mistakes
- Selecting a non-grouped, non-aggregated column → error (or random value in loose MySQL).
- Putting non-aggregate conditions in `HAVING` (works, but slower and confusing).
- `COUNT(*)` after a join counts joined rows, not entities → use `COUNT(DISTINCT id)`.
- Grouping by a name instead of an id: two customers named "John Smith" merge into one group.
- Forgetting that NULLs form their own group.

## Dialect notes
| | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| `GROUP BY 1` (position) | ✅ | ✅ | ❌ |
| `GROUP BY alias` | ✅ | ✅ | ❌ |
| Alias in HAVING | ❌ | ✅ | ❌ |
| Non-aggregated columns | error (except PK dependency) | allowed if ONLY_FULL_GROUP_BY off | error |
