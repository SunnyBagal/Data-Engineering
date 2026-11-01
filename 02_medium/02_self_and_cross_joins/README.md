# 02 · Self Joins & Cross Joins

## Self join
A **self join** joins a table **to itself**, using two different aliases so SQL treats them as two copies.

```sql
SELECT e.first_name AS employee, m.first_name AS manager
FROM employees e                         -- copy 1: the employee
LEFT JOIN employees m                    -- copy 2: the manager
       ON m.emp_id = e.manager_id;
```

### When you need it
| Situation | Example |
|---|---|
| **Hierarchies** (a row points to a parent row in the same table) | employee → manager, category → parent category, customer → referrer |
| **Comparing rows of the same table** | employees earning more than their manager; products priced within $20 of each other |
| **Pairs / duplicates** | customers living in the same city; possible duplicate accounts with similar emails |
| **Sequences** (before window functions existed) | this order vs the previous order of the same customer |

### Rules of thumb
- **Aliases are mandatory** and should say what each copy *means* (`e`/`m`, `child`/`parent`), not `a`/`b`.
- Use **LEFT JOIN** for hierarchies, or the root (CEO, top category) disappears.
- For **unordered pairs**, use `a.id < b.id`: excludes self-pairs (`a = a`) and mirrored duplicates
  (`(1,13)` and `(13,1)`). `a.id <> b.id` gives each pair twice.
- One self join = one level of hierarchy. For **arbitrary depth** use a recursive CTE (03_hard/03).

## Cross join
A **CROSS JOIN** returns the **Cartesian product**: every row of A combined with every row of B.
`|A| × |B|` rows, no join condition.

```sql
SELECT s.size, c.color
FROM (VALUES ('S'),('M'),('L')) s(size)
CROSS JOIN (VALUES ('red'),('blue')) c(color);   -- 3 × 2 = 6 rows
```

### When you need it
| Use case | Example |
|---|---|
| **Report grids / scaffolding** | every (year × payment method) so missing combinations show 0 |
| **Generating combinations** | all product variants (size × color), test data |
| **Applying one row to all rows** | `CROSS JOIN (SELECT AVG(price) AS avg_price FROM products) a` → compare each row with a global value |
| **Calendars × entities** | every day × every store for daily sales including zero days |

### Dangers
- Row count explodes: 10 000 × 10 000 = 100 million rows.
- An **accidental** cross join happens when you forget the join condition
  (`FROM a, b` without `WHERE`, or `JOIN … ON TRUE`). Symptom: suspiciously huge numbers.

## Significance
Self joins unlock hierarchical and comparative questions without extra tables. Cross joins are how you
build **complete** reports — a dashboard that silently omits months with zero sales misleads people.

## Common mistakes
- INNER self join on a hierarchy → loses the top-level row.
- Pair queries returning each pair twice (`<>` instead of `<`).
- Comparing nullable columns with `=`/`<>` in self joins (NULL dept never equals anything) →
  use `IS DISTINCT FROM`.
- Cross joining two large tables by accident.
