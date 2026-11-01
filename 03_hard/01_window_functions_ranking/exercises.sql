-- =============================================================================
-- 03_hard/01 · Window Functions — Ranking — EXERCISES
-- Uses: ranking windows + CTEs (medium/06) + joins (medium/01)
--       + GROUP BY (easy/11) + DML/transactions (medium/08, 10)
-- =============================================================================


-- Q1. For Engineering (dept 1), show each employee with ROW_NUMBER, RANK and
--     DENSE_RANK by salary (highest first). Explain the difference on the
--     95,000 tie.
--     Expected: ranks 1,2,3,4,4,6 ; dense ranks 1,2,3,4,4,5



-- Q2. Every employee with a department, plus: department average salary,
--     difference from that average, and their salary as % of the department's
--     total payroll (1 decimal). One query, no GROUP BY.
--     Expected: 18 rows; Rahul: 180000, avg 116666.67, +63333.33, 25.7 %



-- Q3. The 2nd highest DISTINCT salary in each department, with the name(s).
--     Expected: Sara (1), Tom (2), Aman (3), Sanjay (4)



-- Q4. Top 2 products by revenue in every category (ties included), with the
--     category name, product name, revenue (2 decimals) and rank.
--     Expected: 14 rows; Laptops: GamerX 17 Laptop 6270.00, ProBook 14 Laptop 5890.00



-- Q5. Each customer's FIRST order (earliest) with its order total. Use
--     ROW_NUMBER, then check your result with DISTINCT ON.
--     Expected: 18 rows; Aarav's first order is order 1 (1225.00)



-- Q6. Deduplicate logins: keep the earliest login per customer per calendar
--     day. Inside a transaction, delete the others, show how many rows remain,
--     then ROLLBACK.
--     Expected: 7 deleted, 30 remain



-- Q7. Rank sales reps (employees appearing on orders) by revenue of delivered
--     orders within each year — show year, rep, revenue and rank — and keep
--     only the best rep of each year.
--     Expected: 2023 Pooja 2841.10, 2024 James 4423.00, 2025 James 2238.50
