-- =============================================================================
-- 03_hard/13 · Interview & Real-World SQL Patterns — EXERCISES
-- Uses: EVERYTHING — windows, CTEs, recursion, LATERAL, set operations,
--       conditional aggregation, NULL handling, date functions.
-- For each question first name the PATTERN, then write the query.
-- =============================================================================


-- Q1. For each country, the top 2 customers by lifetime spend (non-cancelled,
--     non-returned orders), ties included, with their rank.
--     Expected: 9 rows — e.g. India Aarav / Isha, USA John / Maria; Canada has only Chloe (Lucas never ordered)



-- Q2. Each customer's LONGEST login streak (consecutive calendar days),
--     one row per customer who ever logged in, longest first.
--     Expected: 1 -> 7, 6 -> 6, 3 -> 3, 12 -> 3, 13 -> 2, 2 -> 1, 19 -> 1



-- Q3. Number of sessions per customer, where a session ends after more than
--     30 minutes without a login. Also the average events per session.
--     Expected: customer 1 -> 12 sessions, customer 13 -> 4



-- Q4. Customers whose non-cancelled revenue grew from 2023 to 2024, with both
--     values and the growth %.
--     Expected: customers 1, 4, 12



-- Q5. New vs returning customers per year: a customer is "new" in the year of
--     their first non-cancelled order and "returning" in any later year in
--     which they order again.
--     Expected: 2023 11 new / 0 returning, 2024 6 / 6, 2025 1 / 11



-- Q6. "Customers who bought the Mechanical Keyboard (product 6) also bought…":
--     other products in the same orders, ranked by how often.
--     Expected: 27in 4K Monitor 2, Wireless Mouse 2, then 3 products once



-- Q7. Data-quality sweep, one query each:
--     (a) days in September 2025 with no logins at all;
--     (b) customers who bought from every ROOT category (relational division);
--     (c) the 2nd most expensive product in each root category.
--     Expected: (a) 15 days  (b) customer 12  (c) 3 rows
