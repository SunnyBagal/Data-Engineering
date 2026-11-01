-- =============================================================================
-- 00_setup/seed.sql — Practice data
-- -----------------------------------------------------------------------------
-- Small enough to reason about by hand, rich enough to hit every edge case:
--   * NULLs (phones, cities, budgets, dept of CEO, unshipped orders)
--   * rows with NO matches (customers without orders, products never sold,
--     a department with no employees, a category with no products)
--   * ties (equal salaries) for RANK vs DENSE_RANK
--   * hierarchies (managers, categories, referrals)
--   * split payments, an unpaid order, cancelled/returned orders
--   * login streaks & same-day repeats for gaps-and-islands / sessionization
-- =============================================================================

-- Load parents before children so foreign keys are satisfied.

INSERT INTO departments (dept_id, dept_name, location, budget) VALUES
    (1, 'Engineering',     'Bengaluru', 1500000.00),
    (2, 'Sales',           'Mumbai',     800000.00),
    (3, 'Marketing',       'Mumbai',     400000.00),
    (4, 'Finance',         'Delhi',      300000.00),
    (5, 'Human Resources', 'Delhi',      200000.00),
    (6, 'Research',        'Pune',       NULL);        -- no budget yet, no employees

INSERT INTO employees (emp_id, first_name, last_name, email, dept_id, manager_id, job_title, salary, hire_date, is_active) VALUES
    ( 1, 'Anita',  'Sharma', 'anita.sharma@corp.com', NULL, NULL, 'CEO',                 250000, '2015-01-10', TRUE),
    ( 2, 'Rahul',  'Verma',  'rahul.verma@corp.com',  1,    1,    'VP Engineering',      180000, '2016-03-01', TRUE),
    ( 3, 'Priya',  'Nair',   'priya.nair@corp.com',   2,    1,    'VP Sales',            170000, '2016-06-15', TRUE),
    ( 4, 'David',  'Miller', 'david.miller@corp.com', 4,    1,    'CFO',                 175000, '2017-02-20', TRUE),
    ( 5, 'Sara',   'Khan',   'sara.khan@corp.com',    1,    2,    'Engineering Manager', 140000, '2018-04-11', TRUE),
    ( 6, 'Arjun',  'Mehta',  'arjun.mehta@corp.com',  1,    5,    'Senior Engineer',     120000, '2019-07-01', TRUE),
    ( 7, 'Emily',  'Chen',   'emily.chen@corp.com',   1,    5,    'Software Engineer',    95000, '2021-01-18', TRUE),
    ( 8, 'Vikram', 'Rao',    'vikram.rao@corp.com',   1,    5,    'Software Engineer',    95000, '2022-08-22', TRUE),
    ( 9, 'Neha',   'Gupta',  'neha.gupta@corp.com',   1,    6,    'Junior Engineer',      70000, '2024-02-05', TRUE),
    (10, 'Tom',    'Wilson', 'tom.wilson@corp.com',   2,    3,    'Sales Manager',       110000, '2017-09-12', TRUE),
    (11, 'Kavya',  'Iyer',   'kavya.iyer@corp.com',   2,    10,   'Account Executive',    75000, '2019-11-03', TRUE),
    (12, 'James',  'Brown',  'james.brown@corp.com',  2,    10,   'Account Executive',    72000, '2020-05-25', TRUE),
    (13, 'Pooja',  'Desai',  'pooja.desai@corp.com',  2,    10,   'Sales Associate',      55000, '2023-03-14', TRUE),
    (14, 'Mark',   'Taylor', 'mark.taylor@corp.com',  2,    10,   'Sales Associate',      52000, '2021-10-01', FALSE),
    (15, 'Riya',   'Kapoor', 'riya.kapoor@corp.com',  3,    3,    'Marketing Manager',   105000, '2018-01-08', TRUE),
    (16, 'Aman',   'Joshi',  'aman.joshi@corp.com',   3,    15,   'Content Strategist',   68000, '2022-06-30', TRUE),
    (17, 'Laura',  'Garcia', 'laura.garcia@corp.com', 4,    4,    'Accountant',           78000, '2019-03-19', TRUE),
    (18, 'Sanjay', 'Patel',  'sanjay.patel@corp.com', 4,    4,    'Financial Analyst',    82000, '2020-12-07', TRUE),
    (19, 'Meera',  'Pillai', 'meera.pillai@corp.com', 5,    1,    'HR Manager',           90000, '2018-08-27', TRUE),
    (20, 'Kevin',  'Lee',    'kevin.lee@corp.com',    NULL, 5,    'Contractor',           60000, '2025-05-01', TRUE);

