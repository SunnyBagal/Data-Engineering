-- =============================================================================
-- 01_easy/12 · Built-in Functions — EXERCISES
-- Uses: functions + GROUP BY (11) + aggregates (10) + ORDER BY (09)
--       + NULLs (08) + WHERE (07) + DML in a transaction (05)
-- =============================================================================


-- Q1. Customer badge: show 'A. SHAH' style names (first initial, dot, space,
--     last name in capitals) and the username part of the email
--     (before the @) for every customer.
--     Expected: 20 rows; customer 17 -> 'M. IYER', 'meera.iyer'



-- Q2. Which product has the longest name, and how many characters is it?
--     Then list products whose name has more than one word AND whose first
--     word is longer than 6 characters (hint: SPLIT_PART on ' ').
--     Expected: 'Noise Cancelling Headphones' (27)



-- Q3. Years of service as of 2025-11-01 for every employee (whole years),
--     and in a separate query: how many employees have 5+ years?
--     Expected: Anita has 10 years; 12 employees have 5+ years



-- Q4. On which weekday were the most orders placed? Show weekday name and
--     count for all 7 days, sorted by count (highest first).
--     Expected: Friday 16



-- Q5. Count customers with a phone number per country calling code
--     (the text before the first '-'), largest first.
--     Expected: +1 → 6, +91 → 4, +44 → 2, +49 → 1



-- Q6. New pricing preview for in-stock products: show name, current price,
--     price rounded UP to the next whole 10, and a "charm" price that ends in
--     .99 (CEIL(price) - 0.01). Then, inside a transaction, apply the charm
--     price to all Accessories (category 4), show the updated rows, and ROLLBACK.
--     Expected: Wireless Mouse 25.00 -> next_ten 30 -> charm 24.99



-- Q7. Monthly collections report for 2024: one row per month with a label like
--     'Jan 2024', the amount collected, and the label must sort correctly
--     (chronologically, not alphabetically).
--     Expected: 12 rows, Jan 2024 = 2225.00, Nov 2024 = 2624.79
