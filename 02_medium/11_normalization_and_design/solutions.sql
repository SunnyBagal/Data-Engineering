-- =============================================================================
-- 02_medium/11 · Normalization & Design — SOLUTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS lab;


-- Q1.
-- a) 3NF: customer_name depends on customer_id (a non-key column) -> transitive
--    dependency. Keep customer_id only; customer_name lives in customers.
--    (total is derived from invoice lines — store it only with a sync strategy.)
-- b) 2NF: product_name depends on product_id alone, i.e. on PART of the
--    composite key. Move it to products(product_id, product_name).
-- c) 1NF: emails holds a list. Create user_emails(user_id, email UNIQUE).
-- d) 1NF (repeating group): skill_1..3 caps skills at 3 and makes "who knows SQL?"
--    a 3-column search. Create employee_skills(emp_id, skill, PRIMARY KEY(emp_id, skill)).


-- Q2.
CREATE TABLE lab.emp_flat AS
SELECT e.emp_id,
       e.first_name || ' ' || e.last_name AS name,
       d.dept_name,
       d.location                         AS dept_location,
       m.first_name || ' ' || m.last_name AS manager_name
FROM employees e
LEFT JOIN departments d ON d.dept_id = e.dept_id
LEFT JOIN employees m   ON m.emp_id  = e.manager_id;

SELECT COUNT(*) AS rows_to_update FROM lab.emp_flat WHERE dept_name = 'Engineering';   -- 6
SELECT COUNT(*) AS rows_to_update FROM departments WHERE dept_name = 'Engineering';     -- 1


-- Q3a.
CREATE TABLE lab.enrollments_flat (
    student_email TEXT, student_name TEXT,
    course_code TEXT, course_title TEXT,
    instructor_email TEXT, instructor_name TEXT,
    grade CHAR(1)
);
INSERT INTO lab.enrollments_flat VALUES
    ('ana@u.edu','Ana','DB101','Databases','kim@u.edu','Dr Kim','A'),
    ('ana@u.edu','Ana','PY201','Python','lee@u.edu','Dr Lee','B'),
    ('raj@u.edu','Raj','DB101','Databases','kim@u.edu','Dr Kim','B'),
    ('mia@u.edu','Mia','DB101','Databases','kim@u.edu','Dr Kim','A'),
    ('mia@u.edu','Mia','ST301','Statistics','lee@u.edu','Dr Lee', NULL);

-- Q3b. Functional dependencies:
--   student_email    -> student_name
--   instructor_email -> instructor_name
--   course_code      -> course_title, instructor_email   (one instructor per course)
--   (student_email, course_code) -> grade
-- Each determinant becomes a table key.

-- Q3c. Natural keys are fine here (stable codes/emails); a real system would
--      probably add surrogate ids.
CREATE TABLE lab.students (
    student_email TEXT PRIMARY KEY,
    student_name  TEXT NOT NULL
);
CREATE TABLE lab.instructors (
    instructor_email TEXT PRIMARY KEY,
    instructor_name  TEXT NOT NULL
);
CREATE TABLE lab.courses (
    course_code      TEXT PRIMARY KEY,
    course_title     TEXT NOT NULL,
    instructor_email TEXT NOT NULL REFERENCES lab.instructors
);
CREATE TABLE lab.enrollments (
    student_email TEXT NOT NULL REFERENCES lab.students,
    course_code   TEXT NOT NULL REFERENCES lab.courses,
    grade         CHAR(1) CHECK (grade IN ('A','B','C','D','F')),   -- NULL = not graded yet
    PRIMARY KEY (student_email, course_code)
);

INSERT INTO lab.students    SELECT DISTINCT student_email, student_name       FROM lab.enrollments_flat;
INSERT INTO lab.instructors SELECT DISTINCT instructor_email, instructor_name FROM lab.enrollments_flat;
INSERT INTO lab.courses     SELECT DISTINCT course_code, course_title, instructor_email FROM lab.enrollments_flat;
INSERT INTO lab.enrollments SELECT student_email, course_code, grade          FROM lab.enrollments_flat;

SELECT (SELECT COUNT(*) FROM lab.students)    AS students,      -- 3
       (SELECT COUNT(*) FROM lab.instructors) AS instructors,   -- 2
       (SELECT COUNT(*) FROM lab.courses)     AS courses,       -- 3
       (SELECT COUNT(*) FROM lab.enrollments) AS enrollments;   -- 5


