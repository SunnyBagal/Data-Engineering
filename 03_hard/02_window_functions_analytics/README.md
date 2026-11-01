# 02 · Window Functions — Analytics (LAG/LEAD, Running Totals, Frames)

## What it is
Beyond ranking, window functions let each row **look at other rows**: the previous one, the next one,
the first in its group, or a sliding range of rows. This powers time-series analytics:
running totals, moving averages, period-over-period growth, gaps between events.

## Value (offset) functions
| Function | Returns |
|---|---|
| `LAG(x [, n [, default]])` | value of x **n rows before** the current row (default n = 1) |
| `LEAD(x [, n [, default]])` | value of x **n rows after** |
| `FIRST_VALUE(x)` | x from the first row of the window frame |
| `LAST_VALUE(x)` | x from the last row of the **frame** (⚠️ see the frame trap) |
| `NTH_VALUE(x, n)` | x from the n-th row of the frame |

```sql
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month)                      AS prev_month,
       revenue - LAG(revenue) OVER (ORDER BY month)            AS change
FROM monthly_revenue;
```

## Aggregate functions as windows
Any aggregate (`SUM`, `AVG`, `COUNT`, `MIN`, `MAX`) can be a window function.
With `ORDER BY` inside `OVER`, it becomes **cumulative**:
```sql
SUM(revenue) OVER (ORDER BY month)                                      -- running total
AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)  -- 3-month moving avg
SUM(revenue) OVER ()                                                    -- grand total on every row
```

## Window frames
The **frame** is the subset of the partition that an aggregate/value function sees for the current row.
```
{ ROWS | RANGE | GROUPS } BETWEEN <start> AND <end>
  start/end: UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
```
| Mode | Counts in… | Example |
|---|---|---|
| `ROWS` | physical rows | `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW` = last 7 rows |
| `RANGE` | values of the ORDER BY column | `RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW` = last 7 *calendar days* |
| `GROUPS` | groups of peer (tied) rows | `GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW` |

### Default frame (important!)
- No `ORDER BY` in `OVER` → frame = **whole partition**.
- With `ORDER BY` → default is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, which includes
  **all peers (ties) of the current row**. So a running total over tied dates jumps by the whole tie
  group at once. Use `ROWS` for a strict row-by-row running total.

### The LAST_VALUE trap
With the default frame, the frame **ends at the current row**, so `LAST_VALUE(x) OVER (ORDER BY …)`
returns the current row's own value. Fix: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`,
or use `FIRST_VALUE` with the opposite sort order.

## Common analytics patterns
| Metric | SQL |
|---|---|
| Running total | `SUM(x) OVER (ORDER BY t ROWS UNBOUNDED PRECEDING)` |
| Running total per group | `SUM(x) OVER (PARTITION BY g ORDER BY t ROWS UNBOUNDED PRECEDING)` |
| Moving average (7 rows) | `AVG(x) OVER (ORDER BY t ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` |
| Period-over-period % | `100 * (x - LAG(x) OVER w) / LAG(x) OVER w` |
| Share of total | `x / SUM(x) OVER ()` |
| Gap between events | `t - LAG(t) OVER (PARTITION BY user ORDER BY t)` |
| Change detection | `WHERE status <> LAG(status) OVER (…)` |
| First/last value per group | `FIRST_VALUE(x) OVER (PARTITION BY g ORDER BY t)` |

## Significance
These are the bread and butter of analytics engineering: growth dashboards, retention, churn
signals, anomaly detection, inventory balances, sessionization (03_hard/13). Doing them without windows
requires self-joins that are slow and error-prone.

## Performance
- Each distinct window spec = one sort; share windows via the `WINDOW` clause.
- `ROWS` frames are cheaper than `RANGE` with offsets.
- Running totals over millions of rows are fine (single pass after the sort).

## Common mistakes
- Forgetting `PARTITION BY` → LAG crosses from one customer to the next.
- Default `RANGE` frame + ties → surprising running totals.
- `LAST_VALUE` with default frame.
- Missing periods (no row for a month) → LAG compares with the wrong month. Fill gaps first with a
  calendar (`generate_series`) LEFT JOIN.
- Dividing by `LAG(...)` when it's 0 or NULL → use `NULLIF`.