INSERT INTO categories (category_id, category_name, parent_id) VALUES
    ( 1, 'Electronics',    NULL),
    ( 2, 'Computers',      1),
    ( 3, 'Laptops',        2),
    ( 4, 'Accessories',    2),
    ( 5, 'Phones',         1),
    ( 6, 'Home & Kitchen', NULL),
    ( 7, 'Appliances',     6),
    ( 8, 'Cookware',       6),
    ( 9, 'Books',          NULL),
    (10, 'Fiction',        9),
    (11, 'Non-Fiction',    9),
    (12, 'Gaming',         1);        -- no products yet

INSERT INTO products (product_id, product_name, category_id, price, cost, stock_qty, is_discontinued, attributes, created_at) VALUES
    ( 1, 'ProBook 14 Laptop',           3, 1200.00,  850.00,  15, FALSE, '{"brand":"Lumen","ram_gb":16,"color":"silver","tags":["work","portable"]}',      '2022-10-15'),
    ( 2, 'UltraBook Air 13',            3, 1500.00, 1050.00,   8, FALSE, '{"brand":"Lumen","ram_gb":16,"color":"space gray","tags":["premium","portable"]}', '2023-01-01'),
    ( 3, 'GamerX 17 Laptop',            3, 2200.00, 1650.00,   3, FALSE, '{"brand":"Titan","ram_gb":32,"gpu":"RTX","tags":["gaming"]}',                   '2023-12-01'),
    ( 4, 'Budget Laptop 15',            3,  450.00,  330.00,   0, TRUE,  '{"brand":"Valu","ram_gb":8}',                                                  '2022-03-20'),
    ( 5, 'Wireless Mouse',              4,   25.00,    8.00, 200, FALSE, '{"brand":"Clicko","wireless":true,"color":"black"}',                            '2022-01-05'),
    ( 6, 'Mechanical Keyboard',         4,   89.99,   40.00,  75, FALSE, '{"brand":"Clicko","wireless":false,"switch":"brown"}',                          '2022-07-11'),
    ( 7, 'USB-C Hub',                   4,   39.50,   12.00, 120, FALSE, '{"brand":"Portix","ports":7}',                                                  '2022-03-03'),
    ( 8, '27in 4K Monitor',             4,  399.00,  260.00,  20, FALSE, '{"brand":"Lumen","size_in":27,"resolution":"4K"}',                              '2022-09-19'),
    ( 9, 'Webcam HD',                   4,   59.00,   22.00,   0, FALSE, NULL,                                                                            '2021-11-30'),
    (10, 'Galaxy Nova Phone',           5,  799.00,  520.00,  40, FALSE, '{"brand":"Nova","storage_gb":128,"color":"blue","tags":["5g"]}',                '2022-09-01'),
    (11, 'Pixelate Pro Phone',          5,  999.00,  640.00,  25, FALSE, '{"brand":"Pixelate","storage_gb":256,"tags":["5g","premium"]}',                 '2023-04-02'),
    (12, 'Basic Phone',                 5,   99.00,   60.00,  60, FALSE, '{"brand":"Valu","storage_gb":16}',                                              '2021-06-14'),
    (13, 'Air Fryer',                   7,  129.00,   70.00,  35, FALSE, '{"brand":"Cookmate","capacity_l":5.5}',                                         '2022-02-14'),
    (14, 'Espresso Machine',            7,  349.00,  210.00,  10, FALSE, '{"brand":"Brewly","pressure_bar":15}',                                          '2022-10-05'),
    (15, 'Robot Vacuum',                7,  499.00,  300.00,   0, TRUE,  '{"brand":"Sweepo"}',                                                            '2022-05-18'),
    (16, 'Non-stick Pan Set',           8,   79.00,   30.00,  50, FALSE, '{"brand":"Cookmate","pieces":3}',                                               '2022-09-09'),
    (17, 'Chef Knife',                  8,   45.00,   15.00,  80, FALSE, '{"brand":"Edge","material":"steel"}',                                           '2022-04-22'),
    (18, 'The Silent Orbit',           10,   14.99,    4.00, 300, FALSE, '{"author":"M. Clarke","pages":320,"format":"paperback"}',                       '2021-01-10'),
    (19, 'Midnight Library Tales',     10,   19.99,    5.50, 150, FALSE, '{"author":"R. Hale","pages":410,"format":"hardcover"}',                         '2022-11-01'),
    (20, 'SQL for Humans',             11,   39.99,   12.00,  90, FALSE, '{"author":"J. Codd","pages":280,"format":"paperback","tags":["programming"]}',  '2022-05-05'),
    (21, 'Data Engineering Handbook',  11,   54.99,   18.00,  45, FALSE, '{"author":"A. Kim","pages":520,"format":"hardcover","tags":["programming","data"]}', '2023-02-12'),
    (22, 'Habits That Stick',          11,   16.50,    4.50,   0, FALSE, '{"author":"L. Moore","pages":240,"format":"paperback"}',                        '2020-08-08'),
    (23, 'Noise Cancelling Headphones', 4,  249.00,  150.00,  30, FALSE, '{"brand":"Sonora","wireless":true,"color":"black"}',                             '2024-05-20'),
    (24, 'Smart Kettle',                7,   69.00,   35.00,   0, FALSE, NULL,                                                                            '2025-01-15');

