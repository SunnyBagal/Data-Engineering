-- =============================================================================
-- 03_hard/10 · JSON & Semi-Structured Data — EXERCISES
-- Uses: JSONB + LATERAL (04) + window functions (01) + GROUP BY (easy/11)
--       + advanced DML (medium/08) + constraints (easy/04)
-- =============================================================================


-- Q1. Number of products per brand (attributes ->> 'brand'), most first,
--     excluding products without a brand.
--     Expected: 12 brands; Lumen 3



-- Q2. Products with at least 16 GB RAM, and books with more than 300 pages,
--     in ONE result: product_name, kind ('laptop'/'book'), value.
--     Expected: 3 laptops + 3 books



-- Q3. All products containing the tag 'portable' OR 'premium' (use @> or a
--     jsonpath), and count distinct tags across the catalog.
--     Expected: 3 products; 7 distinct tags



-- Q4. API endpoint: one JSON document per customer for customers 1 and 3:
--     {"id":…, "name":…, "orders":[{"id":…, "date":…, "total":…}, …]}
--     with orders sorted by date and totals rounded to 2 decimals.
--     Expected: customer 1 has 6 orders in the array



-- Q5. Ingest this webhook payload (as a jsonb literal) into rows with typed
--     columns (event TEXT, customer_id INT, amount NUMERIC, at TIMESTAMPTZ):
--     [{"event":"payment","customer_id":4,"amount":143.97,"at":"2025-10-08T10:00:00Z"},
--      {"event":"refund","customer_id":2,"amount":249,"at":"2025-10-09T12:30:00Z"}]
--     Then total the amount per event type.



-- Q6. Inside a transaction: for every Lumen product, add "warranty_years": 2
--     and append the tag "extended-warranty" (create the tags array if it is
--     missing). Return product names and their new attributes. ROLLBACK.
--     Expected: 3 rows; 27in 4K Monitor gets a new tags array



-- Q7. Discover the schema: for each attribute key, how many products have it
--     and which JSON type(s) it holds. Then create a temp copy of products
--     with a CHECK that ram_gb, when present, must be a number.
--     Expected: 18 keys; brand appears in 17 products
