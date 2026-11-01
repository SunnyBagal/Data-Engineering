-- =============================================================================
-- 02_medium/03 · Subqueries — LESSON
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Scalar subqueries: one value
-- -----------------------------------------------------------------------------

-- Products priced above the average. Aggregates aren't allowed in WHERE, but a
-- subquery that RETURNS an aggregate is just a value.
SELECT product_name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)       -- runs once: 392.71
ORDER BY price DESC;                                   -- 8 rows

-- Scalar subquery in SELECT: show the global value next to each row.
SELECT product_name,
       price,
       (SELECT MAX(price) FROM products)                     AS max_price,
       ROUND(100 * price / (SELECT MAX(price) FROM products), 1) AS pct_of_max
FROM products
ORDER BY price DESC
LIMIT 5;

-- The most recently hired employee (row of the max, via subquery).
SELECT first_name, last_name, hire_date
FROM employees
WHERE hire_date = (SELECT MAX(hire_date) FROM employees);

-- A scalar subquery returning 0 rows yields NULL; more than 1 row is an error:
-- SELECT (SELECT order_id FROM orders WHERE customer_id = 1);
--   ERROR: more than one row returned by a subquery used as an expression


-- -----------------------------------------------------------------------------
-- 2. IN / NOT IN with a subquery: membership
-- -----------------------------------------------------------------------------

-- Customers who have bought at least one laptop (category 3).
-- The subquery can contain joins; it just has to return ONE column.
SELECT customer_id, first_name, last_name
FROM customers
WHERE customer_id IN (
        SELECT o.customer_id
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.order_id
        JOIN products p     ON p.product_id = oi.product_id
        WHERE p.category_id = 3
      )
ORDER BY customer_id;                                  -- 8 customers, each listed ONCE
-- A plain JOIN would list a customer once per laptop line (Aarav 4 times).

-- Products that were never ordered.
SELECT product_id, product_name
FROM products
WHERE product_id NOT IN (SELECT product_id FROM order_items);  -- safe: product_id is NOT NULL


-- -----------------------------------------------------------------------------
-- 3. EXISTS / NOT EXISTS: semi-joins and anti-joins
-- -----------------------------------------------------------------------------

-- Correlated: the inner query references c (the outer row).
-- EXISTS stops at the first matching order — it never multiplies rows.
SELECT c.customer_id, c.first_name
FROM customers c
WHERE EXISTS (
        SELECT 1                                       -- the select list is irrelevant
        FROM orders o
        WHERE o.customer_id = c.customer_id            -- correlation
          AND o.status = 'cancelled'
      );                                               -- customers with a cancellation

-- NOT EXISTS: customers who never ordered. NULL-safe, unlike NOT IN.
SELECT c.customer_id, c.first_name
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- Why NOT EXISTS beats NOT IN: referred_by contains NULLs.
SELECT COUNT(*) AS not_in_result
FROM customers c WHERE c.customer_id NOT IN (SELECT referred_by FROM customers);   -- 0 (!)
SELECT COUNT(*) AS not_exists_result
FROM customers c WHERE NOT EXISTS (SELECT 1 FROM customers r WHERE r.referred_by = c.customer_id);  -- 12


-- -----------------------------------------------------------------------------
-- 4. Correlated subqueries: "compared with MY group"
-- -----------------------------------------------------------------------------

-- Employees earning more than the average of THEIR OWN department.
-- For each outer row e, the inner query computes the average for e.dept_id.
SELECT e.first_name, e.dept_id, e.salary
FROM employees e
WHERE e.salary > (SELECT AVG(x.salary)
                  FROM employees x
                  WHERE x.dept_id = e.dept_id)
ORDER BY e.dept_id, e.salary DESC;                     -- 7 rows
-- Note: CEO and contractor (dept NULL) never qualify — x.dept_id = NULL matches
-- nothing, so the average is NULL and "salary > NULL" is UNKNOWN.

-- Latest order per customer: keep the order whose date equals that customer's max.
SELECT o.customer_id, o.order_id, o.order_date
FROM orders o
WHERE o.order_date = (SELECT MAX(o2.order_date)
                      FROM orders o2
                      WHERE o2.customer_id = o.customer_id)
ORDER BY o.customer_id;                                -- 18 rows

-- Correlated scalar subquery in SELECT: number of orders per customer.
-- Readable, but runs once per customer; a JOIN + GROUP BY scales better.
SELECT c.first_name,
       (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS orders
FROM customers c
ORDER BY orders DESC;


-- -----------------------------------------------------------------------------
-- 5. Derived tables: subqueries in FROM
-- -----------------------------------------------------------------------------

-- Average order value: two levels of aggregation (SUM per order, then AVG).
-- AVG(SUM(...)) is not allowed directly, so the inner query does the first step.
SELECT ROUND(AVG(order_total), 2) AS avg_order_value,
       ROUND(MAX(order_total), 2) AS biggest_order
FROM (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS order_total
    FROM order_items
    GROUP BY order_id
) AS t;                                                -- the alias is mandatory

-- Derived table joined to other tables: AOV per country (excluding cancellations).
SELECT c.country,
       COUNT(*)                   AS orders,
       ROUND(AVG(t.order_total), 2) AS avg_order_value
FROM (SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS order_total
      FROM order_items GROUP BY order_id) t
JOIN orders o    ON o.order_id    = t.order_id
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status <> 'cancelled'
GROUP BY c.country
ORDER BY avg_order_value DESC;

-- Filtering on a computed column: the alias exists once we're "outside".
SELECT *
FROM (SELECT product_name, price - cost AS margin FROM products) p
WHERE margin > 300;                                    -- alias usable here


-- -----------------------------------------------------------------------------
-- 6. ANY / ALL
-- -----------------------------------------------------------------------------

-- More expensive than EVERY phone (i.e. > max phone price 999).
SELECT product_name, price
FROM products
WHERE price > ALL (SELECT price FROM products WHERE category_id = 5);

-- More expensive than AT LEAST ONE phone (i.e. > min phone price 99).
SELECT COUNT(*) AS pricier_than_some_phone
FROM products
WHERE price > ANY (SELECT price FROM products WHERE category_id = 5);

-- Gotcha: ALL over an EMPTY set is TRUE -> every product "beats" the Gaming category.
SELECT COUNT(*) AS beats_empty_category
FROM products
WHERE price > ALL (SELECT price FROM products WHERE category_id = 12);   -- 24


-- -----------------------------------------------------------------------------
-- 7. Subqueries in HAVING, UPDATE and DELETE
-- -----------------------------------------------------------------------------

-- Categories whose revenue is above the average category revenue (7 categories sold).
SELECT cat.category_name,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2) AS revenue
FROM order_items oi
JOIN products p     ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
GROUP BY cat.category_name
HAVING SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) >
       (SELECT AVG(cat_rev) FROM (
            SELECT SUM(oi2.quantity * oi2.unit_price * (1 - oi2.discount)) AS cat_rev
            FROM order_items oi2
            JOIN products p2 ON p2.product_id = oi2.product_id
            GROUP BY p2.category_id) x)
ORDER BY revenue DESC;                                 -- Laptops, Phones

BEGIN;
-- Discontinue products that have never been sold (subquery in UPDATE's WHERE).
UPDATE products SET is_discontinued = TRUE
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = products.product_id)
RETURNING product_name;

-- Delete logins of customers who never ordered (subquery in DELETE).
DELETE FROM logins
WHERE customer_id NOT IN (SELECT customer_id FROM orders)
RETURNING login_id, customer_id;                       -- Nisha's login
ROLLBACK;
