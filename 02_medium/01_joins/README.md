# 01 · Joins — INNER, LEFT, RIGHT, FULL

## What it is
A **join** combines rows from two tables into wider rows, by matching a condition (usually FK = PK).
Normalization (02_medium/11) splits data into many tables to avoid duplication; joins put it back together
at query time.

```sql
SELECT o.order_id, c.first_name
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id;
```

## Join types
Picture `customers` (left) and `orders` (right):

```
 INNER JOIN         LEFT JOIN          RIGHT JOIN         FULL OUTER JOIN
   ( L (█) R )      (█L█(█) R )        ( L (█)█R█)        (█L█(█)█R█)
 only matches       all left rows      all right rows     all rows from both
                    + matches          + matches          + matches
```

| Type | Returns | Unmatched rows |
|---|---|---|
| `[INNER] JOIN` | rows with a match on both sides | dropped |
| `LEFT [OUTER] JOIN` | every left row + matching right rows | right columns = NULL |
| `RIGHT [OUTER] JOIN` | every right row + matching left rows | left columns = NULL |
| `FULL [OUTER] JOIN` | every row from both sides | missing side = NULL |
| `CROSS JOIN` | every combination (02_medium/02) | — |

`RIGHT JOIN` is just a `LEFT JOIN` with the tables swapped — most teams write only LEFT joins for readability.

## How a join "works" (mental model)
1. Take every pair (left row, right row).
2. Keep pairs where the `ON` condition is TRUE.
3. For outer joins, add back unmatched rows padded with NULLs.

(The database never really builds every pair — it uses **nested loop**, **hash** or **merge** join
algorithms; see 03_hard/05.)

## Cardinality: how many rows come out?
- **1:1** join → same number of rows.
- **1:N** join (customer → orders) → one row **per order**; customer columns repeat.
- **Two 1:N joins from the same parent** (order → items, order → payments) → rows **multiply** (fan-out):
  an order with 2 items and 2 payments gives 4 rows, and `SUM(amount)` counts each payment twice.
  **Fix:** aggregate each child table separately first, then join the aggregates.

## ON vs WHERE in outer joins (crucial)
```sql
-- Keeps ALL customers; attaches only their cancelled orders (others get NULLs)
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'cancelled'

-- Turns the LEFT JOIN into an INNER JOIN: customers without a cancelled order are removed,
-- because o.status is NULL for them and NULL = 'cancelled' is not TRUE
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status = 'cancelled'
```
Rule: conditions on the **optional (right) table** of a LEFT JOIN go in `ON` if you want to keep
all left rows. `WHERE` filters the final result.

## Anti-join & semi-join patterns
- **Anti-join** ("customers with NO orders"): `LEFT JOIN … WHERE o.order_id IS NULL`
  (or `NOT EXISTS`, 02_medium/03).
- **Semi-join** ("customers with at least one order", without duplicating them): `EXISTS`, not a join + DISTINCT.

## Syntax variants
- `JOIN … USING (customer_id)` — when the column has the same name on both sides; outputs it once.
- `NATURAL JOIN` — joins on **all** same-named columns automatically. **Avoid**: adding a column like
  `created_at` to both tables silently changes the join.
- Old comma syntax `FROM a, b WHERE a.id = b.a_id` — works (inner join only), but forgetting the WHERE
  produces a cartesian product. Use explicit `JOIN`.

## Significance
Real questions almost always span tables: "revenue **by category**" needs order_items + products +
categories. Joins are the most important skill after basic SELECT — and join bugs (fan-out,
lost rows) are the most common source of wrong numbers in reports.

## Use cases
- Enrich facts with dimensions (orders + customers + products) — the core of BI / star schemas.
- Find missing relationships (products never sold, customers never ordered).
- Reconcile two systems (FULL JOIN on id, look for NULLs on either side).
- Fill gaps in time series (calendar LEFT JOIN facts).

## Performance
- Index the join columns (especially FKs on the "many" side).
- Join on columns of the **same type** — implicit casts can prevent index use.
- Filter early (WHERE on base tables) so fewer rows are joined.

## Common mistakes
- Fan-out → inflated SUM/COUNT. Check row counts before and after each join.
- WHERE on the right table of a LEFT JOIN (accidental inner join).
- `COUNT(*)` with a LEFT JOIN counts the NULL-padded row as 1 → use `COUNT(right.id)`.
- Joining on the wrong column (`o.employee_id = c.customer_id` runs fine and returns garbage).
- Ambiguous column names → always prefix columns with table aliases in joins.
