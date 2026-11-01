# 09 · Indexes (Basics)

## What it is
An **index** is a separate data structure that lets the database find rows **without reading the whole
table** — like the index at the back of a book. Without one, finding `WHERE customer_id = 42` means
checking every row (**sequential scan**). With one, the database jumps almost directly to the matching rows.

```sql
CREATE INDEX idx_orders_customer ON orders (customer_id);
```

## How a B-tree index works
The default index type (B-tree) keeps the indexed values **sorted** in a balanced tree:
```
                [ 50 | 100 ]                      root
        ┌────────────┼─────────────┐
   [10|20|30]   [60|70|80]   [120|150|180]        internal pages
      ↓   ↓        ↓             ↓
   leaf pages: value → pointer to the table row (ctid)
```
- Lookup cost grows with the **depth** (~3–4 levels for millions of rows) → *O(log n)* instead of *O(n)*.
- Because values are sorted, B-trees help with `=`, `<`, `>`, `BETWEEN`, `IN`, `LIKE 'abc%'`,
  `ORDER BY`, `MIN/MAX`, and joins.

## What indexes speed up
| Operation | Helps? |
|---|---|
| `WHERE col = x` (selective) | ✅ big win |
| Range `WHERE col BETWEEN a AND b` | ✅ |
| `ORDER BY col LIMIT n` | ✅ reads in order, stops early |
| `JOIN … ON a.col = b.col` | ✅ (nested loop with index lookups) |
| `WHERE col LIKE 'abc%'` | ✅ (with `text_pattern_ops` or C collation) |
| `WHERE col LIKE '%abc'` | ❌ (needs a trigram GIN index, 03_hard/06) |
| `WHERE LOWER(col) = …` | ❌ unless an **expression index** on `LOWER(col)` |
| `WHERE col = x` matching 60% of rows | ❌ planner prefers a seq scan |

## The cost of indexes
Indexes are **not free**:
- Every `INSERT`, `DELETE` and most `UPDATE`s must also update **every index** → slower writes.
- They take **disk and memory** (often 20–50% of the table size each).
- The planner has more options to consider.
> Index for your **actual query patterns**, not "every column just in case".

## Composite (multi-column) indexes
`CREATE INDEX ON orders (customer_id, order_date)` is sorted by customer, then by date within a customer.
It can serve:
- `WHERE customer_id = 1` ✅ (leftmost column)
- `WHERE customer_id = 1 AND order_date > '2025-01-01'` ✅
- `WHERE customer_id = 1 ORDER BY order_date DESC LIMIT 5` ✅ (no sort needed)
- `WHERE order_date > '2025-01-01'` ❌ (mostly — skips the leftmost column)

**Column order rule:** equality-filtered columns first, then range/sort columns.

## Unique indexes
`PRIMARY KEY` and `UNIQUE` constraints automatically create unique B-tree indexes.
`CREATE UNIQUE INDEX` does the same without a named constraint and supports expressions/partial
conditions (03_hard/06).

## When does the planner use an index?
The **cost-based optimizer** estimates the cost of each plan using **statistics** (row counts, value
distribution, collected by `ANALYZE`/autovacuum):
- **High selectivity** (few matching rows) → index scan.
- **Low selectivity** (many rows) → sequential scan is cheaper (sequential I/O beats random I/O).
- **Tiny tables** (like our practice DB) → seq scan always wins; that's expected, not a problem.

Read plans with `EXPLAIN` (estimates) and `EXPLAIN ANALYZE` (actually runs it). Deep dive: 03_hard/05.

## Scan types you'll see in EXPLAIN
| Node | Meaning |
|---|---|
| `Seq Scan` | read the whole table |
| `Index Scan` | walk the index, fetch each matching row from the table |
| `Index Only Scan` | answer from the index alone (all needed columns are in it) |
| `Bitmap Index Scan` + `Bitmap Heap Scan` | collect many matches from the index, then read table pages in order |

## Significance & use cases
Indexes are the #1 lever for query performance: a missing index can turn a 2 ms query into a 20 s one
as data grows. Typical candidates:
- foreign-key columns used in joins (Postgres doesn't index them automatically!),
- columns in frequent `WHERE` filters (status, created_at, email),
- columns used for sorting with `LIMIT` (feeds, latest N),
- uniqueness rules (emails, usernames).

## Operations
```sql
CREATE INDEX CONCURRENTLY idx ON t (col);  -- production: doesn't block writes (can't run in a transaction)
DROP INDEX CONCURRENTLY idx;
REINDEX INDEX idx;                         -- rebuild a bloated index
SELECT * FROM pg_indexes WHERE tablename = 't';
SELECT pg_size_pretty(pg_relation_size('idx'));
```
Find unused indexes: `pg_stat_user_indexes.idx_scan = 0` over a long period.

## Common mistakes
- Indexing every column (slows writes, wastes memory).
- Wrong column order in composite indexes.
- Wrapping indexed columns in functions or casts in `WHERE`.
- Comparing with a different type (`WHERE text_col = 123`) → implicit cast, no index.
- Expecting an index to be used on a 20-row table.
- Forgetting to index FK columns → slow joins and slow parent deletes.
