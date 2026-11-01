-- =============================================================================
-- 03_hard/03 · Recursive CTEs — EXERCISES
-- Uses: recursion + window functions (01, 02) + CTEs (medium/06)
--       + joins (medium/01, 02) + aggregates (easy/10, 11)
-- =============================================================================


-- Q1. Print the org chart: every employee with level (CEO = 1), indented name,
--     and the full path from the CEO ('Anita > Rahul > Sara').
--     Sort so that each manager is followed by their team (depth-first).
--     Expected: 20 rows; Neha's path = 'Anita > Rahul > Sara > Arjun > Neha'



-- Q2. For every manager (anyone with at least one report), the TOTAL number of
--     people below them at any depth and the total payroll of their subtree
--     (excluding themselves). Sort by headcount descending.
--     Expected: 8 managers; Anita 19 (1892000.00), Priya 7, Rahul 6, Sara 5



-- Q3. The reporting line of Kevin Lee (emp 20) as a single string from the
--     top: 'Anita > Rahul > Sara > Kevin', plus the number of levels above him.
--     Expected: 3 levels above



-- Q4. Category tree: for every category show its full path and the number of
--     products in it INCLUDING all subcategories.
--     Expected: Electronics 13, Computers 10, Home & Kitchen 6, Books 5, Gaming 0



-- Q5. Referral tree of Aarav (customer 1): every descendant, their generation,
--     and the revenue each generation brought (non-cancelled orders).
--     Expected: 3 generations; generation 1 = Isha, Diya, Ananya



-- Q6. Using recursion (NOT generate_series), produce every date in
--     September 2025 and count logins per day, showing 0 for days without logins.
--     Expected: 30 rows; Sep 3 has the most logins (8)



-- Q7. Bill of materials: create a temp table parts(parent, child, qty) for a
--     bicycle:  bike→frame 1, bike→wheel 2, wheel→spoke 32, wheel→rim 1,
--     wheel→tyre 1, bike→handlebar 1, handlebar→grip 2.
--     How many of each leaf part are needed to build 10 bikes?
--     Expected: spoke 640, rim 20, tyre 20, grip 20, frame 10
