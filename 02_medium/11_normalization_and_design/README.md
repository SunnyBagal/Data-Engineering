# 11 · Normalization & Database Design

## What it is
**Normalization** is the process of organizing columns and tables so that **each fact is stored exactly
once**. It removes redundancy and the bugs redundancy causes. **Database design** is the broader craft:
choosing entities, relationships, keys, types and constraints that model the business correctly.

## Why redundancy is dangerous: anomalies
Imagine one wide "spreadsheet" table:

| order_id | order_date | customer_email | customer_city | product_name | category | unit_price | qty |
|---|---|---|---|---|---|---|---|
| 1 | 2023-01-05 | aarav@… | Mumbai | ProBook 14 | Laptops | 1200 | 1 |
| 1 | 2023-01-05 | aarav@… | Mumbai | Wireless Mouse | Accessories | 25 | 1 |
| 5 | 2023-03-08 | aarav@… | Mumbai | Mechanical Keyboard | Accessories | 89.99 | 1 |

| Anomaly | Example |
|---|---|
| **Update** | Aarav moves to Pune → must update *every* row; miss one and the data contradicts itself |
| **Insert** | Can't record a new product until someone orders it (no order_id to put in the row) |
| **Delete** | Delete Aarav's only order → we also lose that the customer exists |

## Functional dependencies (the theory behind it)
`A → B` ("A determines B") means: rows with the same A always have the same B.
- `customer_email → customer_city`
- `product_name → category, unit_price(current)`
- `(order_id, product_name) → qty`

Normal forms are rules about which dependencies are allowed inside one table.

## The normal forms
| Form | Rule | Violation example | Fix |
|---|---|---|---|
| **1NF** | Atomic values; no repeating groups; each row unique (has a key) | `tags = 'work,portable'`; columns `phone1, phone2, phone3` | separate rows / child table |
| **2NF** | 1NF + no non-key column depends on **part** of a composite key | in `(order_id, product_id) → qty, product_name`: product_name depends only on product_id | move product_name to `products` |
| **3NF** | 2NF + no non-key column depends on **another non-key** column (no transitive dependency) | `employees(emp_id, dept_id, dept_name)`: dept_name depends on dept_id | move dept_name to `departments` |
| **BCNF** | every determinant is a candidate key (stricter 3NF) | `(student, course) → teacher` but `teacher → course` | split into (teacher, course) and (student, teacher) |
| **4NF** | no independent multi-valued facts in one table | `(employee, skill, language)` where skills and languages are independent | two tables |

Memory aid for 1–3NF: every non-key attribute depends on **"the key, the whole key, and nothing but the key"**.

In practice, **3NF (or BCNF)** is the target for transactional (OLTP) databases. Our practice database is in 3NF,
with one deliberate exception: `order_items.unit_price` copies the price at purchase time — because
it's a *different fact* (historical price) from `products.price` (current price). That's not redundancy.

## Denormalization — breaking the rules on purpose
Normalized schemas are great for writes and correctness; reads may need many joins.
Denormalize **deliberately** when:
- **Analytics (OLAP)**: star schemas — a central **fact** table (sales lines) surrounded by wide
  **dimension** tables (date, product, customer). Fewer joins, simple for BI tools.
- **Read-heavy hot paths**: cache a computed `order_total` on `orders`, kept in sync by a trigger/app.
- **History/snapshots**: copying values that must not change later (unit_price, shipping address).

Always ask: *who keeps the copy in sync, and what happens if they don't?*

## OLTP vs OLAP design
| | OLTP (application DB) | OLAP (warehouse) |
|---|---|---|
| Workload | many small reads/writes | few huge reads |
| Schema | normalized (3NF) | star / snowflake, denormalized |
| Example | Postgres behind an app | Snowflake, BigQuery, Redshift, DuckDB |
| Keys | surrogate ids + FKs | surrogate keys, slowly-changing dimensions |

## Design process (practical)
1. **List the entities** (nouns): customer, order, product, category, payment.
2. **Define relationships & cardinality**: customer 1—N orders; order N—M products (via order_items).
3. **Choose keys**: surrogate PK (`GENERATED … AS IDENTITY` or UUID) + UNIQUE on natural keys (email).
4. **Choose types & constraints**: NOT NULL by default, CHECKs for business rules, FKs everywhere.
5. **Normalize to 3NF**, then denormalize only with a measured reason.
6. **Index for access patterns** (02_medium/09).
7. **Plan for change**: migrations, soft deletes, audit columns (`created_at`, `updated_at`).

## Relationship patterns
| Relationship | Implementation |
|---|---|
| 1:N | FK on the "many" side (`orders.customer_id`) |
| M:N | junction table with composite PK (`order_items(order_id, product_id)`) |
| 1:1 | FK with UNIQUE (`user_profiles.user_id UNIQUE REFERENCES users`) |
| Hierarchy | self-referencing FK (`employees.manager_id`) |
| Optional | nullable FK |

## Common mistakes
- Comma-separated lists in a column (`'tag1,tag2'`) → can't index, join, or validate.
- `col1, col2, col3` repeating columns → use a child table.
- Storing derived values (age, totals) without a sync strategy.
- One giant "entity-attribute-value" table for everything (`entity, attribute, value`) → no types, no constraints.
- Over-normalizing lookup values that never change (splitting `country` into 5 tables).
- Natural keys that change (email as PK) → cascading updates everywhere.