INSERT INTO customers (customer_id, first_name, last_name, email, phone, city, country, signup_date, referred_by) VALUES
    ( 1, 'Aarav',  'Shah',     'aarav.shah@mail.com',  '+91-9800000001', 'Mumbai',     'India',   '2022-01-15', NULL),
    ( 2, 'Isha',   'Kulkarni', 'isha.k@mail.com',      NULL,             'Pune',       'India',   '2022-02-03', 1),
    ( 3, 'John',   'Smith',    'john.smith@mail.com',  '+1-555-0101',    'New York',   'USA',     '2022-03-10', NULL),
    ( 4, 'Maria',  'Lopez',    'maria.lopez@mail.com', '+1-555-0102',    'Austin',     'USA',     '2022-04-22', 3),
    ( 5, 'Oliver', 'Jones',    'oliver.j@mail.com',    NULL,             'London',     'UK',      '2022-05-30', NULL),
    ( 6, 'Diya',   'Reddy',    'diya.reddy@mail.com',  '+91-9800000006', 'Hyderabad',  'India',   '2022-07-07', 1),
    ( 7, 'Lukas',  'Becker',   'lukas.b@mail.com',     '+49-1510000007', 'Berlin',     'Germany', '2022-08-19', NULL),
    ( 8, 'Chloe',  'Martin',   'chloe.m@mail.com',     NULL,             'Toronto',    'Canada',  '2022-10-02', NULL),
    ( 9, 'Rohan',  'Das',      'rohan.das@mail.com',   '+91-9800000009', 'Kolkata',    'India',   '2023-01-11', 6),
    (10, 'Emma',   'Wilson',   'emma.w@mail.com',      '+44-7700000010', 'Manchester', 'UK',      '2023-02-25', 5),
    (11, 'Kabir',  'Malhotra', 'kabir.m@mail.com',     NULL,             'Delhi',      'India',   '2023-04-14', NULL),
    (12, 'Sophia', 'Brown',    'sophia.b@mail.com',    '+1-555-0112',    'Chicago',    'USA',     '2023-06-01', 4),
    (13, 'Ananya', 'Singh',    'ananya.s@mail.com',    '+91-9800000013', 'Mumbai',     'India',   '2023-08-09', 1),
    (14, 'Noah',   'Fischer',  'noah.f@mail.com',      NULL,             'Munich',     'Germany', '2023-09-23', 7),
    (15, 'Zara',   'Ali',      'zara.ali@mail.com',    '+44-7700000015', 'London',     'UK',      '2023-11-30', NULL),
    (16, 'Liam',   'Taylor',   'liam.t@mail.com',      '+1-555-0116',    NULL,         'USA',     '2024-01-19', NULL),
    (17, 'Meera',  'Iyer',     'meera.iyer@mail.com',  NULL,             'Chennai',    'India',   '2024-03-05', 13),
    (18, 'Ethan',  'Clark',    'ethan.c@mail.com',     '+1-555-0118',    'Seattle',    'USA',     '2024-07-14', NULL),
    (19, 'Nisha',  'Bose',     'nisha.b@mail.com',     NULL,             'Kolkata',    'India',   '2025-02-02', 9),   -- never ordered
    (20, 'Lucas',  'Moreau',   'lucas.m@mail.com',     '+1-555-0120',    'Toronto',    'Canada',  '2025-06-18', NULL); -- never ordered

