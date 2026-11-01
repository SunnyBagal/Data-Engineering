# 12 · Built-in Functions — String, Numeric, Date/Time, Conversion

## What they are
**Scalar functions** take values from **one row** and return **one value** per row
(unlike aggregates, which collapse many rows into one). Use them in `SELECT`, `WHERE`, `ORDER BY`,
`GROUP BY`, `UPDATE … SET` — anywhere an expression is allowed.

## String functions
| Function | Example | Result |
|---|---|---|
| `UPPER / LOWER / INITCAP` | `INITCAP('hello world')` | `Hello World` |
| `LENGTH(s)` | `LENGTH('SQL')` | `3` |
| `TRIM / LTRIM / RTRIM` | `TRIM('  hi  ')` | `hi` |
| `SUBSTRING(s FROM i FOR n)` / `SUBSTR(s, i, n)` | `SUBSTRING('Postgres', 1, 4)` | `Post` (1-indexed!) |
| `LEFT(s, n) / RIGHT(s, n)` | `RIGHT('report.csv', 3)` | `csv` |
| `POSITION(x IN s)` / `STRPOS(s, x)` | `STRPOS('a@b.com', '@')` | `2` (0 = not found) |
| `REPLACE(s, from, to)` | `REPLACE('a-b-c', '-', '')` | `abc` |
| `SPLIT_PART(s, delim, n)` | `SPLIT_PART('a@b.com', '@', 2)` | `b.com` |
| `LPAD / RPAD` | `LPAD('42', 5, '0')` | `00042` |
| `CONCAT / CONCAT_WS` | `CONCAT_WS('-', 'a', NULL, 'b')` | `a-b` (skips NULL) |
| `REGEXP_REPLACE / REGEXP_MATCH` | `REGEXP_REPLACE('+91-98', '\D', '', 'g')` | `9198` |
| `FORMAT` | `FORMAT('%s has %s', 'x', 3)` | `x has 3` |
| `REVERSE`, `REPEAT`, `MD5` | `REPEAT('ab', 3)` | `ababab` |

## Numeric functions
| Function | Example | Result |
|---|---|---|
| `ROUND(x, d)` | `ROUND(2.567, 2)` | `2.57` |
| `TRUNC(x, d)` | `TRUNC(2.567, 2)` | `2.56` (cuts, no rounding) |
| `CEIL / FLOOR` | `CEIL(2.1)`, `FLOOR(-2.1)` | `3`, `-3` |
| `ABS`, `SIGN` | `ABS(-5)` | `5` |
| `MOD(a, b)` / `%` | `MOD(10, 3)` | `1` |
| `POWER(a, b)`, `SQRT`, `LN`, `LOG`, `EXP` | `POWER(2, 10)` | `1024` |
| `GREATEST / LEAST` | `GREATEST(3, 7, 5)` | `7` (row-wise max, not aggregate!) |
| `RANDOM()` | | `0 ≤ x < 1` |
| `WIDTH_BUCKET(x, lo, hi, n)` | `WIDTH_BUCKET(42, 0, 100, 10)` | `5` (histogram bucket) |

## Date & time functions
| Function | Purpose |
|---|---|
| `CURRENT_DATE`, `CURRENT_TIMESTAMP` / `now()` | today / now (constant within a transaction) |
| `EXTRACT(field FROM ts)` / `DATE_PART('field', ts)` | year, month, day, hour, dow, isodow, week, quarter, epoch |
| `DATE_TRUNC('month', ts)` | round **down** to the start of month/week/day/hour… (perfect for GROUP BY) |
| `AGE(a, b)` | interval between dates in years/months/days |
| `ts + INTERVAL '3 days'` | date arithmetic |
| `date_a - date_b` | integer number of days |
| `TO_CHAR(ts, 'YYYY-MM-DD HH24:MI')` | format a date/number as text |
| `TO_DATE(text, fmt)` / `TO_TIMESTAMP` | parse text into a date |
| `MAKE_DATE(y, m, d)` | build a date |
| `generate_series(start, stop, step)` | produce a series of dates (calendar tables) |

### Useful `TO_CHAR` patterns
`YYYY` year · `MM` month number · `Mon`/`Month` month name · `DD` day · `Dy`/`Day` weekday ·
`HH24:MI:SS` time · `Q` quarter · `FM` prefix removes padding · numbers: `'FM999,999.00'`.

## Conversion
- `CAST(x AS type)` (standard) or `x::type` (Postgres).
- `TO_CHAR(number, format)` for display formatting; `TO_NUMBER(text, format)` for parsing.

## Why it matters
Real data is messy: inconsistent case, stray spaces, phone numbers in five formats, timestamps that
need bucketing by week. Functions are how you **clean**, **derive** and **present** data — the "T" in ETL.

## Use cases
- Cleaning: `LOWER(TRIM(email))` before comparing or de-duplicating.
- Parsing: `SPLIT_PART(email, '@', 2)` → email domain analysis.
- Reporting: `DATE_TRUNC('month', order_date)` → monthly revenue; `TO_CHAR(..., 'Mon YYYY')` for labels.
- Business rules: `GREATEST(price * 0.9, cost)` → discount but never below cost.
- Ages / tenures: `EXTRACT(YEAR FROM AGE(hire_date))`.

## Performance: functions in WHERE
`WHERE LOWER(email) = 'x'` or `WHERE DATE_TRUNC('day', ts) = '2025-01-01'` can't use a normal index
on the column → full scan. Rewrite as a range on the bare column, or create an
**expression index** on `LOWER(email)` (03_hard/06).

## Common mistakes
- Assuming 0-based string positions — SQL strings are **1-based**.
- `now()` in a long transaction is the transaction **start** time (use `clock_timestamp()` for wall time).
- `EXTRACT(DOW …)`: Sunday = 0; `ISODOW`: Monday = 1 … Sunday = 7.
- Grouping by `EXTRACT(MONTH …)` alone mixes the same month of different years.
- `ROUND` on `double precision` with a digits argument isn't allowed in Postgres (`ROUND(x::numeric, 2)`).
- `TO_CHAR` output is **text** — don't sort by it ('Apr' < 'Jan').

## Dialect notes
| Purpose | PostgreSQL | MySQL | SQL Server |
|---|---|---|---|
| Substring | `SUBSTRING(s, i, n)` | same | same |
| Find position | `STRPOS(s, x)` | `LOCATE(x, s)` | `CHARINDEX(x, s)` |
| Truncate date | `DATE_TRUNC('month', d)` | `DATE_FORMAT(d, '%Y-%m-01')` | `DATETRUNC(month, d)` (2022+) |
| Date diff (days) | `d1 - d2` | `DATEDIFF(d1, d2)` | `DATEDIFF(day, d2, d1)` |
| Add interval | `d + INTERVAL '1 day'` | `DATE_ADD(d, INTERVAL 1 DAY)` | `DATEADD(day, 1, d)` |
| Format date | `TO_CHAR(d, 'YYYY-MM')` | `DATE_FORMAT(d, '%Y-%m')` | `FORMAT(d, 'yyyy-MM')` |
| Length | `LENGTH` | `CHAR_LENGTH` (`LENGTH` = bytes!) | `LEN` (ignores trailing spaces) |
