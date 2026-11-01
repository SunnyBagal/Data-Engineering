# 03 · Subqueries

## What it is
A **subquery** is a `SELECT` nested inside another statement. Because every query returns a table,
a query's result can be used wherever a value, a list, or a table is expected.

| Kind | Returns | Where it's used | Example |
|---|---|---|---|
| **Scalar** | exactly 1 row × 1 column | anywhere a value fits: SELECT, WHERE, SET | `WHERE price > (SELECT AVG(price) FROM products)` |
| **Row/list** | 1 column, many rows | `IN`, `NOT IN`, `= ANY`, `> ALL` | `WHERE customer_id IN (SELECT customer_id FROM orders)` |
| **Table / derived table** | many rows × many columns | `FROM (…) AS alias`, `JOIN (…) AS alias` | `FROM (SELECT order_id, SUM(…) AS total …) t` |
| **EXISTS** | TRUE/FALSE | `WHERE [NOT] EXISTS (…)` | customers who have an order |

## Uncorrelated vs correlated
- **Uncorrelated**: independent of the outer query; runs once. `(SELECT AVG(price) FROM products)`
- **Correlated**: references the outer row, so conceptually it runs **once per outer row**:
  ```sql
  SELECT e.first_name, e.salary
  FROM employees e
  WHERE e.salary > (SELECT AVG(salary) FROM employees x WHERE x.dept_id = e.dept_id);
  --                                                               ^^^^^^^^^ outer reference
  ```
  Modern optimizers often rewrite correlated subqueries into joins, but not always — on large data,
  check the plan (03_hard/05) or rewrite with a join/window function (03_hard/02).

## EXISTS vs IN vs JOIN
| Need | Best tool | Why |
|---|---|---|
| "rows that have at least one match" | `EXISTS` (semi-join) | stops at first match; never duplicates outer rows |
| "rows that have no match" | `NOT EXISTS` (anti-join) | **NULL-safe**, unlike `NOT IN` |
| membership in a small fixed or computed list | `IN` | readable |
| need columns from the other table | `JOIN` | subqueries in WHERE can't return columns |

`SELECT 1` inside EXISTS is a convention — the select list is ignored; only "is there a row?" matters.

### The NOT IN trap (again)
`WHERE id NOT IN (SELECT ref FROM t)` returns **nothing** if `ref` contains a NULL. `NOT EXISTS` doesn't
have this problem. Default to `NOT EXISTS`.

## ANY / ALL
- `x > ANY (subquery)` — greater than at least one value (= greater than the MIN).
- `x > ALL (subquery)` — greater than every value (= greater than the MAX).
- `= ANY (…)` is the same as `IN (…)`; `<> ALL (…)` is `NOT IN` (with the same NULL trap).
- `x > ALL (empty set)` is **TRUE** — be careful.

## Derived tables (subqueries in FROM)
Use them to **aggregate first, then do something with the aggregates**: average order value
(sum per order, then average), avoiding fan-out (02_medium/01), filtering on window-function results.
Every derived table needs an **alias**. When they get big or nested, switch to **CTEs** (02_medium/06) —
same thing, far more readable.

## Scalar subquery rules
- Must return **at most one row** — otherwise: `ERROR: more than one row returned by a subquery used as an expression`.
- Zero rows → the value is **NULL**.

## Significance & use cases
- Compare each row against an aggregate (above average, the max per group).
- Filter by membership in another table (customers who bought laptops).
- Find missing relationships (`NOT EXISTS`).
- Multi-step calculations (aggregate of an aggregate) via derived tables.
- `UPDATE … SET x = (SELECT …)` and `DELETE … WHERE id IN (SELECT …)`.

## Common mistakes
- Scalar subquery returning more than one row.
- `NOT IN` with NULLs.
- Correlated subquery in SELECT for every row of a million-row table (N+1 problem inside the DB).
- Forgetting the alias on a derived table (`subquery in FROM must have an alias`).
- Using `IN (SELECT …)` + `DISTINCT` when you actually needed columns → use a JOIN.
