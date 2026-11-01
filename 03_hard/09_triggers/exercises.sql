-- =============================================================================
-- 03_hard/09 · Triggers — EXERCISES
-- Uses: triggers + PL/pgSQL functions (08) + JSONB (preview of 10)
--       + views (medium/07) + constraints (easy/04) + advanced DML (medium/08)
-- Work on COPIES in schema "lab"; drop it at the end.
-- =============================================================================


-- Q1. Copy employees into lab.employees (add a PK) with two new columns
--     created_at and updated_at (TIMESTAMPTZ). Write ONE trigger function used by
--     two triggers so that INSERT sets both columns and UPDATE refreshes only
--     updated_at (and only when something actually changed).



-- Q2. Salary audit: lab.salary_history(emp_id, old_salary, new_salary,
--     changed_at, changed_by). Log a row ONLY when salary changes (use the
--     WHEN clause). Give Engineering a 5% raise, change someone's job title
--     (no salary change), and check the history.
--     Expected: 6 history rows (one per Engineering employee), none for the title change



-- Q3. Business rule: no employee may earn more than their manager. Enforce it
--     with a BEFORE INSERT OR UPDATE trigger on lab.employees. Show one
--     update that is rejected and one that passes.



-- Q4. Copy orders and order_items into lab, add orders.total_amount, fill it,
--     and keep it correct with an AFTER INSERT/UPDATE/DELETE trigger on
--     lab.order_items. Prove it by inserting, updating and deleting lines of
--     order 1 and comparing total_amount with a fresh SUM.
--     Expected: total_amount always equals the recomputed total



-- Q5. Soft delete: make DELETE on lab.customers (copy) set a deleted_at
--     timestamp instead of removing the row (BEFORE DELETE trigger returning
--     NULL). Create a view lab.active_customers that hides deleted rows.
--     Expected: after deleting customer 20, customers has 20 rows, the view 19



-- Q6. Statement-level trigger with a transition table: log into
--     lab.bulk_change_log how many employees had their salary changed by each
--     UPDATE statement, and the total payroll difference.
--     Expected: re-running the 5% Engineering raise from Q2 writes ONE log row
--               (6 employees changed, payroll delta 38,075.00 — after Q2 and Q3 ran)



-- Q7. Answer in comments: (a) why can a BEFORE row trigger that returns NULL
--     instead of NEW cause data loss without any error? (b) Give two situations
--     where a constraint is better than a trigger. Finally DROP SCHEMA lab CASCADE.
