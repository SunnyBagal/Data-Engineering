-- =============================================================================
-- 03_hard/08 · Functions & Stored Procedures — EXERCISES
-- Uses: functions/procedures + window functions (01) + LATERAL (04)
--       + locking (07) + advanced DML (medium/08) + transactions (medium/10)
-- Create everything in schema "lab"; drop it at the end.
-- =============================================================================


-- Q1. lab.order_total(order_id) -> numeric (2 decimals), LANGUAGE sql, with the
--     correct volatility. Use it to list orders above 2000.
--     Expected: 33 -> 2624.79, 21 -> 2225.00, 45 -> 2200.00



-- Q2. lab.customer_ltv(customer_id) -> lifetime value from non-cancelled,
--     non-returned orders (0 if none), built ON TOP of lab.order_total.
--     Expected: customer 1 -> 6725.84, customer 19 -> 0



-- Q3. lab.top_customers(p_country TEXT, p_n INT DEFAULT 3) RETURNS TABLE
--     (customer TEXT, ltv NUMERIC, rank BIGINT) using a window function, ties
--     included. Call it for 'USA' and for every country with LATERAL.
--     Expected: USA -> John 4192.49, Maria 3718.97, Ethan 3248.00



-- Q4. lab.days_between_orders(customer_id) RETURNS TABLE (order_id, order_date,
--     gap_days) in PL/pgSQL using RETURN QUERY, raising an exception with a
--     clear message when the customer doesn't exist.
--     Expected: customer 1 gaps NULL, 62, 135, 223, 274, 285



-- Q5. Procedure lab.cancel_order(p_order_id INT): only 'pending' or 'shipped'
--     orders can be cancelled (raise an exception otherwise); set status
--     'cancelled', clear shipped_date, put the items back in stock, and delete
--     any payments. Test it on order 45 and 43 inside a transaction, then
--     ROLLBACK. Also show it refusing order 1 (delivered).
--     Expected: after cancelling 45, GamerX stock goes 3 -> 4



-- Q6. Write an IMMUTABLE function lab.normalize_email(text) that trims and
--     lower-cases, and use it in a UNIQUE expression index on a copy of the
--     customers table so that ' Aarav.Shah@MAIL.com ' is rejected as a duplicate.



-- Q7. Dynamic SQL: lab.null_report(p_table TEXT) RETURNS TABLE(column_name TEXT,
--     null_count BIGINT) that counts NULLs in EVERY column of a public table
--     (loop over information_schema.columns, EXECUTE format with %I).
--     Expected for 'customers': phone 7, city 1, referred_by 10, others 0
