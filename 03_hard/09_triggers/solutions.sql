-- =============================================================================
-- 03_hard/09 · Triggers — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;


-- Q1. TG_OP lets one function handle both events.
CREATE TABLE lab.employees AS SELECT * FROM employees;
ALTER TABLE lab.employees ADD PRIMARY KEY (emp_id),
                          ADD COLUMN created_at TIMESTAMPTZ,
                          ADD COLUMN updated_at TIMESTAMPTZ;

CREATE FUNCTION lab.trg_timestamps() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_at := now();
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER employees_ins_ts BEFORE INSERT ON lab.employees
FOR EACH ROW EXECUTE FUNCTION lab.trg_timestamps();

CREATE TRIGGER employees_upd_ts BEFORE UPDATE ON lab.employees
FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*)         -- only real changes
EXECUTE FUNCTION lab.trg_timestamps();

INSERT INTO lab.employees (emp_id, first_name, last_name, email, dept_id, manager_id, job_title, salary, hire_date, is_active)
VALUES (21, 'Zoya', 'Khan', 'zoya.khan@corp.com', 3, 15, 'Designer', 65000, CURRENT_DATE, TRUE);
SELECT emp_id, created_at IS NOT NULL AS has_created, updated_at IS NOT NULL AS has_updated
FROM lab.employees WHERE emp_id = 21;


-- Q2. WHEN keeps the function from even running when salary is unchanged.
CREATE TABLE lab.salary_history (
    emp_id     INT NOT NULL,
    old_salary NUMERIC(10,2),
    new_salary NUMERIC(10,2),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_by TEXT NOT NULL DEFAULT current_user
);

CREATE FUNCTION lab.trg_salary_history() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO lab.salary_history (emp_id, old_salary, new_salary)
    VALUES (NEW.emp_id, OLD.salary, NEW.salary);
    RETURN NULL;
END;
$$;

CREATE TRIGGER employees_salary_history
AFTER UPDATE OF salary ON lab.employees
FOR EACH ROW WHEN (OLD.salary IS DISTINCT FROM NEW.salary)
EXECUTE FUNCTION lab.trg_salary_history();

UPDATE lab.employees SET salary = ROUND(salary * 1.05, 2) WHERE dept_id = 1;   -- 6 rows
UPDATE lab.employees SET job_title = 'Staff Engineer' WHERE emp_id = 6;       -- not logged
SELECT * FROM lab.salary_history ORDER BY emp_id;                             -- 6 rows


-- Q3. Two checks: the row's own manager, and the row as a manager of others.
CREATE FUNCTION lab.trg_salary_cap() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_mgr_salary NUMERIC; v_max_report NUMERIC;
BEGIN
    SELECT salary INTO v_mgr_salary FROM lab.employees WHERE emp_id = NEW.manager_id;
    IF NEW.salary > v_mgr_salary THEN
        RAISE EXCEPTION 'salary % of emp % exceeds manager salary %',
              NEW.salary, NEW.emp_id, v_mgr_salary;
    END IF;

    SELECT MAX(salary) INTO v_max_report FROM lab.employees WHERE manager_id = NEW.emp_id;
    IF NEW.salary < v_max_report THEN
        RAISE EXCEPTION 'emp % would earn less than a direct report (%)', NEW.emp_id, v_max_report;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER employees_salary_cap
BEFORE INSERT OR UPDATE OF salary, manager_id ON lab.employees
FOR EACH ROW EXECUTE FUNCTION lab.trg_salary_cap();

UPDATE lab.employees SET salary = 100000 WHERE emp_id = 9;    -- Neha 70k -> 100k, Arjun earns 126k: OK
-- UPDATE lab.employees SET salary = 200000 WHERE emp_id = 9;
--   ERROR: salary 200000 of emp 9 exceeds manager salary 126000.00
-- Note: such cross-row rules are NOT fully safe under concurrency without
-- locking (two sessions could each pass the check) — see topic 07.


-- Q4.
CREATE TABLE lab.orders AS SELECT * FROM orders;
CREATE TABLE lab.order_items AS SELECT * FROM order_items;
ALTER TABLE lab.orders ADD PRIMARY KEY (order_id), ADD COLUMN total_amount NUMERIC(12,2);
ALTER TABLE lab.order_items ADD PRIMARY KEY (order_id, product_id);