-- Q4. EXCEPT compares whole rows and treats NULL = NULL (Mia's NULL grade matches).
WITH rebuilt AS (
    SELECT s.student_email, s.student_name, c.course_code, c.course_title,
           i.instructor_email, i.instructor_name, e.grade
    FROM lab.enrollments e
    JOIN lab.students s    ON s.student_email    = e.student_email
    JOIN lab.courses c     ON c.course_code      = e.course_code
    JOIN lab.instructors i ON i.instructor_email = c.instructor_email
)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM lab.enrollments_flat EXCEPT SELECT * FROM rebuilt) a) AS missing,
       (SELECT COUNT(*) FROM (SELECT * FROM rebuilt EXCEPT SELECT * FROM lab.enrollments_flat) b) AS extra;


-- Q5. UNION ALL "unpivots" the three columns into rows; WHERE drops empty slots.
CREATE TABLE lab.contacts (contact_id INT PRIMARY KEY, name TEXT, phone1 TEXT, phone2 TEXT, phone3 TEXT);
INSERT INTO lab.contacts VALUES (1,'Ana','111','222',NULL), (2,'Raj','333',NULL,NULL), (3,'Mia','444','555','666');

CREATE TABLE lab.contact_phones (
    contact_id INT NOT NULL REFERENCES lab.contacts,
    phone      TEXT NOT NULL,
    position   SMALLINT NOT NULL,
    PRIMARY KEY (contact_id, phone)
);

INSERT INTO lab.contact_phones (contact_id, phone, position)
SELECT contact_id, phone, position
FROM (SELECT contact_id, phone1 AS phone, 1 AS position FROM lab.contacts
      UNION ALL
      SELECT contact_id, phone2, 2 FROM lab.contacts
      UNION ALL
      SELECT contact_id, phone3, 3 FROM lab.contacts) x
WHERE phone IS NOT NULL;                                      -- INSERT 0 6

ALTER TABLE lab.contacts DROP COLUMN phone1, DROP COLUMN phone2, DROP COLUMN phone3;


-- Q6.
CREATE TABLE lab.dim_date AS
SELECT d::date AS date_key,
       EXTRACT(YEAR FROM d)::int    AS year,
       EXTRACT(QUARTER FROM d)::int AS quarter,
       EXTRACT(MONTH FROM d)::int   AS month
FROM generate_series(DATE '2023-01-01', DATE '2025-12-31', INTERVAL '1 day') AS d;
ALTER TABLE lab.dim_date ADD PRIMARY KEY (date_key);

CREATE TABLE lab.fact_sales AS
SELECT o.order_date::date                              AS date_key,
       oi.product_id,
       o.customer_id,
       oi.quantity,
       oi.quantity * oi.unit_price * (1 - oi.discount) AS revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.status <> 'cancelled';

SELECT d.year, c.country, ROUND(SUM(f.revenue), 2) AS revenue
FROM lab.fact_sales f
JOIN lab.dim_date d ON d.date_key    = f.date_key
JOIN customers c    ON c.customer_id = f.customer_id      -- customers acts as the dimension
GROUP BY d.year, c.country
ORDER BY d.year, revenue DESC;

SELECT ROUND(SUM(revenue), 2) AS grand_total FROM lab.fact_sales;   -- 30453.52


-- Q7.
CREATE TABLE lab.items_copy AS SELECT * FROM order_items;
CREATE TABLE lab.orders_cached AS SELECT *, NULL::NUMERIC(12,2) AS total_amount FROM orders;

UPDATE lab.orders_cached oc
SET total_amount = t.total
FROM (SELECT order_id, ROUND(SUM(quantity * unit_price * (1 - discount)), 2) AS total
      FROM lab.items_copy GROUP BY order_id) t
WHERE t.order_id = oc.order_id;

UPDATE lab.items_copy SET quantity = 3 WHERE order_id = 1 AND product_id = 5;   -- a line changes

SELECT oc.order_id,
       oc.total_amount                                             AS cached_total,   -- 1225.00
       (SELECT ROUND(SUM(quantity * unit_price * (1 - discount)), 2)
        FROM lab.items_copy WHERE order_id = 1)                    AS real_total      -- 1275.00
FROM lab.orders_cached oc
WHERE oc.order_id = 1;
-- Keeping a cached value in sync:
--   1) a trigger on order_items that recomputes orders.total_amount (03_hard/09);
--   2) recompute in the same transaction in application code / a stored procedure;
--   3) don't store it: use a view, or a materialized view refreshed on a schedule
--      if slightly stale data is acceptable (03_hard/12).

DROP SCHEMA lab CASCADE;
