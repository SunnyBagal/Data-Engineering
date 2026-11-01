# SQL — From Zero to Advanced

A complete, hands-on SQL course. Every topic has **theory**, a **heavily commented runnable lesson**,
**practice questions** that mix in earlier topics, and **solutions** with explanations.

All examples run on **one shared practice database** (an e-commerce + HR company), so you are always
querying realistic, connected data — not toy one-off tables.

---

## How each topic folder is organised

| File | What it contains | How to use it |
|------|------------------|---------------|
| `README.md` | Theory: what it is, how it works, why it matters, use cases, pitfalls, dialect differences | Read first |
| `lesson.sql` | Runnable examples. Every meaningful line has a comment: **what** it does and **why** this over the alternatives | Run it statement by statement, change things, break things |
| `exercises.sql` | 5–7 questions on this topic **combined with earlier topics** | Try them yourself before peeking |
| `solutions.sql` | Answers + explanation + alternative approaches | Compare with your attempt |

---

## Setup (5 minutes)

The course uses **PostgreSQL** (free, the most standards-compliant open-source database).
Differences for MySQL / SQL Server / SQLite / Oracle are called out where they matter.

```bash
# 1. Install & start PostgreSQL (macOS with Homebrew)
brew install postgresql@17
brew services start postgresql@17

# 2. Create the practice database and load it
createdb sql_course
psql -d sql_course -f 00_setup/schema.sql -f 00_setup/seed.sql

# 3. Open a SQL shell
psql -d sql_course
```

To reset the data at any time (e.g. after experimenting with DELETEs), just re-run step 2's `psql` line —
the scripts are idempotent.

GUI alternatives: DBeaver, pgAdmin, DataGrip, TablePlus, or VS Code with the SQLTools extension.

---

## Roadmap

### 🟢 01_easy — Foundations
| # | Topic | You will learn |
|---|-------|----------------|
| 01 | [Intro to databases & SQL](01_easy/01_intro_to_databases_and_sql) | RDBMS, tables, keys, SQL sub-languages, how a query is processed |
| 02 | [Data types](01_easy/02_data_types) | Numeric, text, date/time, boolean, choosing the right type |
| 03 | [CREATE / ALTER / DROP](01_easy/03_create_alter_drop) | Defining and evolving tables (DDL) |
| 04 | [Constraints](01_easy/04_constraints) | PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT, referential actions |
| 05 | [INSERT / UPDATE / DELETE](01_easy/05_insert_update_delete) | Changing data safely (DML) |
| 06 | [SELECT basics](01_easy/06_select_basics) | Columns, expressions, aliases, DISTINCT |
| 07 | [WHERE filtering](01_easy/07_where_filtering) | Comparison, AND/OR/NOT, IN, BETWEEN, LIKE/ILIKE |
| 08 | [NULL handling](01_easy/08_null_handling) | Three-valued logic, IS NULL, COALESCE, NULLIF |
| 09 | [ORDER BY & LIMIT](01_easy/09_order_by_limit) | Sorting, NULLS FIRST/LAST, pagination |
| 10 | [Aggregate functions](01_easy/10_aggregate_functions) | COUNT, SUM, AVG, MIN, MAX, STRING_AGG |
| 11 | [GROUP BY & HAVING](01_easy/11_group_by_having) | Grouping rows, filtering groups, logical query order |
| 12 | [Built-in functions](01_easy/12_builtin_functions) | String, numeric, date/time functions, CAST |

