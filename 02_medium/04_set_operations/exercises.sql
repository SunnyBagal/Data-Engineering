-- =============================================================================
-- 02_medium/04 · Set Operations — EXERCISES
-- Uses: set operators + subqueries (03) + joins (01) + GROUP BY (easy/11)
--       + functions (easy/12) + DDL/DML (easy/03, 05)
-- =============================================================================


-- Q1. Build a single contact directory of all customers and employees with
--     columns: person_type ('customer'/'employee'), full_name, email, location
--     (customer city / employee's department location — join departments).
--     Sort by full_name.
--     Expected: 40 rows



-- Q2. Which first names belong to both a customer and an employee?
--     And which employee first names do NOT appear among customers?
--     Expected: Meera  |  19 names



-- Q3. Lapsed customers: ordered in 2023 but not in 2024. Show their full
--     names (not just ids).
--     Expected: Isha, Diya, Chloe, Kabir, Ananya



-- Q4. Retained customers: ordered in 2023 AND 2024 AND 2025.
--     Expected: 4 customers (1, 3, 4, 12)



-- Q5. All distinct places (customer cities + department locations), and
--     separately the places that are department locations but have no customer.
--     Explain why the first list has 17 rows even though there are only
--     16 distinct non-NULL names.
--     Expected: 17 rows | Bengaluru



-- Q6. Order status summary with a final 'TOTAL' row, status rows sorted by
--     count descending and the TOTAL row always last. Include a percentage
--     column (1 decimal) — 100.0 for TOTAL.
--     Expected: delivered 36 (78.3) ... TOTAL 46 (100.0)



-- Q7. Data-quality checks with EXCEPT:
--     (a) orders that are shipped, delivered or returned but have NO payment;
--     (b) customers who log in but have never ordered.
--     Expected: (a) order 44  (b) customer 19
