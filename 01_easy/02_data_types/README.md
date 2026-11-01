# 02 · Data Types

## What it is
Every column has a **data type** that defines which values it can hold, how much space they take,
how they sort and compare, and which operations/functions apply. Choosing types is the first
**data-quality** decision you make: the database will reject `'banana'` in a `DATE` column for you.

## Why it matters
- **Correctness** — `FLOAT` cannot represent 0.10 exactly; money in `FLOAT` drifts by fractions of a cent.
- **Integrity** — a `DATE` column can't contain `'2024-02-30'`; a `TEXT` column can.
- **Performance** — smaller types = more rows per page = less I/O; comparing integers is faster than strings.
- **Behaviour** — `'10' < '9'` is TRUE for text (alphabetical) but `10 < 9` is FALSE for numbers.

## The main families (PostgreSQL)

### Numeric
| Type | Size | Range / precision | Use for |
|---|---|---|---|
| `SMALLINT` | 2 B | ±32 767 | small counters, ratings |
| `INTEGER` / `INT` | 4 B | ±2.1 billion | ids, quantities (default choice) |
| `BIGINT` | 8 B | ±9.2 × 10¹⁸ | ids in huge tables, event counts, epoch-ms |
| `NUMERIC(p,s)` / `DECIMAL` | variable | exact, p digits total, s after the point | **money**, anything that must be exact |
| `REAL` | 4 B | ~6 significant digits, approximate | sensor readings |
| `DOUBLE PRECISION` | 8 B | ~15 significant digits, approximate | scientific values, ML features |

`NUMERIC(10,2)` → up to 99 999 999.99. Floats are faster but **approximate** (binary fractions):
`0.1 + 0.2 = 0.30000000000000004`.

### Text
| Type | Notes |
|---|---|
| `CHAR(n)` | fixed length, **pads with spaces**. Rarely what you want (except fixed codes like ISO `CHAR(2)`). |
| `VARCHAR(n)` | variable length with a max. Max length acts as a lightweight validation rule. |
| `TEXT` | unlimited. In Postgres, `TEXT` and `VARCHAR` have **identical performance**. |

In MySQL/SQL Server, `VARCHAR(n)` vs `TEXT` *does* matter (indexing limits, storage) — prefer `VARCHAR(n)` there.

### Date & time
| Type | Example | Notes |
|---|---|---|
| `DATE` | `2025-03-21` | calendar day |
| `TIME` | `14:30:00` | time of day |
| `TIMESTAMP` | `2025-03-21 14:30:00` | date + time, **no time zone** |
| `TIMESTAMPTZ` | `2025-03-21 14:30:00+05:30` | stored as UTC, displayed in session time zone |
| `INTERVAL` | `3 days 04:00:00` | a duration; `date + interval` arithmetic |

**Rule of thumb:** use `TIMESTAMPTZ` for real-world events (logins, payments) in multi-region systems.
Our practice DB uses plain `TIMESTAMP` for simplicity.

### Boolean
`BOOLEAN` → `TRUE`, `FALSE`, or `NULL` (unknown). MySQL fakes it with `TINYINT(1)`; SQL Server uses `BIT`.

### Others worth knowing
| Type | Purpose |
|---|---|
| `UUID` | globally unique ids (good for distributed systems; 16 B) |
| `JSON` / `JSONB` | semi-structured documents (`JSONB` = binary, indexable — prefer it) |
| `ARRAY` (`INT[]`, `TEXT[]`) | lists in one column (Postgres-specific; use sparingly) |
| `BYTEA` | binary data (prefer storing files in object storage + a URL) |
| `ENUM` | fixed set of labels (`CREATE TYPE mood AS ENUM (...)`) |
| `INET`, `CIDR` | IP addresses |

## Type conversion (casting)
- Standard: `CAST(expr AS type)` — portable.
- Postgres shorthand: `expr::type` — concise.
- **Implicit** casts happen sometimes (`'2025-01-01'` literal → `DATE` when compared to a date column).
  Relying on them in comparisons can **disable index use** (03_hard/05).

## Choosing a type — checklist
1. Is it money or must be exact? → `NUMERIC`.
2. Is it a count or id? → `INT` (or `BIGINT` if it might exceed 2 billion).
3. Is it a moment in time across regions? → `TIMESTAMPTZ`.
4. Is it free text? → `TEXT`/`VARCHAR(n)`; use `n` when a max is a real business rule.
5. Is it yes/no? → `BOOLEAN` (not `'Y'/'N'` strings).
6. Never store numbers or dates as text "for flexibility" — you lose validation, sorting, and math.

## Common mistakes
- Money in `FLOAT` → rounding errors in totals.
- Phone numbers as `INT` → leading zeros and `+` signs are lost; phones are text (you never do math on them).
- Dates as `VARCHAR` → `'2025-1-5'` and `'2025-01-05'` don't match; sorting is alphabetical.
- `INT` ids that overflow at 2 147 483 647 in high-volume tables.
- Integer division: `5 / 2 = 2` in Postgres/SQL Server (both operands INT). Use `5 / 2.0` or a cast.

## Dialect differences
| Concept | PostgreSQL | MySQL | SQL Server | Oracle |
|---|---|---|---|---|
| Exact decimal | `NUMERIC` | `DECIMAL` | `DECIMAL` | `NUMBER(p,s)` |
| Unlimited text | `TEXT` | `LONGTEXT` | `VARCHAR(MAX)` | `CLOB` |
| Boolean | `BOOLEAN` | `TINYINT(1)` | `BIT` | `NUMBER(1)` (BOOLEAN from 23c) |
| Date+time | `TIMESTAMP` | `DATETIME` | `DATETIME2` | `TIMESTAMP` |
| Integer division | `5/2 = 2` | `5/2 = 2.5000` | `5/2 = 2` | `5/2 = 2.5` |