INSERT INTO orders (order_id, customer_id, employee_id, order_date, status, shipped_date) VALUES
    ( 1,  1, 11,   '2023-01-05 10:15', 'delivered', '2023-01-07'),
    ( 2,  3, 12,   '2023-01-18 14:30', 'delivered', '2023-01-20'),
    ( 3,  2, NULL, '2023-02-02 09:05', 'delivered', '2023-02-04'),
    ( 4,  5, 11,   '2023-02-14 19:45', 'returned',  '2023-02-16'),
    ( 5,  1, NULL, '2023-03-08 11:20', 'delivered', '2023-03-10'),
    ( 6,  4, 13,   '2023-03-22 16:00', 'delivered', '2023-03-25'),
    ( 7,  6, 11,   '2023-04-10 08:40', 'delivered', '2023-04-12'),
    ( 8,  7, 12,   '2023-05-03 13:10', 'cancelled', NULL),
    ( 9,  3, NULL, '2023-05-27 20:55', 'delivered', '2023-05-29'),
    (10,  8, 13,   '2023-06-15 10:00', 'delivered', '2023-06-18'),
    (11,  9, 11,   '2023-07-04 12:30', 'delivered', '2023-07-06'),
    (12,  1, 12,   '2023-07-21 17:15', 'delivered', '2023-07-23'),
    (13, 10, NULL, '2023-08-11 09:50', 'delivered', '2023-08-14'),
    (14,  5, 13,   '2023-09-02 15:25', 'delivered', '2023-09-05'),
    (15, 11, 11,   '2023-09-28 18:05', 'cancelled', NULL),
    (16, 12, 12,   '2023-10-19 11:45', 'delivered', '2023-10-21'),
    (17,  2, NULL, '2023-11-24 07:30', 'delivered', '2023-11-26'),
    (18, 13, 13,   '2023-11-24 21:10', 'delivered', '2023-11-27'),
    (19,  3, 11,   '2023-12-15 14:00', 'delivered', '2023-12-18'),
    (20,  6, NULL, '2023-12-29 10:35', 'returned',  '2024-01-02'),
    (21,  4, 12,   '2024-01-12 16:20', 'delivered', '2024-01-15'),
    (22, 14, 14,   '2024-02-07 13:55', 'delivered', '2024-02-09'),
    (23,  1, 11,   '2024-02-29 09:00', 'delivered', '2024-03-02'),  -- leap day
    (24, 15, NULL, '2024-03-17 19:40', 'delivered', '2024-03-19'),
    (25,  7, 12,   '2024-04-05 12:10', 'delivered', '2024-04-08'),
    (26,  9, 13,   '2024-05-20 15:35', 'delivered', '2024-05-22'),
    (27, 16, NULL, '2024-06-08 10:25', 'delivered', '2024-06-11'),
    (28,  3, 11,   '2024-07-01 08:15', 'delivered', '2024-07-03'),
    (29, 10, 12,   '2024-07-26 17:50', 'cancelled', NULL),
    (30, 17, NULL, '2024-08-30 11:05', 'delivered', '2024-09-02'),
    (31,  5, 13,   '2024-09-14 14:45', 'delivered', '2024-09-16'),
    (32, 12, 11,   '2024-10-31 20:20', 'delivered', '2024-11-03'),
    (33,  1, NULL, '2024-11-29 06:55', 'delivered', '2024-12-01'),
    (34, 18, 12,   '2024-12-20 13:30', 'delivered', '2024-12-23'),
    (35,  6, 11,   '2025-01-09 09:40', 'delivered', '2025-01-11'),
    (36, 13, NULL, '2025-02-14 18:00', 'delivered', '2025-02-16'),
    (37,  2, 13,   '2025-03-21 12:00', 'returned',  '2025-03-24'),
    (38, 11, 12,   '2025-04-30 15:15', 'delivered', '2025-05-02'),
    (39,  3, NULL, '2025-05-18 10:50', 'delivered', '2025-05-21'),
    (40, 14, 11,   '2025-06-27 16:40', 'delivered', '2025-06-30'),
    (41,  8, 12,   '2025-07-15 11:30', 'delivered', '2025-07-17'),
    (42, 15, NULL, '2025-08-22 19:05', 'delivered', '2025-08-25'),
    (43,  1, 13,   '2025-09-10 10:10', 'shipped',   '2025-09-12'),
    (44,  4, NULL, '2025-10-05 14:25', 'shipped',   '2025-10-07'),  -- cash on delivery: unpaid
    (45, 18, 11,   '2025-10-28 09:30', 'pending',   NULL),
    (46, 12, NULL, '2025-10-30 21:45', 'pending',   NULL);

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount) VALUES
    ( 1,  1, 1, 1200.00, 0),    ( 1,  5, 1,   25.00, 0),
    ( 2, 10, 1,  799.00, 0.05), ( 2, 18, 2,   14.99, 0),
    ( 3, 13, 1,  129.00, 0),    ( 3, 17, 1,   45.00, 0),
    ( 4,  8, 1,  399.00, 0),
    ( 5,  6, 1,   89.99, 0),    ( 5,  7, 2,   39.50, 0),
    ( 6,  2, 1, 1500.00, 0.10),
    ( 7, 20, 1,   39.99, 0),    ( 7, 21, 1,   54.99, 0),
    ( 8, 14, 1,  349.00, 0),
    ( 9,  5, 3,   25.00, 0),    ( 9,  7, 1,   39.50, 0),
    (10, 16, 1,   79.00, 0),    (10, 13, 1,  129.00, 0.10),
    (11, 12, 2,   99.00, 0),
    (12,  8, 2,  399.00, 0.05), (12,  6, 1,   89.99, 0),
    (13, 19, 3,   19.99, 0),    (13, 18, 1,   14.99, 0),
    (14,  1, 1, 1200.00, 0.05),
    (15, 10, 1,  799.00, 0),
    (16, 14, 1,  349.00, 0),    (16, 17, 2,   45.00, 0),
    (17,  2, 1, 1500.00, 0.20), (17,  5, 1,   25.00, 0),    (17,  6, 1, 89.99, 0.20),
    (18, 13, 1,  129.00, 0.25), (18, 16, 1,   79.00, 0.25),
    (19, 20, 2,   39.99, 0),    (19,  1, 1, 1200.00, 0),
    (20, 11, 1,  999.00, 0),
    (21,  3, 1, 2200.00, 0),    (21,  5, 1,   25.00, 0),
    (22, 10, 1,  799.00, 0),    (22,  9, 1,   59.00, 0),
    (23, 21, 1,   54.99, 0),    (23, 20, 1,   39.99, 0),    (23, 18, 1, 14.99, 0),
    (24, 14, 1,  349.00, 0.10),
    (25,  1, 1, 1150.00, 0),     -- sold below today's list price (price changed later)
    (26, 12, 1,   99.00, 0),    (26,  5, 2,   25.00, 0),
    (27, 23, 1,  249.00, 0),
    (28,  2, 1, 1500.00, 0),    (28,  8, 1,  399.00, 0),
    (29, 13, 1,  129.00, 0),
    (30, 19, 2,   19.99, 0),    (30, 17, 1,   45.00, 0),
    (31, 23, 1,  249.00, 0.10), (31,  7, 1,   39.50, 0),
    (32, 11, 1,  999.00, 0.05),
    (33,  3, 1, 2200.00, 0.15), (33,  6, 1,   89.99, 0.15), (33,  8, 2, 399.00, 0.15),
    (34, 10, 1,  799.00, 0),    (34, 23, 1,  249.00, 0),
    (35, 20, 1,   39.99, 0),
    (36, 14, 1,  349.00, 0),    (36, 13, 1,  129.00, 0),
    (37, 23, 1,  249.00, 0),
    (38,  1, 1, 1200.00, 0),    (38,  7, 1,   39.50, 0),
    (39, 21, 2,   54.99, 0),
    (40, 16, 2,   79.00, 0),    (40, 17, 1,   45.00, 0),
    (41, 11, 1,  999.00, 0),
    (42,  5, 1,   25.00, 0),    (42,  6, 1,   89.99, 0),
    (43,  2, 1, 1500.00, 0),    (43, 23, 1,  249.00, 0),
    (44, 12, 1,   99.00, 0),    (44, 18, 3,   14.99, 0),
    (45,  3, 1, 2200.00, 0),
    (46, 19, 1,   19.99, 0),    (46, 20, 1,   39.99, 0);

