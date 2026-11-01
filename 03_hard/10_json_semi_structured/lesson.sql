-- =============================================================================
-- 03_hard/10 · JSON & Semi-Structured Data — LESSON
-- products.attributes is JSONB, e.g.
--   {"brand":"Lumen","ram_gb":16,"color":"silver","tags":["work","portable"]}
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Navigating: -> (jsonb) vs ->> (text)
-- -----------------------------------------------------------------------------

SELECT product_name,
       attributes                         AS whole_doc,
       attributes -> 'brand'              AS brand_jsonb,   -- "Lumen" (with quotes: JSON string)
       attributes ->> 'brand'             AS brand_text,    -- Lumen   (plain text)
       attributes -> 'tags'               AS tags_array,
       attributes -> 'tags' ->> 0         AS first_tag,     -- arrays are 0-based in JSON!
       attributes #>> '{tags,1}'          AS second_tag     -- path operator
FROM products
WHERE product_id IN (1, 2, 9);                              -- 9 has NULL attributes -> NULLs

-- Missing keys simply return NULL (no error).
SELECT product_name, attributes ->> 'gpu' AS gpu FROM products WHERE product_id IN (1, 3);


-- -----------------------------------------------------------------------------
-- 2. Filtering: equality, numbers, containment, key existence
-- -----------------------------------------------------------------------------

-- Text equality with ->>.
SELECT product_name FROM products WHERE attributes ->> 'brand' = 'Lumen';

-- Numbers: CAST the text. Without it, '8' > '16' alphabetically!
SELECT product_name, (attributes ->> 'ram_gb')::int AS ram_gb
FROM products
WHERE (attributes ->> 'ram_gb')::int >= 16;                 -- 3 laptops

-- Containment @>: "the document includes this sub-document" (GIN-indexable).
SELECT product_name FROM products WHERE attributes @> '{"wireless": true}';
SELECT product_name FROM products WHERE attributes @> '{"tags": ["premium"]}';  -- array contains

-- Key existence: ? (one), ?| (any of), ?& (all of).
SELECT product_name FROM products WHERE attributes ? 'author';            -- the 5 books
SELECT product_name FROM products WHERE attributes ?| ARRAY['gpu','switch'];

-- SQL/JSON path (PG 12+): filters INSIDE the document.
SELECT product_name
FROM products
WHERE attributes @? '$.tags[*] ? (@ == "programming")';

SELECT product_name, jsonb_path_query_first(attributes, '$.pages') AS pages
FROM products
WHERE attributes @@ '$.pages > 300';


-- -----------------------------------------------------------------------------
-- 3. Exploring an unknown schema
-- -----------------------------------------------------------------------------

-- Which keys exist, and how often? Essential when ingesting third-party JSON.
SELECT key, COUNT(*) AS products
FROM products
CROSS JOIN LATERAL jsonb_object_keys(attributes) AS key
GROUP BY key
ORDER BY products DESC, key;

-- Type of each value (string / number / boolean / array / object / null).
SELECT DISTINCT key, jsonb_typeof(value) AS json_type
FROM products, jsonb_each(attributes)
ORDER BY key;


-- -----------------------------------------------------------------------------
-- 4. Shredding JSON into rows and columns
-- -----------------------------------------------------------------------------

-- One row per tag.
SELECT p.product_name, t.tag
FROM products p
CROSS JOIN LATERAL jsonb_array_elements_text(p.attributes -> 'tags') AS t(tag);

-- Typed columns from a document: jsonb_to_record with a column definition list.
SELECT p.product_name, r.*
FROM products p
CROSS JOIN LATERAL jsonb_to_record(p.attributes) AS r(author TEXT, pages INT, format TEXT)
WHERE p.attributes ? 'author';

-- An incoming API payload: an array of objects -> a relational result set.
SELECT *
FROM jsonb_to_recordset('[
        {"sku": "A-1", "qty": 2, "price": 9.99},
        {"sku": "B-7", "qty": 1, "price": 24.50}
     ]'::jsonb) AS x(sku TEXT, qty INT, price NUMERIC);


-- -----------------------------------------------------------------------------
-- 5. Building JSON from relational data (API responses)
-- -----------------------------------------------------------------------------

