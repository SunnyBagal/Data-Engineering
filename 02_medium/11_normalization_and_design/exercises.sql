-- =============================================================================
-- 02_medium/11 · Normalization & Design — EXERCISES
-- Uses: design + DDL/constraints (easy/03, 04) + INSERT…SELECT (08)
--       + set operations (04) + joins (01) + CTEs (06)
-- Work in schema "lab"; drop it at the end.
-- =============================================================================


-- Q1. Which normal form does each design violate, and how would you fix it?
--     (answer in comments)
--     a) invoices(invoice_id PK, customer_id, customer_name, total)
--     b) order_lines(order_id, product_id, qty, product_name, PRIMARY KEY(order_id, product_id))
--     c) users(user_id PK, name, emails TEXT)   -- 'a@x.com;b@y.com'
--     d) employees(emp_id PK, name, skill_1, skill_2, skill_3)



-- Q2. Create lab.emp_flat with emp_id, name, dept_name, dept_location and
--     manager_name (CTAS from employees/departments). If Engineering moves to
--     Hyderabad, how many rows of emp_flat must change? How many rows of the
--     real normalized schema?
--     Expected: 6 rows vs 1 row



-- Q3. A university tracks enrollments in this spreadsheet:
--       student_email, student_name, course_code, course_title,
--       instructor_email, instructor_name, grade
--     with rows:
--       ('ana@u.edu','Ana','DB101','Databases','kim@u.edu','Dr Kim','A')
--       ('ana@u.edu','Ana','PY201','Python','lee@u.edu','Dr Lee','B')
--       ('raj@u.edu','Raj','DB101','Databases','kim@u.edu','Dr Kim','B')
--       ('mia@u.edu','Mia','DB101','Databases','kim@u.edu','Dr Kim','A')
--       ('mia@u.edu','Mia','ST301','Statistics','lee@u.edu','Dr Lee', NULL)
--     a) Create lab.enrollments_flat and load it.
--     b) Write down the functional dependencies (comments).
--     c) Decompose into lab.students, lab.instructors, lab.courses,
--        lab.enrollments (3NF, with PKs/FKs) and load them from the flat table.
--     Expected: 3 students, 2 instructors, 3 courses, 5 enrollments



-- Q4. Prove the decomposition in Q3 is lossless: rebuild the flat rows by
--     joining the four tables and compare with EXCEPT in both directions.
--     Expected: 0 and 0



-- Q5. 1NF repair: lab.contacts(contact_id, name, phone1, phone2, phone3) has
--     rows (1,'Ana','111','222',NULL), (2,'Raj','333',NULL,NULL),
--     (3,'Mia','444','555','666'). Move the phones into
--     lab.contact_phones(contact_id, phone, position) with one INSERT … SELECT,
--     skipping NULLs.
--     Expected: 6 phone rows



-- Q6. Star schema: build lab.dim_date (2023–2025) and lab.fact_sales
--     (date_key, product_id, customer_id, quantity, revenue; non-cancelled
--     orders). Then report revenue by year and customer country (join the
--     real customers table as the customer dimension).
--     Expected: 13 rows; 2023 India 5161.05, 2024 USA 6370.05;
--               grand total 30453.52



-- Q7. Denormalization trade-off: create lab.orders_cached as a copy of orders
--     plus a total_amount column filled with UPDATE … FROM. Then change one
--     line's quantity in a COPY of order_items (lab.items_copy) and show that
--     total_amount is now stale. Write in comments 2 ways to keep it in sync.
--     Finally DROP SCHEMA lab CASCADE.
