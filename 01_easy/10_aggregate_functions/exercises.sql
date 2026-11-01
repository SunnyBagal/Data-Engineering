-- =============================================================================
-- 01_easy/10 · Aggregate Functions — EXERCISES
-- Uses: aggregates + NULLs (08) + WHERE (07) + expressions (06) + types (02)
-- =============================================================================


-- Q1. Sales KPIs from order_items in one row: number of lines, units sold,
--     total revenue (qty * price * (1 - discount), 2 decimals) and the
--     number of distinct products ever sold.
--     Expected: 78 | 95 | 31730.52 | 20



-- Q2. Payroll of ACTIVE employees: headcount, total, average (2 decimals),
--     median, lowest and highest salary.
--     Expected: 19 | 2090000.00 | 110000.00 | 95000 | 55000.00 | 250000.00



-- Q3. Orders placed in calendar year 2024: how many, the first and last
--     order timestamp, and how many of them were handled online (no rep).
--     Expected: 14 | 2024-01-12 16:20 | 2024-12-20 13:30 | 4



-- Q4. Payments: total collected, number of payments, average payment
--     (2 decimals), and the total collected by card only (use FILTER).
--     Expected: 28049.57 | 43 | 652.32 | 19673.43



-- Q5. Inventory valuation across all products: total units in stock, stock
--     value at list price, stock value at cost, and the potential gross profit
--     (difference). Then answer: what share (%) of products are out of stock?
--     Expected: 1356 | 160538.40 | 93405.00 | 67133.40  ;  20.83 %



-- Q6. One row with: a comma-separated, alphabetical list of the names of
--     discontinued products, and booleans saying whether ALL products have
--     attributes (NOT NULL) and whether ANY product's price is above 2000.
--     Expected: 'Budget Laptop 15, Robot Vacuum' | false | true



-- Q7. The finance team asks: "How much has been paid for order 44, and how much
--     for order 6?" Write ONE query per order that returns 0 (not NULL) when
--     nothing is paid. Then explain: why is SUM(amount) over all payments
--     (28049.57) lower than total line revenue (31730.52)?
--     Expected: 0 for order 44, 1350.00 for order 6
