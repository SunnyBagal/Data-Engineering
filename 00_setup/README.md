# 00 · Setup — The Practice Database

Every lesson, exercise and solution in this course runs against **one** database called `sql_course`.
It models a small company that **sells products online and through sales reps**, and also has an
**HR side** (departments and employees).

## Load / reset

```bash
createdb sql_course                                             # once
psql -d sql_course -f 00_setup/schema.sql -f 00_setup/seed.sql # load (and re-run any time to RESET)
```

> Lessons that modify data either use their own scratch tables or wrap changes in
> `BEGIN; … ROLLBACK;`, so the shared data stays the same. If you ever break it, re-run the line above.

## Entity-relationship diagram

```
                    ┌──────────────┐
                    │ departments  │
                    └──────┬───────┘
                           │ 1
                           │
                           │ N
   ┌───────────────┐  ┌────┴─────────┐ manager_id (self-reference)
   │  categories   │  │  employees   │◄──────────┐
   │ parent_id ──┐ │  └────┬─────────┘───────────┘
   └──────┬──────┘◄┘       │ 1 (sales rep, optional)
          │ 1              │
          │ N              │ N
   ┌──────┴──────┐   ┌─────┴──────┐  N      1 ┌─────────────┐ referred_by (self)
   │  products   │   │   orders   ├───────────┤  customers  │◄────┐
   └──────┬──────┘   └──┬──────┬──┘           └──────┬──────┴─────┘
          │ 1         1 │      │ 1                   │ 1
          │ N         N │      │ N                   │ N
   ┌──────┴─────────────┴┐  ┌──┴───────┐       ┌─────┴────┐
   │     order_items     │  │ payments │       │  logins  │
   └─────────────────────┘  └──────────┘       └──────────┘
```

## Tables

### `departments` (6 rows)
| column | type | notes |
|---|---|---|
| dept_id | INT PK | |
| dept_name | VARCHAR(50) | unique |
| location | VARCHAR(50) | city |
| budget | NUMERIC(12,2) | **NULL** for Research |

*Research (6) has **no employees** — useful for LEFT JOIN practice.*

### `employees` (20 rows)
| column | type | notes |
|---|---|---|
| emp_id | INT PK | |
| first_name, last_name, email | VARCHAR | email unique |
| dept_id | INT FK → departments | **NULL** for the CEO (1) and a contractor (20) |
| manager_id | INT FK → employees | **NULL** for the CEO; builds a 5-level org chart |
| job_title | VARCHAR(60) | |
| salary | NUMERIC(10,2) | ties exist (e.g. two engineers at 95,000) |
| hire_date | DATE | |
| is_active | BOOLEAN | Mark Taylor (14) has left |

### `categories` (12 rows) — a tree
```
Electronics ─┬─ Computers ─┬─ Laptops
             │             └─ Accessories
             ├─ Phones
             └─ Gaming          (no products)
Home & Kitchen ─┬─ Appliances
                └─ Cookware
Books ─┬─ Fiction
       └─ Non-Fiction
```

### `products` (24 rows)
| column | type | notes |
|---|---|---|
| product_id | INT PK | |
| product_name | VARCHAR(100) | |
| category_id | INT FK → categories | always a leaf category |
| price | NUMERIC(10,2) | current list price |
| cost | NUMERIC(10,2) | supplier cost → margin = price − cost |
| stock_qty | INT | several are 0 (out of stock) |
| is_discontinued | BOOLEAN | |
| attributes | JSONB | brand, ram_gb, author, tags[] …; **NULL** for two products |
| created_at | DATE | |

*Never ordered: 4, 15, 22, 24.*

### `customers` (20 rows)
| column | type | notes |
|---|---|---|
| customer_id | INT PK | |
| first_name, last_name, email | VARCHAR | email unique |
| phone | VARCHAR(20) | **NULL** for many |
| city | VARCHAR(50) | **NULL** for Liam (16) |
| country | VARCHAR(50) | India, USA, UK, Germany, Canada |
| signup_date | DATE | |
| referred_by | INT FK → customers | referral chains, e.g. 1 → 6 → 9 → 19 |

*Never ordered: Nisha (19), Lucas (20).*

### `orders` (46 rows, Jan 2023 – Oct 2025)
| column | type | notes |
|---|---|---|
| order_id | INT PK | |
| customer_id | INT FK → customers | |
| employee_id | INT FK → employees | sales rep; **NULL** = online self-checkout |
| order_date | TIMESTAMP | includes time of day |
| status | VARCHAR | pending, shipped, delivered, cancelled, returned |
| shipped_date | DATE | **NULL** when not shipped |

### `order_items` (78 rows) — PK (order_id, product_id)
| column | type | notes |
|---|---|---|
| order_id | INT FK → orders | |
| product_id | INT FK → products | |
| quantity | INT | |
| unit_price | NUMERIC(10,2) | price **at purchase time** (may differ from current price) |
| discount | NUMERIC(4,2) | 0.10 = 10% off |

**Line revenue** = `quantity * unit_price * (1 - discount)`

### `payments` (43 rows)
| column | type | notes |
|---|---|---|
| payment_id | INT PK | |
| order_id | INT FK → orders | orders 6, 28, 41 paid in **two parts** |
| amount | NUMERIC(10,2) | |
| method | VARCHAR | card, upi, paypal, bank_transfer, cash |
| paid_at | TIMESTAMP | |

*Unpaid: cancelled 8, 15, 29; pending 45, 46; shipped cash-on-delivery 44.*

### `logins` (37 rows, Sep–Oct 2025)
| column | type | notes |
|---|---|---|
| login_id | INT PK | |
| customer_id | INT FK → customers | |
| login_at | TIMESTAMP | |
| device | VARCHAR | web, ios, android |

*Designed for streak and session problems: customer 1 has a 7-day streak (two logins on Sep 3),
customer 6 has a streak across a month boundary, customer 13 has many logins in one day.*

## Quick sanity check
```sql
SELECT 'orders' AS t, COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'customers', COUNT(*) FROM customers;
-- orders 46 · order_items 78 · customers 20
```