-- Payments. amount NULL in the list below means "pays the full order total",
-- which we compute from order_items (sum of qty * price * (1 - discount)).
-- Orders 6, 28 and 41 are paid in two parts. Cancelled (8, 15, 29), pending
-- (45, 46) and cash-on-delivery order 44 have no payment.
INSERT INTO payments (payment_id, order_id, amount, method, paid_at)
SELECT p.payment_id,
       p.order_id,
       COALESCE(p.amount,
                (SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2)
                 FROM order_items oi WHERE oi.order_id = p.order_id)),
       p.method,
       o.order_date + p.delay_min * INTERVAL '1 minute'
FROM (VALUES
    ( 1,  1, NULL::NUMERIC, 'card',             3),
    ( 2,  2, NULL, 'card',             2),
    ( 3,  3, NULL, 'upi',              1),
    ( 4,  4, NULL, 'paypal',           4),
    ( 5,  5, NULL, 'upi',              2),
    ( 6,  6, 675.00, 'card',           5),
    ( 7,  6, 675.00, 'bank_transfer', 1440),
    ( 8,  7, NULL, 'upi',              1),
    ( 9,  9, NULL, 'card',             3),
    (10, 10, NULL, 'paypal',           2),
    (11, 11, NULL, 'cash',          2880),
    (12, 12, NULL, 'card',             1),
    (13, 13, NULL, 'paypal',           6),
    (14, 14, NULL, 'card',             2),
    (15, 16, NULL, 'bank_transfer',   60),
    (16, 17, NULL, 'card',             1),
    (17, 18, NULL, 'upi',              1),
    (18, 19, NULL, 'card',             2),
    (19, 20, NULL, 'paypal',           3),
    (20, 21, NULL, 'card',             2),
    (21, 22, NULL, 'card',             4),
    (22, 23, NULL, 'upi',              1),
    (23, 24, NULL, 'paypal',           2),
    (24, 25, NULL, 'card',             3),
    (25, 26, NULL, 'cash',          2880),
    (26, 27, NULL, 'card',             1),
    (27, 28, 1000.00, 'card',          2),
    (28, 28,  899.00, 'upi',          30),
    (29, 30, NULL, 'upi',              1),
    (30, 31, NULL, 'paypal',           5),
    (31, 32, NULL, 'card',             2),
    (32, 33, NULL, 'card',             3),
    (33, 34, NULL, 'card',             2),
    (34, 35, NULL, 'upi',              1),
    (35, 36, NULL, 'upi',              2),
    (36, 37, NULL, 'card',             1),
    (37, 38, NULL, 'bank_transfer',  120),
    (38, 39, NULL, 'paypal',           3),
    (39, 40, NULL, 'card',             2),
    (40, 41, 500.00, 'upi',            2),
    (41, 41, 499.00, 'upi',          600),
    (42, 42, NULL, 'upi',              1),
    (43, 43, NULL, 'card',             4)
) AS p(payment_id, order_id, amount, method, delay_min)
JOIN orders o ON o.order_id = p.order_id;

