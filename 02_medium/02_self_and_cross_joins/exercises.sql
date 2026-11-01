-- =============================================================================
-- 02_medium/02 · Self Joins & Cross Joins — EXERCISES
-- Uses: self/cross joins + joins (01) + GROUP BY (easy/11) + NULLs (easy/08)
--       + functions (easy/12)
-- =============================================================================


-- Q1. Org chart list: every employee's full name, job title, manager's full
--     name ('(none)' for the top) and manager's job title.
--     Expected: 20 rows; Anita Sharma -> '(none)'



-- Q2. For each manager: name, number of direct reports, and the average salary
--     of their direct reports (2 decimals). Most reports first.
--     Expected: 8 managers; Anita, Sara and Tom each have 4



-- Q3. Employees whose department is different from their manager's department.
--     First use <>, then IS DISTINCT FROM, and explain the difference.
--     Expected: 1 row with <> (Riya), 6 rows with IS DISTINCT FROM



-- Q4. Every referred customer with the name of the customer who referred them,
--     and — if any — the name of whoever referred the referrer.
--     Expected: 10 rows; Rohan <- Diya <- Aarav



-- Q5. Pairs of customers living in the same city (each pair listed once),
--     with the city and both full names.
--     Expected: 4 pairs (Mumbai, London, Toronto, Kolkata)



-- Q6. Pairs of products in the same category whose prices are at most 20 apart.
--     Show the category NAME too (join categories) and the price difference.
--     Expected: 4 pairs



-- Q7. Payments grid: total collected for every combination of year (2023–2025)
--     and payment method, showing 0 where nothing was collected.
--     Expected: 15 rows; 2024 bank_transfer = 0, 2025 cash = 0, 2024 card = 10103.84