-- One customer as a JSON object.
SELECT jsonb_build_object('id', customer_id,
                          'name', first_name || ' ' || last_name,
                          'contact', jsonb_build_object('email', email, 'phone', phone))
       AS customer_json
FROM customers WHERE customer_id = 1;

-- A whole order with NESTED line items in one query — no N+1 queries from the app.
SELECT jsonb_build_object(
           'order_id', o.order_id,
           'date',     o.order_date::date,
           'status',   o.status,
           'items',    jsonb_agg(jsonb_build_object(
                           'product', p.product_name,
                           'qty',     oi.quantity,
                           'price',   oi.unit_price) ORDER BY p.product_name),
           'total',    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)), 2)
       ) AS order_json
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.order_id = 33
GROUP BY o.order_id;

-- Object keyed by a column: {"card": 19673.43, "upi": ...}
SELECT jsonb_object_agg(method, total) AS totals_by_method
FROM (SELECT method, SUM(amount) AS total FROM payments GROUP BY method) t;

-- Whole rows -> JSON (handy for audit logs, exports).
SELECT to_jsonb(d) AS dept FROM departments d WHERE dept_id = 6;


-- -----------------------------------------------------------------------------
-- 6. Modifying JSONB (inside a transaction)
-- -----------------------------------------------------------------------------

BEGIN;
-- jsonb_set: replace/add a value at a path. The new value must be JSONB.
UPDATE products SET attributes = jsonb_set(attributes, '{color}', '"black"')
WHERE product_id = 1 RETURNING attributes;

-- || merges objects (shallow: top-level keys of the right side win).
UPDATE products SET attributes = attributes || '{"warranty_years": 2, "ram_gb": 32}'
WHERE product_id = 1 RETURNING attributes;

-- Remove a key / a path.
UPDATE products SET attributes = attributes - 'warranty_years'
WHERE product_id = 1 RETURNING attributes;
UPDATE products SET attributes = attributes #- '{tags,0}'           -- drop the first tag
WHERE product_id = 1 RETURNING attributes -> 'tags';

-- Append to an array.
UPDATE products SET attributes = jsonb_set(attributes, '{tags}',
                                           (attributes -> 'tags') || '["sale"]'::jsonb)
WHERE product_id = 2 RETURNING attributes -> 'tags';

-- Fill a NULL document: COALESCE first, otherwise NULL || {...} stays NULL.
UPDATE products SET attributes = COALESCE(attributes, '{}'::jsonb) || '{"brand":"Generic"}'
WHERE product_id = 9 RETURNING attributes;
ROLLBACK;


-- -----------------------------------------------------------------------------
-- 7. Indexing and validating JSONB (on a copy)
-- -----------------------------------------------------------------------------

CREATE TEMP TABLE product_docs AS SELECT product_id, attributes FROM products WHERE attributes IS NOT NULL;

-- GIN: serves @>, ?, ?|, ?& on ANY key.
CREATE INDEX ON product_docs USING gin (attributes);
-- Expression B-tree: serves = / < / > on ONE hot field.
CREATE INDEX ON product_docs ((attributes ->> 'brand'));

-- Constraints keep "schemaless" data sane.
ALTER TABLE product_docs
    ADD CONSTRAINT chk_is_object  CHECK (jsonb_typeof(attributes) = 'object'),
    ADD CONSTRAINT chk_has_brand_or_author CHECK (attributes ? 'brand' OR attributes ? 'author');

-- INSERT INTO product_docs VALUES (99, '["not", "an", "object"]');
--   ERROR: violates check constraint "chk_is_object"


-- -----------------------------------------------------------------------------
-- 8. Promoting a JSON field to a real (generated) column
-- -----------------------------------------------------------------------------

-- Once a field becomes important, make it a typed, indexable column that
-- can't drift from the document.
ALTER TABLE product_docs
    ADD COLUMN brand TEXT GENERATED ALWAYS AS (attributes ->> 'brand') STORED;
SELECT brand, COUNT(*) FROM product_docs WHERE brand IS NOT NULL GROUP BY brand ORDER BY 2 DESC LIMIT 3;