INSERT INTO logins (customer_id, login_at, device) VALUES
    -- customer 1: 7-day streak (with 2 logins on Sep 3), a 3-day streak, then a single day
    (1, '2025-09-01 08:00', 'web'),     (1, '2025-09-02 08:10', 'ios'),
    (1, '2025-09-03 07:00', 'web'),     (1, '2025-09-03 21:00', 'ios'),
    (1, '2025-09-04 07:45', 'web'),     (1, '2025-09-05 22:30', 'ios'),
    (1, '2025-09-06 09:00', 'web'),     (1, '2025-09-07 10:00', 'ios'),
    (1, '2025-09-10 08:00', 'web'),     (1, '2025-09-11 08:05', 'web'),
    (1, '2025-09-12 19:00', 'ios'),     (1, '2025-09-20 12:00', 'android'),
    -- customer 3: streaks of 2 and 3 days, then a single day
    (3, '2025-09-01 10:00', 'web'),     (3, '2025-09-02 11:00', 'web'),
    (3, '2025-09-04 09:30', 'android'), (3, '2025-09-05 09:35', 'android'),
    (3, '2025-09-06 18:00', 'web'),     (3, '2025-09-15 13:00', 'web'),
    -- customer 6: a 6-day streak crossing a month boundary
    (6, '2025-09-28 20:00', 'ios'),     (6, '2025-09-29 20:15', 'ios'),
    (6, '2025-09-30 20:05', 'ios'),     (6, '2025-10-01 21:00', 'ios'),
    (6, '2025-10-02 19:50', 'ios'),     (6, '2025-10-03 20:30', 'ios'),
    -- customer 13: many logins in one day -> sessionization (30-min inactivity rule)
    (13, '2025-09-03 10:00', 'web'),    (13, '2025-09-03 10:05', 'web'),
    (13, '2025-09-03 10:20', 'web'),    (13, '2025-09-03 11:30', 'ios'),
    (13, '2025-09-03 11:40', 'ios'),    (13, '2025-09-03 15:00', 'web'),
    (13, '2025-09-04 09:00', 'web'),
    -- a few others
    (2,  '2025-09-05 12:00', 'android'),
    (12, '2025-10-10 14:00', 'web'),    (12, '2025-10-10 14:25', 'web'),
    (12, '2025-10-11 14:00', 'web'),    (12, '2025-10-12 08:00', 'android'),
    (19, '2025-10-20 09:00', 'android');  -- logs in but has never ordered

-- We inserted explicit ids, so move each identity sequence past the max id.
-- Otherwise the next INSERT without an id would try id = 1 and fail with a
-- duplicate-key error. (A classic gotcha after bulk loads / migrations.)
SELECT setval(pg_get_serial_sequence('departments', 'dept_id'),     (SELECT MAX(dept_id)     FROM departments));
SELECT setval(pg_get_serial_sequence('employees',   'emp_id'),      (SELECT MAX(emp_id)      FROM employees));
SELECT setval(pg_get_serial_sequence('categories',  'category_id'), (SELECT MAX(category_id) FROM categories));
SELECT setval(pg_get_serial_sequence('products',    'product_id'),  (SELECT MAX(product_id)  FROM products));
SELECT setval(pg_get_serial_sequence('customers',   'customer_id'), (SELECT MAX(customer_id) FROM customers));
SELECT setval(pg_get_serial_sequence('orders',      'order_id'),    (SELECT MAX(order_id)    FROM orders));
SELECT setval(pg_get_serial_sequence('payments',    'payment_id'),  (SELECT MAX(payment_id)  FROM payments));

-- Refresh planner statistics so EXPLAIN output in later lessons is realistic.
ANALYZE;
