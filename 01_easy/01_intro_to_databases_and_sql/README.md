# 01 · Introduction to Databases & SQL

## What is a database?
A **database** is an organised, persistent collection of data. A **DBMS** (Database Management System)
is the software that stores it and lets many users read and change it **safely and concurrently**.

A **relational** DBMS (RDBMS) — PostgreSQL, MySQL, SQL Server, Oracle, SQLite — stores data in
**tables (relations)**, based on E. F. Codd's relational model (1970).

| Term (everyday) | Formal term | Example |
|---|---|---|
| Table | Relation | `customers` |
| Row / record | Tuple | one customer |
| Column / field | Attribute | `email` |
| Column's allowed values | Domain / data type | `VARCHAR(100)` |
| Table definition | Schema | column names + types + constraints |

### Keys — how rows are identified and linked
- **Primary key (PK)** — uniquely identifies each row, never NULL (`customers.customer_id`).
- **Foreign key (FK)** — a column that references another table's PK (`orders.customer_id → customers`).
  This is how relationships are stored: *not* by nesting, but by matching values.
- **Candidate key** — any column set that could be a PK (`customers.email` is one too).
- **Natural vs surrogate key** — natural = real-world value (email, ISBN); surrogate = generated id.
  Surrogates are usually preferred because real-world values change (people change email).

### Relationship types
- **One-to-many (1:N)** — one customer → many orders. FK lives on the "many" side.
- **Many-to-many (M:N)** — orders ↔ products. Needs a **junction table** (`order_items`).
- **One-to-one (1:1)** — rare; e.g. user ↔ user_profile, split for security or size.

## What is SQL?
**SQL (Structured Query Language)** is the standard language for relational databases (ANSI/ISO standard
since 1986). It is **declarative**: you describe *what* you want, and the database's **query optimizer**
decides *how* to get it (which index, which join algorithm). This is why the same SQL keeps working
when data grows 1000× — the plan adapts, your code doesn't.

### SQL sub-languages
| Group | Purpose | Statements |
|---|---|---|
| **DDL** – Data Definition | define structure | `CREATE`, `ALTER`, `DROP`, `TRUNCATE` |
| **DML** – Data Manipulation | change data | `INSERT`, `UPDATE`, `DELETE`, `MERGE` |
| **DQL** – Data Query | read data | `SELECT` |
| **DCL** – Data Control | permissions | `GRANT`, `REVOKE` |
| **TCL** – Transaction Control | group changes | `BEGIN`, `COMMIT`, `ROLLBACK`, `SAVEPOINT` |

### How a SELECT is processed (logical order)
You *write* `SELECT … FROM … WHERE … GROUP BY … HAVING … ORDER BY … LIMIT`, but the database
*logically evaluates* it as:

```
FROM / JOIN  →  WHERE  →  GROUP BY  →  HAVING  →  SELECT  →  DISTINCT  →  ORDER BY  →  LIMIT
```
Remember this — it explains many "why doesn't my alias work in WHERE?" errors later.

## Why it matters
- SQL is used by every role that touches data: backend developers, data engineers/analysts/scientists, PMs.
- It has been the #1 data language for 40+ years; skills transfer across PostgreSQL, Snowflake,
  BigQuery, Spark SQL, Databricks, Redshift, DuckDB…
- Relational databases give **ACID** guarantees (covered in 02_medium/10) — your bank balance relies on them.

## Use cases
- Application backends (users, orders, payments) — OLTP: many small, fast transactions.
- Analytics & reporting (dashboards, KPIs) — OLAP: few huge, read-heavy queries.
- Data pipelines (ETL/ELT) that move and transform data between systems.

## SQL vs NoSQL (when to choose what)
| Choose relational (SQL) when… | Consider NoSQL when… |
|---|---|
| Data is structured & related | Data is mostly schemaless documents / key-value |
| You need transactions & consistency | You need massive horizontal write scale with relaxed consistency |
| You need ad-hoc querying / reporting | Access pattern is simple & known in advance |

Modern Postgres also handles JSON well (03_hard/10), so "SQL vs NoSQL" is often "and", not "or".

## Syntax basics
- Statements end with `;`.
- **Keywords are case-insensitive** (`select` = `SELECT`). Convention: UPPERCASE keywords, lowercase names.
- Unquoted identifiers are folded to lowercase in Postgres (`Customers` → `customers`).
  `"Customers"` (double quotes) keeps case — avoid it, it forces you to quote forever.
- **Strings use single quotes** `'India'`. Double quotes are for identifiers.
- Comments: `-- single line` and `/* multi-line */`.

## Dialect notes
| Feature | PostgreSQL | MySQL | SQL Server | SQLite |
|---|---|---|---|---|
| Limit rows | `LIMIT 5` | `LIMIT 5` | `TOP 5` / `OFFSET…FETCH` | `LIMIT 5` |
| Identifier quote | `"col"` | `` `col` `` | `[col]` | `"col"` |
| String concat | `\|\|` | `CONCAT()` | `+` | `\|\|` |
| Auto-increment | `IDENTITY` / `SERIAL` | `AUTO_INCREMENT` | `IDENTITY(1,1)` | `INTEGER PRIMARY KEY` |

## Common mistakes
- Using double quotes for strings → `column "India" does not exist`.
- Forgetting `;` in the psql shell (it waits for more input — prompt changes to `-#`).
- Thinking SQL runs top-to-bottom like code — it's set-based and declarative.

## psql cheat sheet
| Command | Does |
|---|---|
| `\l` | list databases |
| `\c sql_course` | connect to a database |
| `\dt` | list tables |
| `\d orders` | describe a table |
| `\x` | toggle expanded (vertical) output |
| `\timing` | show query execution time |
| `\i file.sql` | run a file |
| `\q` | quit |