### 🟡 02_medium — Combining & structuring data
| # | Topic | You will learn |
|---|-------|----------------|
| 01 | [Joins](02_medium/01_joins) | INNER, LEFT, RIGHT, FULL OUTER, join vs filter conditions |
| 02 | [Self & cross joins](02_medium/02_self_and_cross_joins) | Hierarchies, comparisons within a table, cartesian products |
| 03 | [Subqueries](02_medium/03_subqueries) | Scalar, IN, EXISTS, correlated, derived tables |
| 04 | [Set operations](02_medium/04_set_operations) | UNION, UNION ALL, INTERSECT, EXCEPT |
| 05 | [CASE expressions](02_medium/05_case_expressions) | Conditional logic, bucketing, custom sorting |
| 06 | [CTEs (WITH)](02_medium/06_ctes) | Readable multi-step queries |
| 07 | [Views](02_medium/07_views) | Saved queries, abstraction, updatable views |
| 08 | [Advanced DML](02_medium/08_advanced_dml) | UPSERT, INSERT…SELECT, UPDATE…FROM, DELETE…USING, RETURNING, MERGE |
| 09 | [Indexes (basics)](02_medium/09_indexes_basics) | B-tree, when indexes help & hurt |
| 10 | [Transactions & ACID](02_medium/10_transactions_acid) | BEGIN/COMMIT/ROLLBACK, SAVEPOINT, atomicity |
| 11 | [Normalization & design](02_medium/11_normalization_and_design) | 1NF→BCNF, ER modelling, when to denormalize |
| 12 | [Conditional aggregation & pivoting](02_medium/12_conditional_aggregation_pivot) | FILTER, SUM(CASE…), rows → columns |

### 🔴 03_hard — Advanced & production SQL
| # | Topic | You will learn |
|---|-------|----------------|
| 01 | [Window functions — ranking](03_hard/01_window_functions_ranking) | ROW_NUMBER, RANK, DENSE_RANK, NTILE, PARTITION BY |
| 02 | [Window functions — analytics](03_hard/02_window_functions_analytics) | LAG/LEAD, running totals, moving averages, frames |
| 03 | [Recursive CTEs](03_hard/03_recursive_ctes) | Trees, hierarchies, graph walks, series generation |
| 04 | [Advanced grouping & LATERAL](03_hard/04_advanced_grouping_lateral) | ROLLUP, CUBE, GROUPING SETS, LATERAL joins |
| 05 | [Query execution & EXPLAIN](03_hard/05_query_execution_explain) | Planner, scan/join types, reading plans, tuning |
| 06 | [Advanced indexing](03_hard/06_advanced_indexing) | Composite, covering, partial, expression, GIN, BRIN |
| 07 | [Concurrency, isolation & locking](03_hard/07_concurrency_isolation_locking) | Anomalies, isolation levels, MVCC, deadlocks, SKIP LOCKED |
| 08 | [Functions & stored procedures](03_hard/08_functions_procedures) | SQL & PL/pgSQL functions, procedures, volatility |
| 09 | [Triggers](03_hard/09_triggers) | Audit logs, derived columns, BEFORE/AFTER, row/statement |
| 10 | [JSON & semi-structured data](03_hard/10_json_semi_structured) | JSONB operators, indexing, building/flattening JSON |
| 11 | [Security & SQL injection](03_hard/11_security_injection) | Roles, GRANT/REVOKE, row-level security, parameterization |
| 12 | [Partitioning, materialized views & scaling](03_hard/12_partitioning_scaling) | Partitioning, MVs, replication, sharding concepts |
| 13 | [Interview & real-world patterns](03_hard/13_sql_patterns) | Gaps & islands, top-N per group, dedup, sessionization, median |

---

## The practice database (`00_setup`)

```
departments ──< employees >── (manager_id → employees)        HR side
                    │
                    └──< orders >── customers (referred_by → customers)
                            │            │
                            │            └──< logins
                            ├──< order_items >── products >── categories (parent_id → categories)
                            └──< payments
```

See [`00_setup/README.md`](00_setup/README.md) for every table and column.

---

## Study tips

1. **Type, don't copy-paste.** Muscle memory matters for SQL.
2. **Predict before running.** Guess the row count / result first, then check. Wrong guesses are where learning happens.
3. **Read queries in logical order:** `FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT`.
4. **Use transactions while experimenting:** `BEGIN; ...your DELETE...; ROLLBACK;` — nothing is lost.
5. **Revisit exercises.** Later topics often give a cleaner solution to an earlier problem (e.g. window functions vs correlated subqueries).
