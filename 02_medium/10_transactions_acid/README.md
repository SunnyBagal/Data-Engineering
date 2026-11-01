# 10 · Transactions & ACID

## What it is
A **transaction** is a group of SQL statements that the database treats as **one indivisible unit of work**:
either **all** of them take effect, or **none** do.

```sql
BEGIN;                                                         -- start
UPDATE accounts SET balance = balance - 100 WHERE id = 1;      -- debit
UPDATE accounts SET balance = balance + 100 WHERE id = 2;      -- credit
COMMIT;                                                        -- make it permanent (or ROLLBACK to undo)
```
If the server crashes between the two UPDATEs, neither is applied — money is never "lost in flight".

## ACID
| Property | Promise | How the database delivers it |
|---|---|---|
| **A**tomicity | all or nothing | undo on ROLLBACK/failure; Postgres MVCC simply never makes the new row versions visible |
| **C**onsistency | every commit moves the DB from one valid state to another | constraints (PK, FK, CHECK, UNIQUE), triggers |
| **I**solation | concurrent transactions don't see each other's half-done work | MVCC snapshots, locks, isolation levels (03_hard/07) |
| **D**urability | once COMMIT returns, the change survives crashes | write-ahead log (WAL) flushed to disk at commit |

## Transaction control (TCL)
| Command | Effect |
|---|---|
| `BEGIN` / `START TRANSACTION` | open a transaction |
| `COMMIT` | make all changes permanent and visible to others |
| `ROLLBACK` | discard all changes since BEGIN |
| `SAVEPOINT name` | a checkpoint inside the transaction |
| `ROLLBACK TO SAVEPOINT name` | undo only back to the checkpoint; transaction continues |
| `RELEASE SAVEPOINT name` | forget the checkpoint (keeps its changes) |
| `SET TRANSACTION ISOLATION LEVEL …` | choose isolation (03_hard/07) |

## Autocommit
Outside an explicit `BEGIN`, every single statement is its own transaction and commits immediately
(psql, most drivers). Many GUI tools offer a "manual commit" mode — know which one you're in!

## Errors inside a transaction (Postgres)
After any error, Postgres marks the transaction **aborted**: every following statement fails with
`current transaction is aborted, commands ignored until end of transaction block`.
You must `ROLLBACK` (or `ROLLBACK TO SAVEPOINT` if you set one before the failing statement).
Other databases (MySQL, SQL Server) may let the transaction continue after a statement error —
another reason to always check errors in application code.

## Things that are transactional in Postgres (and might surprise you)
- **DDL** (`CREATE`, `ALTER`, `DROP`) — can be rolled back. (Not in MySQL/Oracle.)
- `now()` / `CURRENT_TIMESTAMP` return the **transaction start time** — the same value for every
  statement in the transaction. Use `clock_timestamp()` for the real time.
- **Sequences are NOT rolled back**: an identity value consumed in a rolled-back transaction is gone
  → gaps in ids are normal and expected.

## Significance
Transactions are what make databases trustworthy for money, inventory, bookings — any operation that
touches several rows/tables that must stay in agreement:
- checkout: create order + order lines + decrement stock + record payment,
- bank transfer: debit + credit,
- migration scripts: change schema + backfill data, all or nothing.

## Best practices
- **Keep transactions short.** Open transactions hold locks and prevent cleanup of old row versions
  (`VACUUM`), causing blocking and table bloat. Never wait for user input inside a transaction.
- Do reads/validation that don't need locking **before** `BEGIN` when possible.
- Make the order of updates consistent across code paths (e.g. always lock accounts by ascending id)
  to avoid deadlocks (03_hard/07).
- Let the database enforce invariants (CHECK balance >= 0) so a bug can't commit invalid data.
- Handle errors: `ROLLBACK` on any exception, and be ready to **retry** serialization failures.

## Common mistakes
- Forgetting `COMMIT` in a manual-commit tool → changes invisible to others, locks held for hours.
- Running a big `UPDATE` in autocommit mode with no way to undo it.
- Long-running transactions in app code ("idle in transaction" connections).
- Assuming a ROLLBACK resets identity counters.
- Doing external side effects (sending emails, calling APIs) inside a DB transaction that may roll back.
