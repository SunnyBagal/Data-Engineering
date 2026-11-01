# 07 · Concurrency, Isolation Levels & Locking

## Why it matters
Real databases serve **many sessions at once**. Two checkouts buying the last item, two transfers from
the same account, a report running while orders are inserted. Without control you get **lost money,
oversold stock, and inconsistent reports**. The "I" in ACID is about this.

## Concurrency anomalies
| Anomaly | What happens | Example |
|---|---|---|
| **Dirty read** | read another transaction's **uncommitted** change (which may roll back) | see a balance that never existed |
| **Non-repeatable read** | read the same row twice, get different values (someone committed in between) | report total changes mid-report |
| **Phantom read** | re-run a range query, new rows appear | "count orders today" changes within one transaction |
| **Lost update** | two read-modify-write cycles overwrite each other | both read stock = 1, both write stock = 0 → sold twice |
| **Write skew** | two transactions each check a condition on overlapping data, then write disjoint rows → invariant broken | two doctors both go off-call because "the other is on call" |

## Isolation levels (SQL standard) and PostgreSQL behaviour
| Level | Dirty read | Non-repeatable | Phantom | Write skew | PostgreSQL notes |
|---|---|---|---|---|---|
| Read Uncommitted | possible* | possible | possible | possible | *PG treats it as Read Committed |
| **Read Committed** (PG default) | ❌ | possible | possible | possible | each **statement** sees a fresh snapshot |
| Repeatable Read | ❌ | ❌ | ❌ (in PG) | possible | one snapshot for the whole **transaction**; concurrent update of the same row → error 40001 |
| Serializable | ❌ | ❌ | ❌ | ❌ | SSI: detects dangerous patterns, aborts one transaction with 40001 — **app must retry** |

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;   -- or: SET TRANSACTION ISOLATION LEVEL … (first statement)
```
(MySQL InnoDB defaults to Repeatable Read; SQL Server to Read Committed with locking reads.)

## MVCC — how Postgres does it
**Multi-Version Concurrency Control**: an UPDATE writes a **new row version**; the old one stays until
no transaction needs it (then `VACUUM` reclaims it). Each row version carries `xmin` (creating transaction)
and `xmax` (deleting/updating transaction). A transaction's **snapshot** decides which versions it sees.
> **Readers never block writers, writers never block readers.** Only writers to the *same row* wait for each other.

## Locks
### Row-level (explicit)
| Clause | Blocks | Use |
|---|---|---|
| `SELECT … FOR UPDATE` | other FOR UPDATE/UPDATE/DELETE of those rows | read-modify-write safely |
| `FOR NO KEY UPDATE` | like above but allows FK checks | default for UPDATE not touching keys |
| `FOR SHARE` | updates/deletes (others can also share-lock) | ensure a row doesn't change while you use it |
| `… NOWAIT` | error immediately instead of waiting | interactive apps |
| `… SKIP LOCKED` | skip rows already locked | **job queues** with many workers |

### Table-level (mostly implicit)
`ALTER TABLE` / `DROP` / `TRUNCATE` take **ACCESS EXCLUSIVE** (blocks everything, even SELECT).
⚠️ A DDL waiting for a lock also blocks everyone queued *behind* it → always set `lock_timeout` for migrations.

### Advisory locks
Application-defined locks on a number: `pg_advisory_lock(42)` / `pg_try_advisory_lock(42)` —
e.g. "only one instance of this cron job runs at a time".

## Preventing lost updates — 4 techniques
1. **Atomic UPDATE**: `UPDATE products SET stock_qty = stock_qty - 1 WHERE product_id = 5 AND stock_qty >= 1;`
   (check the affected row count). Simplest and best when possible.
2. **Pessimistic locking**: `SELECT … FOR UPDATE`, then compute, then UPDATE, in one transaction.
3. **Optimistic locking**: `version` column; `UPDATE … SET …, version = version + 1 WHERE id = ? AND version = ?`;
   0 rows updated → someone else changed it → reload and retry. Great for web forms (no long-held locks).
4. **Serializable isolation** + retry loop.
Plus **constraints** (`CHECK (stock_qty >= 0)`) as the last line of defence.

## Deadlocks
T1 locks row A then wants B; T2 locks B then wants A → both wait forever. Postgres detects it
(after `deadlock_timeout`, 1 s) and aborts one with `ERROR: deadlock detected`.
**Prevention:** lock rows in a consistent order (e.g. ascending id), keep transactions short,
lock everything you need up front (`SELECT … WHERE id IN (…) ORDER BY id FOR UPDATE`).

## Significance
Concurrency bugs pass every test on a developer laptop and then corrupt data in production under load.
Knowing isolation levels, row locks, SKIP LOCKED queues and retry logic is essential for anyone building
payments, inventory, booking or job-processing systems.

## Common mistakes
- Read-then-write in application code without locking or atomic SQL (lost updates).
- Assuming Repeatable Read prevents write skew (it doesn't — use Serializable or explicit locks).
- Not retrying on `40001 serialization_failure` / `40P01 deadlock_detected`.
- Long transactions holding locks (see 02_medium/10).
- Running `ALTER TABLE` on a busy table without `lock_timeout`.
- Using `SELECT … FOR UPDATE` on many rows without ORDER BY (inconsistent lock order → deadlocks).
