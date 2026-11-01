# 13 · Interview & Real-World SQL Patterns

This topic combines everything before it into **reusable recipes**. Each pattern below appears again and
again in analytics work, data-engineering pipelines and technical interviews. Learn to recognise the
*shape* of the problem — then the solution is a template.

| # | Pattern | Recognise it by… | Core technique |
|---|---|---|---|
| 1 | **Top-N per group** | "best/latest/first *k* per X" | `ROW_NUMBER/RANK() OVER (PARTITION BY X ORDER BY …)` → filter; or `LATERAL … LIMIT k` |
| 2 | **Deduplication** | "duplicates", "keep the latest version" | `ROW_NUMBER() OVER (PARTITION BY <dup key> ORDER BY <preference>)` → keep `rn = 1` |
| 3 | **Nth highest** | "second highest salary" | `DENSE_RANK() = N` (or `OFFSET N-1` on DISTINCT values) |
| 4 | **Gaps & islands** | "consecutive days", "streaks", "ranges" | `value − ROW_NUMBER()` is constant inside an island → `GROUP BY` it |
| 5 | **Sessionization** | "sessions with 30-min inactivity", "group events into visits" | `LAG` → flag a new session when gap > threshold → running `SUM` of flags = session id |
| 6 | **Running totals / balances** | "cumulative", "to date", "balance after each txn" | `SUM() OVER (ORDER BY … ROWS UNBOUNDED PRECEDING)` |
| 7 | **Period-over-period** | "MoM", "YoY growth" | aggregate per period → `LAG()` |
| 8 | **Cohort retention** | "of users who started in X, how many came back in Y" | first event per user (cohort) → join activity → count per (cohort, period) |
| 9 | **Funnel** | "how many did A, then B, then C" | `COUNT(DISTINCT user) FILTER (…)` or step-wise `EXISTS` |
| 10 | **Market basket** | "frequently bought together" | self-join order lines on order_id with `a.product < b.product` |
| 11 | **Missing values in a sequence** | "which ids/dates are missing" | `generate_series` anti-join, or `LEAD(id) - id > 1` |
| 12 | **Overlapping intervals** | "double bookings", "concurrent sessions" | `a.start < b.end AND b.start < a.end` (+ `EXCLUDE` constraint to prevent) |
| 13 | **Relational division** | "customers who bought ALL products in X" | `GROUP BY … HAVING COUNT(DISTINCT …) = (SELECT COUNT(*) …)` |
| 14 | **A but not B** | "bought laptops but never accessories" | `EXISTS` + `NOT EXISTS` (or `EXCEPT`) |
| 15 | **Median / percentiles** | "typical value", "p95 latency" | `PERCENTILE_CONT(p) WITHIN GROUP (ORDER BY x)` |

## The gaps-and-islands trick, explained
For consecutive dates, subtracting a row number that increases by 1 per row yields a **constant**
for every row in the same streak:
```
date        rn   date - rn
2025-09-01   1   2025-08-31  ┐
2025-09-02   2   2025-08-31  │ island 1 (7 days)
…                            │
2025-09-07   7   2025-08-31  ┘
2025-09-10   8   2025-09-02  ┐ island 2 (3 days)
2025-09-11   9   2025-09-02  │
2025-09-12  10   2025-09-02  ┘
```
De-duplicate first (two logins on the same day would break the arithmetic).

## The sessionization trick, explained
```
login_at  gap_from_previous  new_session_flag  running_sum = session_no
10:00     —                   1                 1
10:05     5 min               0                 1
10:20     15 min              0                 1
11:30     70 min              1                 2
```

## Interview approach
1. Restate the question in terms of **grain** ("one row per customer per day").
2. Identify the pattern(s) from the table above.
3. Build it in **CTE steps**, checking intermediate results.
4. Think about **edge cases**: ties, NULLs, empty groups, duplicates, time zones, boundaries (half-open ranges).
5. Mention performance: indexes on partition/order columns, avoiding correlated subqueries on big tables.
