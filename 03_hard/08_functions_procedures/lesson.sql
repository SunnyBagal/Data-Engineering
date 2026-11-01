-- =============================================================================
-- 03_hard/08 · Functions & Stored Procedures — LESSON
-- All objects are created in schema "sandbox" and dropped at the end.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;


-- -----------------------------------------------------------------------------
-- 1. A scalar SQL function
-- -----------------------------------------------------------------------------

-- p_ prefix avoids clashing with column names. STABLE: reads tables but gives
-- the same answer for the duration of one statement.
CREATE OR REPLACE FUNCTION order_total(p_order_id INT)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
    SELECT ROUND(SUM(quantity * unit_price * (1 - discount)), 2)
    FROM order_items
    WHERE order_id = p_order_id;
$$;

SELECT order_total(33) AS total_33;                      -- 2624.79

-- Functions are usable anywhere an expression is: SELECT, WHERE, ORDER BY…
SELECT order_id, order_total(order_id) AS total
FROM orders
WHERE order_total(order_id) > 2000
ORDER BY total DESC;


-- -----------------------------------------------------------------------------
-- 2. IMMUTABLE functions: pure calculations (and indexable)
-- -----------------------------------------------------------------------------

-- No table access, same input -> same output forever -> IMMUTABLE.
-- STRICT: if any argument is NULL, return NULL without running the body.
CREATE OR REPLACE FUNCTION net_amount(p_qty INT, p_price NUMERIC, p_discount NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE STRICT PARALLEL SAFE
AS $$ SELECT p_qty * p_price * (1 - p_discount) $$;

SELECT net_amount(2, 100, 0.25) AS net, net_amount(1, NULL, 0) AS null_in_null_out;

-- Only IMMUTABLE functions may appear in index expressions:
CREATE INDEX idx_items_net ON public.order_items (net_amount(quantity, unit_price, discount));
DROP INDEX idx_items_net;                    -- (demo only; don't leave it on the shared table)


-- -----------------------------------------------------------------------------
-- 3. Default and named parameters
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION price_with_tax(p_price NUMERIC, p_rate NUMERIC DEFAULT 0.18)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE
AS $$ SELECT ROUND(p_price * (1 + p_rate), 2) $$;

SELECT price_with_tax(100)                 AS default_rate,   -- 118.00
       price_with_tax(100, 0.05)           AS positional,     -- 105.00
       price_with_tax(p_rate => 0.12, p_price => 100) AS named; -- 112.00


-- -----------------------------------------------------------------------------
-- 4. Set-returning functions: RETURNS TABLE
-- -----------------------------------------------------------------------------

-- A parameterized "view": top N products of a category by revenue.
CREATE OR REPLACE FUNCTION top_products(p_category_id INT, p_limit INT DEFAULT 3)
RETURNS TABLE (product_name TEXT, units BIGINT, revenue NUMERIC)
LANGUAGE sql
STABLE
AS $$
    SELECT p.product_name::text,
           SUM(oi.quantity),
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2)
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    WHERE p.category_id = p_category_id
    GROUP BY p.product_name
    ORDER BY 3 DESC
    LIMIT p_limit;
$$;

SELECT * FROM top_products(3);              -- laptops, default 3 rows
SELECT * FROM top_products(4, 2);           -- accessories, 2 rows

-- Call it for every category with LATERAL (03_hard/04).
SELECT c.category_name, t.*
FROM categories c
CROSS JOIN LATERAL top_products(c.category_id, 1) t;


-- -----------------------------------------------------------------------------
-- 5. PL/pgSQL: variables, IF, RAISE, INTO STRICT
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION customer_tier(p_customer_id INT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_spend  NUMERIC;                       -- local variable
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'customer % does not exist', p_customer_id
              USING ERRCODE = 'no_data_found';           -- a proper SQLSTATE for callers
    END IF;

    SELECT COALESCE(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 0)
    INTO v_spend
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id = p_customer_id
      AND o.status NOT IN ('cancelled', 'returned');

    IF v_spend >= 3000 THEN
        RETURN 'gold';
    ELSIF v_spend >= 1000 THEN
        RETURN 'silver';
    ELSIF v_spend > 0 THEN
        RETURN 'bronze';
    ELSE
        RETURN 'none';
    END IF;
END;
$$;

SELECT customer_id, first_name, customer_tier(customer_id) AS tier
FROM customers ORDER BY customer_id;

-- SELECT customer_tier(999);
--   ERROR: customer 999 does not exist


-- -----------------------------------------------------------------------------
-- 6. Exceptions: catch specific errors
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION safe_ratio(p_a NUMERIC, p_b NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
    RETURN p_a / p_b;
EXCEPTION
    WHEN division_by_zero THEN               -- catch ONLY what you expect
        RAISE NOTICE 'division by zero for %/% — returning NULL', p_a, p_b;
        RETURN NULL;
END;
$$;

SELECT safe_ratio(10, 4) AS ok, safe_ratio(10, 0) AS by_zero;
-- (For this simple case NULLIF(p_b, 0) is cheaper: an EXCEPTION block starts a
--  subtransaction on every call.)


-- -----------------------------------------------------------------------------
-- 7. Loops — and why set-based SQL is usually better
-- -----------------------------------------------------------------------------

-- Row-by-row ("slow by slow"): one UPDATE per row.
CREATE OR REPLACE FUNCTION restock_slow(p_min INT) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    r       RECORD;
    v_count INT := 0;
BEGIN
    FOR r IN SELECT product_id FROM products WHERE stock_qty < p_min AND NOT is_discontinued LOOP
        UPDATE products SET stock_qty = stock_qty + 50 WHERE product_id = r.product_id;
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$$;

-- Set-based: one statement does the same work. GET DIAGNOSTICS reads the row count.
CREATE OR REPLACE FUNCTION restock_fast(p_min INT) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE v_count INT;
BEGIN
    UPDATE products SET stock_qty = stock_qty + 50
    WHERE stock_qty < p_min AND NOT is_discontinued;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

BEGIN;
SELECT restock_slow(10) AS slow_rows;       -- 5
ROLLBACK;
BEGIN;
SELECT restock_fast(10) AS fast_rows;       -- 5, one statement
ROLLBACK;


-- -----------------------------------------------------------------------------
-- 8. Procedures: CALL, multi-step operations
-- -----------------------------------------------------------------------------

-- Place an order atomically: validate, insert header + line, reduce stock.
CREATE OR REPLACE PROCEDURE place_order(p_customer_id INT, p_product_id INT, p_qty INT,
                                        INOUT p_order_id INT DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
    v_price NUMERIC;
    v_stock INT;
BEGIN
    SELECT price, stock_qty INTO STRICT v_price, v_stock     -- STRICT: error if 0 or >1 rows
    FROM products
    WHERE product_id = p_product_id AND NOT is_discontinued
    FOR UPDATE;                                               -- lock the product row (topic 07)

    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'only % left of product %', v_stock, p_product_id;
    END IF;

    INSERT INTO orders (customer_id, order_date, status)
    VALUES (p_customer_id, now(), 'pending')
    RETURNING order_id INTO p_order_id;                       -- INOUT param returns the new id

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (p_order_id, p_product_id, p_qty, v_price);

    UPDATE products SET stock_qty = stock_qty - p_qty WHERE product_id = p_product_id;
END;
$$;

BEGIN;                                       -- wrapped only to keep shared data unchanged
CALL place_order(20, 5, 3);                  -- returns p_order_id (47 on a fresh DB; sequences never roll back)
SELECT stock_qty FROM products WHERE product_id = 5;          -- 197
-- CALL place_order(20, 3, 99);   -- ERROR: only 3 left of product 3 (nothing inserted: atomic)
ROLLBACK;

-- DO blocks: anonymous, one-off PL/pgSQL (e.g. in migration scripts).
DO $$
BEGIN
    RAISE NOTICE 'customers: %, orders: %',
        (SELECT COUNT(*) FROM customers), (SELECT COUNT(*) FROM orders);
END;
$$;


-- -----------------------------------------------------------------------------
-- 9. Dynamic SQL — the safe way
-- -----------------------------------------------------------------------------

-- Count rows of any table in public. %I quotes the identifier, so a value like
-- 'orders; DROP TABLE customers' becomes a (non-existent) table NAME, not code.
CREATE OR REPLACE FUNCTION row_count(p_table TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
AS $$
DECLARE v_n BIGINT;
BEGIN
    EXECUTE format('SELECT COUNT(*) FROM public.%I', p_table) INTO v_n;
    RETURN v_n;
END;
$$;

SELECT t, row_count(t) FROM unnest(ARRAY['customers','orders','order_items']) AS t;
-- SELECT row_count('orders; DROP TABLE customers');
--   ERROR: relation "public.orders; DROP TABLE customers" does not exist   (safe!)

-- Values go in with USING ($1, $2 …) — parameters, never concatenation.
DO $$
DECLARE v_n BIGINT;
BEGIN
    EXECUTE 'SELECT COUNT(*) FROM public.orders WHERE status = $1' INTO v_n USING 'delivered';
    RAISE NOTICE 'delivered orders: %', v_n;
END;
$$;


-- -----------------------------------------------------------------------------
-- 10. Inspecting and dropping functions
-- -----------------------------------------------------------------------------

SELECT p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       CASE p.provolatile WHEN 'i' THEN 'IMMUTABLE' WHEN 's' THEN 'STABLE' ELSE 'VOLATILE' END AS volatility,
       CASE p.prokind WHEN 'p' THEN 'procedure' ELSE 'function' END AS kind
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'sandbox'
ORDER BY name;

-- Functions are identified by name + argument types (overloading is allowed):
DROP FUNCTION safe_ratio(NUMERIC, NUMERIC);

RESET search_path;
DROP SCHEMA sandbox CASCADE;
