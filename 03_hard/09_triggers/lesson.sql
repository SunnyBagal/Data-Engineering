-- =============================================================================
-- 03_hard/09 · Triggers — LESSON
-- Triggers are attached to COPIES of our tables in schema "sandbox", so the
-- shared practice tables never get hidden behaviour.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;

-- Copies with primary keys (CTAS doesn't copy constraints).
CREATE TABLE s_products    AS SELECT * FROM public.products;
CREATE TABLE s_orders      AS SELECT * FROM public.orders;
CREATE TABLE s_order_items AS SELECT * FROM public.order_items;
ALTER TABLE s_products    ADD PRIMARY KEY (product_id);
ALTER TABLE s_orders      ADD PRIMARY KEY (order_id);
ALTER TABLE s_order_items ADD PRIMARY KEY (order_id, product_id);
ALTER TABLE s_products    ADD CONSTRAINT chk_stock CHECK (stock_qty >= 0);


-- -----------------------------------------------------------------------------
-- 1. BEFORE UPDATE row trigger: automatic updated_at
-- -----------------------------------------------------------------------------

ALTER TABLE s_products ADD COLUMN updated_at TIMESTAMPTZ;

-- A trigger function: no arguments, RETURNS trigger.
CREATE FUNCTION trg_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();         -- change the row BEFORE it's written
    RETURN NEW;                      -- returning NULL here would silently cancel the update!
END;
$$;

CREATE TRIGGER products_updated_at
BEFORE UPDATE ON s_products
FOR EACH ROW
WHEN (OLD.* IS DISTINCT FROM NEW.*)  -- skip no-op updates (cheap filter, function not called)
EXECUTE FUNCTION trg_set_updated_at();

UPDATE s_products SET price = 26 WHERE product_id = 5;
SELECT product_id, price, updated_at FROM s_products WHERE product_id = 5;   -- updated_at filled


-- -----------------------------------------------------------------------------
-- 2. AFTER row trigger: a generic audit log
-- -----------------------------------------------------------------------------

CREATE TABLE audit_log (
    audit_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name TEXT        NOT NULL,
    operation  TEXT        NOT NULL,
    changed_by TEXT        NOT NULL DEFAULT current_user,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    old_row    JSONB,
    new_row    JSONB
);

-- One function serves any table: TG_TABLE_NAME / TG_OP tell it what happened.
-- to_jsonb(OLD) stores the whole row as JSON, so schema changes don't break it.
CREATE FUNCTION trg_audit() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_log (table_name, operation, old_row, new_row)
    VALUES (TG_TABLE_NAME,
            TG_OP,
            CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END);
    RETURN NULL;                     -- AFTER trigger: return value is ignored
END;
$$;

CREATE TRIGGER products_audit
AFTER INSERT OR UPDATE OR DELETE ON s_products
FOR EACH ROW EXECUTE FUNCTION trg_audit();

UPDATE s_products SET price = price * 1.1 WHERE category_id = 8;   -- 2 rows -> 2 audit rows
DELETE FROM s_products WHERE product_id = 24;                       -- 1 audit row

-- Which fields changed? Compare old and new JSON values key by key.
SELECT a.audit_id, a.operation, a.old_row ->> 'product_name' AS product,
       k AS column_changed, a.old_row ->> k AS old_value, a.new_row ->> k AS new_value
FROM audit_log a
CROSS JOIN LATERAL jsonb_object_keys(COALESCE(a.new_row, a.old_row)) AS k
WHERE a.operation = 'UPDATE'
  AND a.old_row -> k IS DISTINCT FROM a.new_row -> k
ORDER BY a.audit_id;


-- -----------------------------------------------------------------------------
-- 3. BEFORE INSERT: defaults from another table + validation
-- -----------------------------------------------------------------------------

-- Rules a CHECK constraint can't express (they need another table):
--   * unit_price defaults to the product's CURRENT price if not given
--   * discontinued products can't be sold
CREATE FUNCTION trg_order_item_defaults() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_price NUMERIC; v_disc BOOLEAN;
BEGIN
    SELECT price, is_discontinued INTO v_price, v_disc
    FROM s_products WHERE product_id = NEW.product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'product % does not exist', NEW.product_id;
    ELSIF v_disc THEN
        RAISE EXCEPTION 'product % is discontinued', NEW.product_id;
    END IF;

    NEW.unit_price := COALESCE(NEW.unit_price, v_price);   -- fill only if missing
    NEW.discount   := COALESCE(NEW.discount, 0);
    RETURN NEW;
END;
$$;

CREATE TRIGGER order_items_defaults
BEFORE INSERT ON s_order_items
FOR EACH ROW EXECUTE FUNCTION trg_order_item_defaults();

INSERT INTO s_orders (order_id, customer_id, order_date, status) VALUES (100, 20, now(), 'pending');
INSERT INTO s_order_items (order_id, product_id, quantity) VALUES (100, 6, 1);   -- no price given
SELECT * FROM s_order_items WHERE order_id = 100;                                -- unit_price 89.99
-- INSERT INTO s_order_items (order_id, product_id, quantity) VALUES (100, 4, 1);
--   ERROR: product 4 is discontinued


-- -----------------------------------------------------------------------------
-- 4. AFTER row trigger maintaining another table: stock
-- -----------------------------------------------------------------------------

-- Selling reduces stock; the CHECK (stock_qty >= 0) on s_products makes an
-- oversell fail -> the whole INSERT is rolled back.
CREATE FUNCTION trg_reserve_stock() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE s_products SET stock_qty = stock_qty - NEW.quantity WHERE product_id = NEW.product_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE s_products SET stock_qty = stock_qty + OLD.quantity WHERE product_id = OLD.product_id;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE s_products SET stock_qty = stock_qty + OLD.quantity - NEW.quantity
        WHERE product_id = NEW.product_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER order_items_stock
AFTER INSERT OR UPDATE OF quantity OR DELETE ON s_order_items   -- UPDATE only when quantity changes
FOR EACH ROW EXECUTE FUNCTION trg_reserve_stock();

SELECT stock_qty FROM s_products WHERE product_id = 13;                          -- 35
INSERT INTO s_order_items (order_id, product_id, quantity) VALUES (100, 13, 5);
SELECT stock_qty FROM s_products WHERE product_id = 13;                          -- 30
UPDATE s_order_items SET quantity = 2 WHERE order_id = 100 AND product_id = 13;
SELECT stock_qty FROM s_products WHERE product_id = 13;                          -- 33
-- INSERT INTO s_order_items (order_id, product_id, quantity) VALUES (100, 3, 50);
--   ERROR: new row for relation "s_products" violates check constraint "chk_stock"


-- -----------------------------------------------------------------------------
-- 5. Statement-level trigger with a transition table (set-based)
-- -----------------------------------------------------------------------------

CREATE TABLE price_change_log (
    changed_at   TIMESTAMPTZ DEFAULT now(),
    rows_changed INT,
    avg_change_pct NUMERIC
);

-- Runs ONCE per UPDATE statement and sees all changed rows at once via
-- old_rows / new_rows — far cheaper than a row trigger for bulk updates.
CREATE FUNCTION trg_log_price_changes() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO price_change_log (rows_changed, avg_change_pct)
    SELECT COUNT(*), ROUND(AVG(100 * (n.price - o.price) / o.price), 2)
    FROM old_rows o
    JOIN new_rows n ON n.product_id = o.product_id
    WHERE n.price IS DISTINCT FROM o.price;
    RETURN NULL;
END;
$$;

CREATE TRIGGER products_price_log
AFTER UPDATE ON s_products
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION trg_log_price_changes();

UPDATE s_products SET price = ROUND(price * 0.95, 2) WHERE category_id = 4;   -- one statement, 6 rows
SELECT * FROM price_change_log;                                               -- one row: 6 rows, -5 %


-- -----------------------------------------------------------------------------
-- 6. INSTEAD OF trigger: make a join view writable
-- -----------------------------------------------------------------------------

CREATE VIEW v_order_lines AS
SELECT oi.order_id, p.product_name, oi.quantity, oi.unit_price
FROM s_order_items oi JOIN s_products p ON p.product_id = oi.product_id;

-- Views with joins aren't auto-updatable; INSTEAD OF defines what an UPDATE means.
CREATE FUNCTION trg_v_order_lines_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE s_order_items oi
    SET quantity = NEW.quantity
    FROM s_products p
    WHERE p.product_id = oi.product_id
      AND oi.order_id = OLD.order_id
      AND p.product_name = OLD.product_name;
    RETURN NEW;
END;
$$;

CREATE TRIGGER v_order_lines_update
INSTEAD OF UPDATE ON v_order_lines
FOR EACH ROW EXECUTE FUNCTION trg_v_order_lines_update();

UPDATE v_order_lines SET quantity = 3 WHERE order_id = 100 AND product_name = 'Air Fryer';
SELECT * FROM s_order_items WHERE order_id = 100 ORDER BY product_id;   -- quantity 3
SELECT stock_qty FROM s_products WHERE product_id = 13;                 -- 32: the stock trigger fired too (cascade)


-- -----------------------------------------------------------------------------
-- 7. Inspecting and controlling triggers
-- -----------------------------------------------------------------------------

SELECT event_object_table AS table_name, trigger_name, action_timing, event_manipulation,
       action_orientation
FROM information_schema.triggers
WHERE trigger_schema = 'sandbox'
ORDER BY table_name, trigger_name;

-- Temporarily disable (e.g. bulk backfill) — dangerous: rules are skipped!
ALTER TABLE s_products DISABLE TRIGGER products_audit;
UPDATE s_products SET stock_qty = stock_qty WHERE product_id = 1;   -- not audited
ALTER TABLE s_products ENABLE TRIGGER products_audit;

SELECT operation, COUNT(*) FROM audit_log GROUP BY operation ORDER BY operation;


RESET search_path;
DROP SCHEMA sandbox CASCADE;
