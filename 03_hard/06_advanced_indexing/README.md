# 06 · Advanced Indexing

Builds on 02_medium/09 (B-tree basics) and 03_hard/05 (reading plans).

## 1. Composite indexes — the rules that matter
`CREATE INDEX ON orders (customer_id, status, order_date)`
- Usable for any **leftmost prefix**: `(customer_id)`, `(customer_id, status)`, all three.
- Put **equality** columns first, then the **range / ORDER BY** column.
- One good composite index often replaces several single-column ones (and is smaller in total).
- Postgres can also combine separate indexes with `BitmapAnd`/`BitmapOr`, but a matching composite is faster.

## 2. Covering indexes (`INCLUDE`) → index-only scans
```sql
CREATE INDEX ON orders (customer_id) INCLUDE (order_date, status);
```
`INCLUDE` columns are stored in the leaf pages but are **not part of the key** (not sorted, not searchable).
A query that needs only key + included columns can be answered from the index alone
(**Index Only Scan**), skipping the table. Requires a reasonably up-to-date **visibility map** (VACUUM).

## 3. Partial indexes — index only the rows you query
```sql
CREATE INDEX ON orders (order_date) WHERE status IN ('pending', 'shipped');
CREATE UNIQUE INDEX ON subscriptions (user_id) WHERE is_active;   -- max ONE active row per user
```
- Much smaller and cheaper to maintain when queries always target a small subset (open orders, unprocessed jobs, non-deleted rows).
- The query's `WHERE` must **imply** the index predicate for the planner to use it.
- **Partial UNIQUE** indexes express rules that constraints can't: "unique among active rows only".

## 4. Expression (functional) indexes
```sql
CREATE INDEX ON customers (LOWER(email));          -- WHERE LOWER(email) = 'x@y.com'
CREATE INDEX ON orders ((order_date::date));        -- WHERE order_date::date = '2025-01-01'
CREATE INDEX ON products ((attributes ->> 'brand'));-- WHERE attributes->>'brand' = 'Lumen'
```
- The query must use **exactly the same expression**.
- Functions must be `IMMUTABLE` (same input → same output forever).
- Makes "non-sargable" predicates indexable; also enables case-insensitive UNIQUE: `CREATE UNIQUE INDEX ON users (LOWER(email))`.

## 5. Index types beyond B-tree (PostgreSQL)
| Type | Good for | Example |
|---|---|---|
| **B-tree** (default) | `= < > BETWEEN`, sorting, `LIKE 'abc%'` | almost everything |
| **Hash** | `=` only | rarely better than B-tree |
| **GIN** (Generalized Inverted) | "contains" on multi-valued data: `jsonb @>`, arrays `@>`/`&&`, full-text `@@`, trigrams | `CREATE INDEX ON products USING gin (attributes)` |
| **GiST** | geometric/range types, nearest-neighbour, exclusion constraints | `EXCLUDE USING gist (room WITH =, during WITH &&)` |
| **SP-GiST** | non-balanced structures (quad-trees, IP ranges) | |
| **BRIN** (Block Range) | huge tables where values follow physical order (append-only time series) | `CREATE INDEX ON events USING brin (created_at)` — kilobytes instead of gigabytes |

### Trigram indexes for `LIKE '%text%'`
B-trees can't help with a leading wildcard. The `pg_trgm` extension + a GIN index can:
```sql
CREATE EXTENSION pg_trgm;
CREATE INDEX ON products USING gin (product_name gin_trgm_ops);
SELECT * FROM products WHERE product_name ILIKE '%phone%';   -- index-assisted
```
Also enables fuzzy search: `similarity(a, b)`, `a % b`.

## 6. Index maintenance & operations
| Task | Command |
|---|---|
| Build without blocking writes | `CREATE INDEX CONCURRENTLY …` (slower; not inside a transaction) |
| Rebuild a bloated index | `REINDEX INDEX CONCURRENTLY idx;` (PG 12+) |
| Find unused indexes | `pg_stat_user_indexes` where `idx_scan = 0` |
| Index sizes | `pg_relation_size(idx)`, `pg_indexes_size(table)` |
| Find duplicate indexes | same table + same column list in `pg_index` |

Every index slows writes and uses RAM. Audit periodically: drop unused and redundant ones.

## Significance
Advanced index types let one database serve workloads that would otherwise need extra systems:
JSON document search (GIN), fuzzy text search (trigram), time-series (BRIN), business rules (partial unique,
exclusion constraints). Picking the right index is often a 100–1000× improvement.

## Common mistakes
- Expression in the query differs slightly from the index expression (`lower(email)` vs `LOWER(TRIM(email))`).
- Partial index predicate not implied by the query (`WHERE status = $1` with a parameter can't prove it).
- GIN on a JSONB column queried with `->>` equality (needs an expression B-tree; GIN serves `@>`, `?`).
- BRIN on randomly ordered data (useless).
- Too many indexes on write-heavy tables.
