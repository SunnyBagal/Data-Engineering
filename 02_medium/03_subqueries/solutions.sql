-- =============================================================================
-- 02_medium/03 · Subqueries — SOLUTIONS
-- =============================================================================


-- Q1. The same uncorrelated scalar subquery used twice; the planner evaluates
--     it once per occurrence (a CTE or CROSS JOIN could compute it once).
SELECT product_name,
       price,
       ROUND(price - (SELECT AVG(price) FROM products), 2) AS above_avg
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY above_avg DESC;


-- Q2a. IN: the subquery returns the set of laptop buyers.
SELECT first_name || ' ' || last_name AS customer, country
FROM customers
WHERE customer_id IN (SELECT o.customer_id
                      FROM orders o
                      JOIN order_items oi ON oi.order_id = o.order_id
                      JOIN products p     ON p.product_id = oi.product_id
                      WHERE p.category_id = 3);

-- Q2b. EXISTS: correlated; stops scanning at the first laptop found.
SELECT c.first_name || ' ' || c.last_name AS customer, c.country
FROM customers c
WHERE EXISTS (SELECT 1
              FROM orders o
              JOIN order_items oi ON oi.order_id = o.order_id
              JOIN products p     ON p.product_id = oi.product_id
              WHERE o.customer_id = c.customer_id
                AND p.category_id = 3);


-- Q3.
SELECT c.first_name, c.last_name
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);
-- orders.customer_id is NOT NULL, so the NOT IN list never contains NULL and
-- NOT IN works. customers.referred_by IS nullable: one NULL in the list makes
-- every "x NOT IN (...)" UNKNOWN -> zero rows. NOT EXISTS is safe in both cases.


-- Q4. The same correlated subquery appears in SELECT (to show) and WHERE (to filter).
SELECT e.first_name, e.dept_id, e.salary,
       (SELECT ROUND(AVG(x.salary), 2) FROM employees x WHERE x.dept_id = e.dept_id) AS dept_avg
FROM employees e
WHERE e.salary > (SELECT AVG(x.salary) FROM employees x WHERE x.dept_id = e.dept_id)
ORDER BY e.dept_id, e.salary DESC;
-- Window functions (03_hard/02) do this in one pass: AVG(salary) OVER (PARTITION BY dept_id).


-- Q5.
SELECT c.first_name || ' ' || c.last_name AS customer,
       o.order_id, o.order_date, o.status
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_date = (SELECT MAX(o2.order_date)
                      FROM orders o2
                      WHERE o2.customer_id = o.customer_id)
ORDER BY c.customer_id;
-- If a customer had two orders at the exact same max timestamp, both would be
-- returned. ROW_NUMBER() (03_hard/01) lets you choose exactly one.


-- Q6. Aggregate lines -> orders in the derived table, then orders -> countries.
SELECT c.country,
       COUNT(*)                     AS orders,
       ROUND(AVG(t.order_total), 2) AS avg_order_value
FROM (SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS order_total
      FROM order_items
      GROUP BY order_id) AS t
JOIN orders o    ON o.order_id    = t.order_id
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status <> 'cancelled'
GROUP BY c.country
ORDER BY avg_order_value DESC;


-- Q7a. > ALL = greater than the maximum of the list.
SELECT product_name, price
FROM products
WHERE price > ALL (SELECT price FROM products WHERE category_id = 5);
-- Equivalent and often clearer: WHERE price > (SELECT MAX(price) FROM products WHERE category_id = 5)

-- Q7b. Inside UPDATE, the target table is referenced by its name (or an alias).
BEGIN;
UPDATE products p
SET stock_qty = 0
WHERE p.price > (SELECT AVG(x.price) FROM products x WHERE x.category_id = p.category_id)
RETURNING p.product_name, p.category_id, p.price;
ROLLBACK;
