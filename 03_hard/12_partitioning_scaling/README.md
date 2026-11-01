# 12 · Partitioning, Materialized Views & Scaling

## Part 1 — Table partitioning

### What it is
**Partitioning** splits one large logical table into smaller physical tables (**partitions**) by the value
of a **partition key**. Queries and DML still target the parent table; Postgres routes rows to the right
partition and skips irrelevant ones.

```sql
CREATE TABLE events (id BIGINT, created_at TIMESTAMP NOT NULL, …) PARTITION BY RANGE (created_at);
CREATE TABLE events_2025_01 PARTITION OF events FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE events_default PARTITION OF events DEFAULT;   -- catches rows matching no partition
```

| Strategy | Key examples | Good for |
|---|---|---|
| `RANGE` | dates, ids | time series, logs, orders by month/year |
| `LIST` | country, tenant, status | geographic / tenant separation |
| `HASH` | user_id | spreading load evenly when there's no natural range |
(Partitions can themselves be partitioned — sub-partitioning.)

### Benefits
- **Partition pruning**: `WHERE created_at >= '2025-03-01'` scans only matching partitions (visible in EXPLAIN).
- **Cheap data retention**: `DETACH PARTITION` / `DROP TABLE events_2022_01` is instant — vs a huge `DELETE` that bloats the table and the WAL.
- **Maintenance per partition**: smaller indexes, faster `VACUUM`, can move old partitions to cheaper storage.
- **Bulk loads**: load into a standalone table, then `ATTACH PARTITION`.

### Rules & gotchas
- A **primary key / unique constraint must include the partition key** (`PRIMARY KEY (id, created_at)`).
- Indexes created on the parent are created on every partition automatically.
- Queries that **don't filter on the key** scan all partitions (can be slower than one table).
- Too many partitions (thousands) increases planning time. Typical: monthly/daily for time series.
- Updating the key moves the row between partitions (allowed, but slower).
- Partitioning is **not** a substitute for indexes; it's for very large tables (tens/hundreds of millions of rows).

## Part 2 — Materialized views

A **materialized view** stores the **result** of a query physically. Reads are as fast as a table;
the data is a snapshot until refreshed.
```sql
CREATE MATERIALIZED VIEW mv_daily_revenue AS SELECT …;
CREATE UNIQUE INDEX ON mv_daily_revenue (day);       -- required for CONCURRENTLY
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_revenue;   -- readers aren't blocked
```

| | View | Materialized view | Summary table (+ ETL/trigger) |
|---|---|---|---|
| Stores data | no | yes | yes |
| Freshness | always current | as of last REFRESH | as fresh as your pipeline |
| Refresh cost | — | recomputes everything | can be incremental |
| Indexable | no | yes | yes |

Use MVs for expensive dashboards/aggregations that tolerate minutes/hours of staleness. Schedule refreshes
(cron, pg_cron, Airflow). For incremental maintenance at scale, use summary tables updated by ETL or
extensions/tools (e.g. dbt incremental models, TimescaleDB continuous aggregates).

## Part 3 — Scaling a relational database (concepts)
| Technique | What it solves | Notes |
|---|---|---|
| **Indexes & query tuning** | most "slow database" problems | always first |
| **Vertical scaling** | CPU/RAM/IOPS limits | bigger machine; simplest |
| **Connection pooling** (PgBouncer) | too many connections (each PG connection is a process) | transaction pooling for web apps |
| **Caching** (Redis, app cache) | repeated identical reads | invalidation is the hard part |
| **Read replicas** (streaming replication) | read-heavy load, reporting | replicas lag slightly: read-your-writes issues |
| **Partitioning** | huge tables, retention | within one server |
| **Sharding** (Citus, app-level) | write volume / data size beyond one server | cross-shard joins & transactions get hard |
| **Logical replication / CDC** (Debezium) | feeding warehouses, search, microservices | streams row changes |
| **OLAP warehouse** (Snowflake, BigQuery, ClickHouse, DuckDB) | heavy analytics | column stores; keep OLTP lean |

### Operational basics
- **VACUUM / autovacuum** removes dead row versions (MVCC) and prevents transaction-id wraparound; tune it for
  hot tables. **ANALYZE** keeps statistics fresh.
- **Bulk loading**: `COPY` is 10–100× faster than INSERTs; drop/recreate indexes for massive initial loads.
- **Backups**: `pg_dump` (logical) for small DBs; base backups + WAL archiving (PITR) for production.
- **Monitoring**: `pg_stat_statements`, `pg_stat_activity`, `pg_stat_user_tables` (seq scans, dead tuples).

## Significance
Data engineers own large, growing tables. Partitioning + retention, materialized/summary tables, and
knowing when to move analytics to a warehouse are everyday design decisions.

## Common mistakes
- Partitioning small tables "for performance" (adds overhead, no gain).
- Forgetting the default partition → inserts fail when a new month arrives (or worse, everything lands in default).
- Not automating creation of future partitions (pg_partman, scheduled jobs).
- `REFRESH MATERIALIZED VIEW` (non-concurrent) during business hours → readers blocked.
- Sending analytics queries to the primary OLTP database.
