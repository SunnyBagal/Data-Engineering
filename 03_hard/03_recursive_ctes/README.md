# 03 · Recursive CTEs

## What it is
A **recursive CTE** (`WITH RECURSIVE`) is a CTE that **refers to itself**. It repeatedly applies a query
to its own previous output until no new rows appear. This lets plain SQL walk **hierarchies and graphs
of unknown depth** — org charts, category trees, bills of materials, referral chains, routes.

```sql
WITH RECURSIVE chain AS (
    -- 1) ANCHOR: the starting row(s)
    SELECT emp_id, first_name, manager_id, 1 AS level
    FROM employees
    WHERE manager_id IS NULL
  UNION ALL
    -- 2) RECURSIVE MEMBER: join the table to the rows found in the previous step
    SELECT e.emp_id, e.first_name, e.manager_id, c.level + 1
    FROM employees e
    JOIN chain c ON e.manager_id = c.emp_id
)
SELECT * FROM chain;
```

## How it executes
```
working_table = anchor result                 (level 1: the CEO)
result        = working_table
loop:
    new_rows = recursive member run against working_table only   (level 2, then 3, …)
    if new_rows is empty: stop
    result += new_rows ; working_table = new_rows
```
Each iteration only sees the rows produced by the **previous** iteration — that's why it walks one
level at a time.

## Directions
| Goal | Anchor | Join in recursive part |
|---|---|---|
| **Down** (all subordinates / descendants) | the starting node | `child.parent_id = cte.id` |
| **Up** (management chain / ancestors) | the starting node | `parent.id = cte.parent_id` |

## Useful things to carry along
- **Depth/level**: `cte.level + 1`
- **Path**: `cte.path || ' > ' || child.name` (text) or `cte.path || child.id` (array) — great for display and sorting.
- **Root id**: carry the anchor's id down to group all descendants by their top-level ancestor.

## Termination & cycles
Recursion stops when an iteration returns no rows. If the data has a **cycle** (A → B → A), it never stops.
Protections:
- `UNION` instead of `UNION ALL` (stops when rows repeat exactly — only works if you don't carry
  changing columns like depth).
- Track visited ids in an array and stop: `WHERE NOT child.id = ANY(cte.path)`.
- Postgres 14+: `CYCLE id SET is_cycle USING path` clause.
- A depth limit: `WHERE cte.level < 20`.

## Other uses (not just trees)
- **Generate series** (numbers, dates) in databases without `generate_series`.
- **Graph traversal**: all destinations reachable from an airport, shortest number of hops.
- **Running computations** that depend on the previous row's *computed* result (e.g. compound interest,
  inventory with reorder rules) — things windows can't express.
- Splitting strings, parsing.

## Significance
Hierarchies are everywhere (orgs, categories, comments/replies, file systems, accounts in a ledger,
parts in a product). Without recursion you'd need one self-join per level and a fixed maximum depth.

## Performance
- Index the parent column (`manager_id`, `parent_id`) — every iteration joins on it.
- Filter early in the anchor (start from one node instead of all).
- For very deep/large graphs, consider specialised models: **materialized path** (`'1/2/5/'`),
  **nested sets**, **closure tables**, Postgres `ltree`, or a graph database.

## Common mistakes
- Forgetting the keyword `RECURSIVE`.
- Joining in the wrong direction (walking up when you wanted down).
- Infinite loops on cyclic data.
- Type mismatch between anchor and recursive member (e.g. `'a'` text vs varchar path) →
  cast the anchor column explicitly (`name::text`).
- Using aggregates/`LIMIT`/`ORDER BY` inside the recursive member (not allowed).

## Dialect notes
`WITH RECURSIVE` in PostgreSQL, MySQL 8+, SQLite. SQL Server and Oracle use plain `WITH` (no keyword).
Oracle also has the legacy `CONNECT BY PRIOR` syntax.
