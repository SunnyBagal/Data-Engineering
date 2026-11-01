-- =============================================================================
-- 01_easy/10 · Aggregate Functions — SOLUTIONS
-- =============================================================================


-- Q1. COUNT(*) counts lines; COUNT(DISTINCT product_id) counts unique products.
SELECT COUNT(*)                                              AS lines,
       SUM(quantity)                                         AS units,
       ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS revenue,
       COUNT(DISTINCT product_id)                            AS products_sold
FROM order_items;


-- Q2. WHERE removes the inactive employee before aggregation.
SELECT COUNT(*)                                            AS headcount,
       SUM(salary)                                         AS payroll,
       ROUND(AVG(salary), 2)                               AS avg_salary,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary) AS median_salary,
       MIN(salary)                                         AS lowest,     -- 55000.00 (Mark, 52000, is inactive)
       MAX(salary)                                         AS highest
FROM employees
WHERE is_active;


-- Q3. Half-open date range; COUNT(*) FILTER for the online subset.
SELECT COUNT(*)                                     AS orders_2024,
       MIN(order_date)                              AS first_order,
       MAX(order_date)                              AS last_order,
       COUNT(*) FILTER (WHERE employee_id IS NULL)  AS online_orders
FROM orders
WHERE order_date >= '2024-01-01'
  AND order_date <  '2025-01-01';


-- Q4.
SELECT SUM(amount)                                   AS total_collected,
       COUNT(*)                                      AS payments,
       ROUND(AVG(amount), 2)                         AS avg_payment,
       SUM(amount) FILTER (WHERE method = 'card')    AS card_total
FROM payments;
-- Portable version of the last column (no FILTER):
--   SUM(CASE WHEN method = 'card' THEN amount ELSE 0 END)


-- Q5.
SELECT SUM(stock_qty)                       AS units_in_stock,
       SUM(price * stock_qty)               AS value_at_price,
       SUM(cost  * stock_qty)               AS value_at_cost,
       SUM((price - cost) * stock_qty)      AS potential_profit
FROM products;

-- 100.0 (a numeric literal) forces decimal division instead of integer division.
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE stock_qty = 0) / COUNT(*), 2) AS pct_out_of_stock
FROM products;                                                       -- 5 / 24 = 20.83


-- Q6. STRING_AGG with FILTER limits which rows are concatenated, while the
--     BOOL_ aggregates still see every row.
SELECT STRING_AGG(product_name, ', ' ORDER BY product_name)
           FILTER (WHERE is_discontinued)        AS discontinued,
       BOOL_AND(attributes IS NOT NULL)          AS all_have_attributes,   -- false (2 NULLs)
       BOOL_OR(price > 2000)                     AS any_price_over_2000    -- true (GamerX)
FROM products;


-- Q7. SUM over zero rows is NULL -> wrap in COALESCE to report 0.
SELECT COALESCE(SUM(amount), 0) AS paid_order_44 FROM payments WHERE order_id = 44;  -- 0
SELECT COALESCE(SUM(amount), 0) AS paid_order_6  FROM payments WHERE order_id = 6;   -- 1350.00 (two parts)
-- Why paid < revenue: line revenue includes orders that were never paid —
-- cancelled (8, 15, 29), pending (45, 46) and cash-on-delivery order 44.
-- (Returned orders 4, 20, 37 were paid; refunds aren't modelled.)
