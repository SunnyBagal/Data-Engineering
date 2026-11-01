-- =============================================================================
-- 03_hard/08 · Functions & Stored Procedures — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;


-- Q1. Reads tables -> not IMMUTABLE; no side effects -> STABLE.
CREATE OR REPLACE FUNCTION lab.order_total(p_order_id INT)
RETURNS NUMERIC
LANGUAGE sql STABLE
AS $$
    SELECT ROUND(SUM(quantity * unit_price * (1 - discount)), 2)
    FROM public.order_items
    WHERE order_id = p_order_id;
$$;

SELECT order_id, lab.order_total(order_id) AS total
FROM orders
WHERE lab.order_total(order_id) > 2000
ORDER BY total DESC;


-- Q2.
CREATE OR REPLACE FUNCTION lab.customer_ltv(p_customer_id INT)
RETURNS NUMERIC
LANGUAGE sql STABLE
AS $$
    SELECT COALESCE(SUM(lab.order_total(o.order_id)), 0)
    FROM public.orders o
    WHERE o.customer_id = p_customer_id
      AND o.status NOT IN ('cancelled', 'returned');
$$;

SELECT lab.customer_ltv(1) AS aarav, lab.customer_ltv(19) AS nisha;     -- 6725.84 | 0
-- Performance note: calling a per-order function per customer is fine for a
-- handful of rows; for a full report, one set-based query is much faster.


-- Q3. RANK() keeps ties; WHERE on the rank needs a subquery.
CREATE OR REPLACE FUNCTION lab.top_customers(p_country TEXT, p_n INT DEFAULT 3)
RETURNS TABLE (customer TEXT, ltv NUMERIC, rank BIGINT)
LANGUAGE sql STABLE
AS $$
    SELECT customer, ltv, rnk
    FROM (SELECT c.first_name || ' ' || c.last_name AS customer,
                 lab.customer_ltv(c.customer_id)      AS ltv,
                 RANK() OVER (ORDER BY lab.customer_ltv(c.customer_id) DESC) AS rnk
          FROM public.customers c
          WHERE c.country = p_country) x
    WHERE rnk <= p_n
    ORDER BY rnk;
$$;

SELECT * FROM lab.top_customers('USA');

SELECT co.country, t.*
FROM (SELECT DISTINCT country FROM customers) co
CROSS JOIN LATERAL lab.top_customers(co.country, 1) t
ORDER BY t.ltv DESC;


-- Q4. RETURN QUERY appends a query's rows to the function's result.
--     Output column names are prefixed (o_…) so they can't clash with table
--     columns inside the body.
CREATE OR REPLACE FUNCTION lab.days_between_orders(p_customer_id INT)
RETURNS TABLE (o_order_id INT, o_order_date DATE, gap_days INT)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.customers WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'customer % not found', p_customer_id;
    END IF;

    RETURN QUERY
    SELECT o.order_id,
           o.order_date::date,
           o.order_date::date - LAG(o.order_date::date) OVER (ORDER BY o.order_date)
    FROM public.orders o
    WHERE o.customer_id = p_customer_id
    ORDER BY o.order_date;
END;
$$;

SELECT * FROM lab.days_between_orders(1);
-- SELECT * FROM lab.days_between_orders(999);   -- ERROR: customer 999 not found


-- Q5. Lock the order row first so two cancellations can't race (topic 07).
CREATE OR REPLACE PROCEDURE lab.cancel_order(p_order_id INT)
LANGUAGE plpgsql
AS $$
DECLARE v_status TEXT;
BEGIN
    SELECT status INTO v_status
    FROM public.orders WHERE order_id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN                                    -- FOUND = did the last query return a row?
        RAISE EXCEPTION 'order % not found', p_order_id;
    ELSIF v_status NOT IN ('pending', 'shipped') THEN
        RAISE EXCEPTION 'order % is % and cannot be cancelled', p_order_id, v_status;
    END IF;

    UPDATE public.products p                             -- restock (set-based)
    SET stock_qty = p.stock_qty + oi.quantity
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id AND oi.product_id = p.product_id;

    DELETE FROM public.payments WHERE order_id = p_order_id;

    UPDATE public.orders SET status = 'cancelled', shipped_date = NULL
    WHERE order_id = p_order_id;
END;
$$;

BEGIN;
CALL lab.cancel_order(45);
SELECT order_id, status FROM orders WHERE order_id = 45;           -- cancelled
SELECT stock_qty FROM products WHERE product_id = 3;               -- 4 (was 3)
CALL lab.cancel_order(43);                                          -- shipped: allowed, payment removed
SELECT COUNT(*) AS payments_43 FROM payments WHERE order_id = 43;  -- 0
-- CALL lab.cancel_order(1);   -- ERROR: order 1 is delivered and cannot be cancelled
ROLLBACK;


-- Q6. TRIM + LOWER are deterministic -> the function may be IMMUTABLE,
--     which is required for use in an index.
CREATE OR REPLACE FUNCTION lab.normalize_email(p_email TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
AS $$ SELECT LOWER(TRIM(p_email)) $$;

CREATE TABLE lab.customers_copy AS SELECT * FROM customers;
CREATE UNIQUE INDEX uq_customers_copy_email ON lab.customers_copy (lab.normalize_email(email));

-- INSERT INTO lab.customers_copy (customer_id, first_name, last_name, email, country, signup_date)
-- VALUES (99, 'A', 'S', ' Aarav.Shah@MAIL.com ', 'India', CURRENT_DATE);
--   ERROR: duplicate key value violates unique constraint "uq_customers_copy_email"


-- Q7. Loop over the column list; build one COUNT query per column with %I.
CREATE OR REPLACE FUNCTION lab.null_report(p_table TEXT)
RETURNS TABLE (column_name TEXT, null_count BIGINT)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_col TEXT;
BEGIN
    FOR v_col IN
        SELECT c.column_name FROM information_schema.columns c
        WHERE c.table_schema = 'public' AND c.table_name = p_table
        ORDER BY c.ordinal_position
    LOOP
        column_name := v_col;                                   -- set the OUT column
        EXECUTE format('SELECT COUNT(*) FROM public.%I WHERE %I IS NULL', p_table, v_col)
           INTO null_count;
        RETURN NEXT;                                            -- emit the current row
    END LOOP;
END;
$$;

SELECT * FROM lab.null_report('customers');

DROP SCHEMA lab CASCADE;
