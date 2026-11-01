-- =============================================================================
-- 01_easy/04 · Constraints — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;


-- Q1.
CREATE TABLE lab.coupons (
    coupon_code VARCHAR(20)  PRIMARY KEY,
    pct_off     NUMERIC(5,2) NOT NULL,
    valid_from  DATE         NOT NULL,
    valid_to    DATE         NOT NULL,
    max_uses    INT,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_coupons_pct      CHECK (pct_off > 0 AND pct_off <= 90),
    CONSTRAINT chk_coupons_dates    CHECK (valid_to >= valid_from),   -- multi-column -> table-level
    CONSTRAINT chk_coupons_max_uses CHECK (max_uses > 0)             -- NULL passes (optional)
);


-- Q2.
INSERT INTO lab.coupons (coupon_code, pct_off, valid_from, valid_to, max_uses)
VALUES ('WELCOME10', 10, '2025-01-01', '2025-12-31', 1000);                       -- OK

-- INSERT INTO lab.coupons (coupon_code, pct_off, valid_from, valid_to)
-- VALUES ('HUGE', 95, '2025-01-01', '2025-02-01');        -- chk_coupons_pct
-- INSERT INTO lab.coupons (coupon_code, pct_off, valid_from, valid_to)
-- VALUES ('BACKWARDS', 5, '2025-03-01', '2025-02-01');    -- chk_coupons_dates
-- INSERT INTO lab.coupons (coupon_code, pct_off, valid_from, valid_to)
-- VALUES ('WELCOME10', 5, '2025-01-01', '2025-02-01');    -- coupons_pkey (duplicate)


-- Q3.
CREATE TABLE lab.coupon_redemptions (
    redemption_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    coupon_code   VARCHAR(20) NOT NULL
                  REFERENCES lab.coupons(coupon_code) ON DELETE RESTRICT,  -- block deletes
    order_id      INT NOT NULL REFERENCES public.orders(order_id),
    redeemed_at   TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_redemption_once_per_order UNIQUE (coupon_code, order_id)
);

INSERT INTO lab.coupon_redemptions (coupon_code, order_id) VALUES ('WELCOME10', 1);

-- DELETE FROM lab.coupons WHERE coupon_code = 'WELCOME10';
--   ERROR: ... violates foreign key constraint ... on table "coupon_redemptions"


-- Q4. contype: p = primary key, f = foreign key, c = check, u = unique.
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.payments'::regclass
ORDER BY contype;


-- Q5.
BEGIN;
-- a) UPDATE orders SET status = 'lost' WHERE order_id = 1;
--      -> orders_status_check (CHECK)
-- b) INSERT INTO orders (customer_id, order_date, status) VALUES (999, now(), 'pending');
--      -> orders_customer_id_fkey (FOREIGN KEY)
-- c) UPDATE products SET stock_qty = -3 WHERE product_id = 5;
--      -> products_stock_qty_check (CHECK)
-- d) INSERT INTO customers (first_name, last_name, email, country, signup_date)
--    VALUES ('A', 'S', 'aarav.shah@mail.com', 'India', CURRENT_DATE);
--      -> customers_email_key (UNIQUE)
ROLLBACK;
-- Note: after any error inside a transaction, Postgres marks the transaction
-- "aborted" and rejects further statements until ROLLBACK. Test each one separately.


-- Q6.
BEGIN;
ALTER TABLE products ADD CONSTRAINT uq_products_name UNIQUE (product_name);  -- succeeds
-- INSERT INTO products (product_name, category_id, price, created_at)
-- VALUES ('Wireless Mouse', 4, 30, CURRENT_DATE);
--   ERROR: duplicate key value violates unique constraint "uq_products_name"
ROLLBACK;                                  -- constraint is removed again (transactional DDL)


-- Q7.
-- A CHECK constraint rejects a row only when its expression is FALSE.
-- NULL > 0 evaluates to NULL (unknown), which is not FALSE -> the row passes.
-- To require a positive value and forbid NULL, either:
--     max_uses INT NOT NULL CHECK (max_uses > 0)
-- or  CHECK (max_uses IS NOT NULL AND max_uses > 0)

DROP SCHEMA lab CASCADE;
