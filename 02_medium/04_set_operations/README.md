# 04 · Set Operations — UNION, INTERSECT, EXCEPT

## What it is
Set operators combine the **results of two queries vertically** (stacking rows), whereas joins combine
tables **horizontally** (adding columns).

| Operator | Returns | Duplicates |
|---|---|---|
| `UNION` | rows in A **or** B | removed |
| `UNION ALL` | all rows of A followed by all rows of B | **kept** (fastest) |
| `INTERSECT` | rows in **both** A and B | removed |
| `INTERSECT ALL` | rows in both, keeping min(count in A, count in B) copies | kept |
| `EXCEPT` | rows in A **but not** in B (Oracle: `MINUS`) | removed |
| `EXCEPT ALL` | multiset difference | kept |

```
  A ∪ B (UNION)        A ∩ B (INTERSECT)      A − B (EXCEPT)
   (███(███)███)         (   (███)   )          (███(   )   )
```

## Rules
1. Both queries must return the **same number of columns**.
2. Corresponding columns must have **compatible types** (matched by **position**, not by name!).
3. Output column **names come from the first query**.
4. `ORDER BY` / `LIMIT` apply to the **whole** combined result and go at the very end.
   To sort/limit an individual branch, wrap it in parentheses or a subquery.
5. Precedence: `INTERSECT` binds tighter than `UNION`/`EXCEPT`; use parentheses when mixing.
6. Set operators compare whole rows, and treat **NULLs as equal** (unlike `=`) — like DISTINCT does.

## UNION vs UNION ALL
`UNION` must sort or hash the entire result to remove duplicates. If you **know** the branches can't
overlap (e.g. they carry different type labels) or you **want** duplicates, use `UNION ALL` —
it's cheaper and never surprises you by silently dropping legitimately identical rows.
> Default to `UNION ALL`; use `UNION` only when you specifically need de-duplication.

## Set operators vs joins/subqueries
| Question | Set operator | Alternative |
|---|---|---|
| customers who ordered in 2023 **and** 2024 | `INTERSECT` | `EXISTS` + `EXISTS` |
| customers in 2023 **but not** 2024 | `EXCEPT` | `NOT EXISTS` |
| combine two similar tables | `UNION ALL` | — (no alternative) |

`INTERSECT`/`EXCEPT` work on **whole rows**, so they're perfect when you compare a few key columns.
When you also need other columns, use them on the keys, then join back — or use EXISTS.

## Significance & use cases
- **Combining sources**: customers from two regional databases, current + archived orders,
  contacts from customers + employees + suppliers.
- **Reconciliation / data quality**: rows in source but not in target (`EXCEPT` both ways) — the
  standard test after a migration or ETL load.
- **Cohorts**: retained users (`INTERSECT` between periods), churned users (`EXCEPT`).
- **Reports with total rows**: detail rows `UNION ALL` a summary row (see also ROLLUP, 03_hard/04).

## Common mistakes
- Columns in a different order in each branch → values land in the wrong column silently
  (types may still be compatible, e.g. two text columns).
- Using `UNION` and losing legitimate duplicate rows (two identical payments).
- Trying to `ORDER BY` inside a branch without parentheses.
- Forgetting that the first query decides column names and (often) types.

## Dialect notes
- Oracle uses `MINUS` instead of `EXCEPT`.
- MySQL supports `INTERSECT` and `EXCEPT` only from **8.0.31**.
- `INTERSECT ALL` / `EXCEPT ALL` aren't supported in SQL Server.