UPDATE lab.orders o SET total_amount = t.total
FROM (SELECT order_id, ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS total
      FROM lab.order_items GROUP BY order_id) t
WHERE t.order_id = o.order_id;

-- Recompute the affected order(s) from scratch: simpler and safer than
-- adding/subtracting deltas (handles order_id changes and rounding).
CREATE FUNCTION lab.trg_order_total() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE lab.orders o
    SET total_amount = (SELECT COALESCE(ROUND(SUM(quantity * unit_price * (1 - discount)), 2), 0)
                        FROM lab.order_items WHERE order_id = o.order_id)
    WHERE o.order_id IN (
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN NEW.order_id END,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN OLD.order_id END);
    RETURN NULL;
END;
$$;

CREATE TRIGGER order_items_total
AFTER INSERT OR UPDATE OR DELETE ON lab.order_items
FOR EACH ROW EXECUTE FUNCTION lab.trg_order_total();

INSERT INTO lab.order_items VALUES (1, 7, 2, 39.50, 0);               -- +79.00
UPDATE lab.order_items SET quantity = 3 WHERE order_id = 1 AND product_id = 5;
DELETE FROM lab.order_items WHERE order_id = 1 AND product_id = 7;

SELECT o.order_id, o.total_amount,
       (SELECT ROUND(SUM(quantity * unit_price * (1 - discount)), 2)
        FROM lab.order_items WHERE order_id = 1) AS recomputed           -- both 1275.00
FROM lab.orders o WHERE o.order_id = 1;


-- Q5. BEFORE DELETE returning NULL cancels the delete for that row.
CREATE TABLE lab.customers AS SELECT * FROM customers;
ALTER TABLE lab.customers ADD PRIMARY KEY (customer_id), ADD COLUMN deleted_at TIMESTAMPTZ;

CREATE FUNCTION lab.trg_soft_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE lab.customers SET deleted_at = now() WHERE customer_id = OLD.customer_id;
    RETURN NULL;                                 -- skip the real DELETE
END;
$$;

CREATE TRIGGER customers_soft_delete
BEFORE DELETE ON lab.customers
FOR EACH ROW EXECUTE FUNCTION lab.trg_soft_delete();

CREATE VIEW lab.active_customers AS
SELECT * FROM lab.customers WHERE deleted_at IS NULL;

DELETE FROM lab.customers WHERE customer_id = 20;          -- reports DELETE 0 (row was skipped)
SELECT (SELECT COUNT(*) FROM lab.customers)        AS all_rows,      -- 20
       (SELECT COUNT(*) FROM lab.active_customers) AS active_rows;   -- 19


-- Q6. Transition tables: one execution per statement, set-based.
CREATE TABLE lab.bulk_change_log (
    logged_at       TIMESTAMPTZ DEFAULT now(),
    rows_changed    INT,
    payroll_delta   NUMERIC(12,2)
);

CREATE FUNCTION lab.trg_bulk_salary_log() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO lab.bulk_change_log (rows_changed, payroll_delta)
    SELECT COUNT(*), SUM(n.salary - o.salary)
    FROM old_rows o JOIN new_rows n ON n.emp_id = o.emp_id
    WHERE n.salary IS DISTINCT FROM o.salary;
    RETURN NULL;
END;
$$;

CREATE TRIGGER employees_bulk_log
AFTER UPDATE ON lab.employees
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION lab.trg_bulk_salary_log();

UPDATE lab.employees SET salary = ROUND(salary * 1.05, 2) WHERE dept_id = 1;
SELECT * FROM lab.bulk_change_log;               -- ONE log row: 6 employees changed


-- Q7.
-- (a) In a BEFORE row trigger, the returned row is what gets written; NULL
--     means "skip this row". A RETURN NULL copied from an AFTER trigger
--     therefore silently drops every INSERT/UPDATE: the statement reports
--     "INSERT 0 0" / "UPDATE 0" and no error is raised. (Forgetting RETURN
--     entirely is at least loud in PL/pgSQL: "control reached end of trigger
--     procedure without RETURN".)
-- (b) Prefer constraints when the rule is about the row itself or a simple
--     relationship: CHECK (price >= 0), NOT NULL, UNIQUE (email), FOREIGN KEY,
--     generated columns for derived values. They're declarative, faster, can't
--     be disabled by accident, are visible in the schema and are used by the planner.

DROP SCHEMA lab CASCADE;
