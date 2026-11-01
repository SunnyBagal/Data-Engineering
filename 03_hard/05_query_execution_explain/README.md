# 05 · Query Execution & EXPLAIN — How the Database Runs Your SQL

## The journey of a query
```
SQL text → Parser (syntax) → Analyzer (names, types) → Rewriter (views, rules)
         → Planner/Optimizer (choose the cheapest plan) → Executor (run the plan) → rows
```
SQL is **declarative**: you say *what*; the **planner** decides *how*: which indexes, which join order,
which join algorithm, whether to sort or hash. Understanding its choices is how you tune queries.

## Cost-based optimization
The planner enumerates candidate plans and estimates each one's **cost** (abstract units ≈ disk page
reads + CPU work) using **statistics** about the data:
- row count per table (`pg_class.reltuples`),
- per column: NULL fraction, number of distinct values, most common values, histogram (`pg_stats`).

Statistics are refreshed by `ANALYZE` (autovacuum runs it automatically). **Bad statistics → bad
row estimates → bad plans.** The #1 thing to check in a slow plan: *estimated rows vs actual rows*.

## EXPLAIN
| Command | Does |
|---|---|
| `EXPLAIN query` | shows the chosen plan with **estimates** (does not run it) |
| `EXPLAIN ANALYZE query` | **runs** the query, adds actual rows/time per node (careful with UPDATE/DELETE — wrap in a transaction and ROLLBACK) |
| `EXPLAIN (ANALYZE, BUFFERS)` | + pages read from cache (`shared hit`) vs disk (`read`) |
| `EXPLAIN (FORMAT JSON)` | machine-readable; paste into visualizers (explain.dalibo.com, pev2) |

### Reading a plan
```
Hash Join  (cost=1.45..30.12 rows=78 width=40) (actual time=0.05..0.21 rows=78 loops=1)
  Hash Cond: (oi.order_id = o.order_id)
  ->  Seq Scan on order_items oi  (cost=0.00..1.78 rows=78 …)
  ->  Hash  (cost=1.46..1.46 rows=46 …)
        ->  Seq Scan on orders o  (…)
```
- It's a **tree**; read it **inside-out / bottom-up**: children produce rows for their parent.
- `cost=startup..total` — cost before the first row / for all rows.
- `rows` = estimated rows output; `actual … rows` = real; `loops` = times the node ran
  (multiply actual rows/time by loops for nested loops).
- `width` = average row size in bytes.

## Scan nodes
| Node | When chosen |
|---|---|
| `Seq Scan` | no useful index, or a large fraction of the table is needed |
| `Index Scan` | few rows via index, then fetch from table |
| `Index Only Scan` | all needed columns are in the index (and pages are all-visible) |
| `Bitmap Index Scan` → `Bitmap Heap Scan` | medium selectivity, or combining several indexes (`BitmapAnd/Or`) |

## Join algorithms
| Algorithm | How | Best when |
|---|---|---|
| **Nested Loop** | for each outer row, look up matching inner rows (ideally via index) | outer side small, inner side indexed |
| **Hash Join** | build a hash table on the smaller input, probe with the larger | big unsorted inputs, equality joins |
| **Merge Join** | both inputs sorted on the key, walk them together | inputs already sorted (indexes) or very large |

## Other common nodes
`Sort` (watch for `Sort Method: external merge Disk:` = spilled to disk, raise `work_mem` or add an index),
`HashAggregate` / `GroupAggregate`, `Limit`, `Gather` (parallel workers), `Materialize`, `Memoize`,
`SubPlan` (a correlated subquery executed per row — often a red flag).

## Tuning checklist
1. **Measure**: `EXPLAIN (ANALYZE, BUFFERS)`; in production, find the worst queries with `pg_stat_statements`.
2. **Estimates vs actual** off by 10×+? → `ANALYZE`, raise statistics target, extended statistics for correlated columns.
3. **Big Seq Scan with a selective filter?** → missing index (or a non-sargable predicate: function on column, type mismatch, leading `%`).
4. **Nested loop with many loops on a big inner table?** → index on the inner join key.
5. **Sort/Hash spilling to disk?** → `work_mem` (per operation!), or avoid the sort with an index.
6. **SubPlan per row?** → rewrite correlated subquery as JOIN / EXISTS / window function.
7. **Fetching too much?** → select fewer columns (enables index-only scans), filter earlier, paginate with keyset.
8. Re-measure. Change one thing at a time.

## Significance
Performance problems are usually **one bad plan**, not "the database is slow". Reading EXPLAIN turns
guessing into engineering — it's a core senior-level skill for backend and data engineers.

## Common mistakes
- Tuning with `EXPLAIN` alone (estimates) instead of `EXPLAIN ANALYZE` (reality).
- Testing on tiny dev data where every plan is a seq scan.
- Running `EXPLAIN ANALYZE` on a DELETE outside a transaction (it really deletes!).
- Adding indexes without checking the plan uses them.
- Forcing plans with `enable_seqscan = off` in production (it's a diagnostic tool, not a fix).
