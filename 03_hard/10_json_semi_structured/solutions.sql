-- =============================================================================
-- 03_hard/10 · JSON & Semi-Structured Data — SOLUTIONS
-- =============================================================================


-- Q1. ? 'brand' keeps only documents that have the key.
SELECT attributes ->> 'brand' AS brand, COUNT(*) AS products
FROM products
WHERE attributes ? 'brand'
GROUP BY brand
ORDER BY products DESC, brand;


-- Q2. Casts are required: ->> returns text.
SELECT product_name, 'laptop' AS kind, (attributes ->> 'ram_gb')::int AS value
FROM products
WHERE (attributes ->> 'ram_gb')::int >= 16
UNION ALL
SELECT product_name, 'book', (attributes ->> 'pages')::int
FROM products
WHERE (attributes ->> 'pages')::int > 300
ORDER BY kind, value DESC;


-- Q3a. Two containment checks…
SELECT product_name, attributes -> 'tags' AS tags
FROM products
WHERE attributes @> '{"tags": ["portable"]}'
   OR attributes @> '{"tags": ["premium"]}';
-- …or one jsonpath with a disjunction:
SELECT product_name
FROM products
WHERE attributes @? '$.tags[*] ? (@ == "portable" || @ == "premium")';

-- Q3b.
SELECT COUNT(DISTINCT tag) AS distinct_tags
FROM products
CROSS JOIN LATERAL jsonb_array_elements_text(attributes -> 'tags') AS tag;


-- Q4. Aggregate orders per customer into an array, then wrap in an object.
WITH order_totals AS (
    SELECT o.customer_id, o.order_id, o.order_date,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2) AS total
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id, o.order_id, o.order_date
)
SELECT jsonb_build_object(
           'id',     c.customer_id,
           'name',   c.first_name || ' ' || c.last_name,
           'orders', COALESCE(jsonb_agg(jsonb_build_object('id', t.order_id,
                                                           'date', t.order_date::date,
                                                           'total', t.total)
                                        ORDER BY t.order_date)
                               FILTER (WHERE t.order_id IS NOT NULL), '[]'::jsonb)
       ) AS customer_json
FROM customers c
LEFT JOIN order_totals t ON t.customer_id = c.customer_id
WHERE c.customer_id IN (1, 3)
GROUP BY c.customer_id;
-- FILTER + COALESCE give customers without orders "orders": [] instead of [null].


-- Q5. jsonb_to_recordset turns an array of objects into typed rows.
WITH payload AS (
    SELECT '[{"event":"payment","customer_id":4,"amount":143.97,"at":"2025-10-08T10:00:00Z"},
             {"event":"refund","customer_id":2,"amount":249,"at":"2025-10-09T12:30:00Z"}]'::jsonb AS doc
),
events AS (
    SELECT e.*
    FROM payload
    CROSS JOIN LATERAL jsonb_to_recordset(payload.doc)
         AS e(event TEXT, customer_id INT, amount NUMERIC, at TIMESTAMPTZ)
)
SELECT event, COUNT(*) AS events, SUM(amount) AS total
FROM events
GROUP BY event;


-- Q6. COALESCE(attributes -> 'tags', '[]') handles products without a tags array.
BEGIN;
UPDATE products
SET attributes = jsonb_set(
        attributes || '{"warranty_years": 2}',
        '{tags}',
        COALESCE(attributes -> 'tags', '[]'::jsonb) || '["extended-warranty"]'::jsonb)
WHERE attributes ->> 'brand' = 'Lumen'
RETURNING product_name, attributes;
ROLLBACK;


-- Q7a. jsonb_each gives (key, value); jsonb_typeof the value's JSON type.
SELECT key,
       COUNT(*)                                          AS products,
       STRING_AGG(DISTINCT jsonb_typeof(value), ', ')    AS json_types
FROM products
CROSS JOIN LATERAL jsonb_each(attributes)
GROUP BY key
ORDER BY products DESC, key;

-- Q7b. "If the key exists, its value must be a number."
CREATE TEMP TABLE products_checked AS SELECT * FROM products;
ALTER TABLE products_checked
    ADD CONSTRAINT chk_ram_numeric
    CHECK (NOT attributes ? 'ram_gb' OR jsonb_typeof(attributes -> 'ram_gb') = 'number');
-- UPDATE products_checked SET attributes = attributes || '{"ram_gb": "sixteen"}' WHERE product_id = 1;
--   ERROR: violates check constraint "chk_ram_numeric"
