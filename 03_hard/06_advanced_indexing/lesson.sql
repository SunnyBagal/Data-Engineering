-- =============================================================================
-- 03_hard/06 · Advanced Indexing — LESSON
-- Uses a generated table in "sandbox" so the planner has a reason to use indexes.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;
CREATE EXTENSION IF NOT EXISTS pg_trgm;          -- trigram support (contrib, ships with Postgres)
SELECT setseed(0.9);

CREATE TABLE tickets (
    ticket_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_email  TEXT        NOT NULL,
    status      TEXT        NOT NULL,            -- open / closed
    priority    INT         NOT NULL,            -- 1..5
    created_at  TIMESTAMP   NOT NULL,
    subject     TEXT        NOT NULL,
    meta        JSONB       NOT NULL
);

-- 300k tickets: 97% closed, created in time order (important for BRIN later).
INSERT INTO tickets (user_email, status, priority, created_at, subject, meta)
SELECT 'User' || (g % 20000) || '@Mail.com',                       -- mixed-case emails
       CASE WHEN random() < 0.03 THEN 'open' ELSE 'closed' END,
       1 + (random() * 4)::int,
       TIMESTAMP '2022-01-01' + g * INTERVAL '5 minutes',          -- increasing with id
       (ARRAY['Login problem','Refund request','Payment failed','Shipping delay',
              'Account locked','Wrong item'])[1 + (random() * 5)::int] || ' #' || g,
       jsonb_build_object('channel', (ARRAY['email','chat','phone'])[1 + (random() * 2)::int],
                          'tags', CASE WHEN random() < 0.1 THEN '["vip"]'::jsonb ELSE '[]'::jsonb END)
FROM generate_series(1, 300000) g;
ANALYZE tickets;


-- -----------------------------------------------------------------------------
-- 1. Composite index: equality first, then range/sort
-- -----------------------------------------------------------------------------

CREATE INDEX idx_tickets_status_prio_created ON tickets (status, priority, created_at);

-- Uses all three columns: = status, = priority, ORDER BY created_at -> no Sort node.
EXPLAIN
SELECT ticket_id, created_at FROM tickets
WHERE status = 'open' AND priority = 1
ORDER BY created_at DESC
LIMIT 20;


-- -----------------------------------------------------------------------------
-- 2. Covering index (INCLUDE) -> Index Only Scan
-- -----------------------------------------------------------------------------

-- Query needs user_email (filter) + status, created_at (output).
CREATE INDEX idx_tickets_email_cover ON tickets (user_email) INCLUDE (status, created_at);
VACUUM tickets;                                   -- set visibility-map bits for index-only scans

EXPLAIN
SELECT status, created_at FROM tickets WHERE user_email = 'User42@Mail.com';
-- Expect: Index Only Scan using idx_tickets_email_cover (the table isn't touched).


-- -----------------------------------------------------------------------------
-- 3. Expression index: make a function-wrapped predicate indexable
-- -----------------------------------------------------------------------------

-- Users type emails in any case. LOWER(user_email) can't use the plain index.
EXPLAIN SELECT * FROM tickets WHERE LOWER(user_email) = 'user42@mail.com';      -- Seq Scan

CREATE INDEX idx_tickets_email_lower ON tickets (LOWER(user_email));
ANALYZE tickets;                                  -- gathers stats on the expression too

EXPLAIN SELECT * FROM tickets WHERE LOWER(user_email) = 'user42@mail.com';      -- Bitmap/Index Scan
-- The expression must match exactly: LOWER(TRIM(user_email)) would NOT use it.

-- Expression index on a JSONB field used in equality filters.
CREATE INDEX idx_tickets_channel ON tickets ((meta ->> 'channel'));


-- -----------------------------------------------------------------------------
-- 4. Partial index: index only the rows you actually query
-- -----------------------------------------------------------------------------

-- Agents only ever look at OPEN tickets (~3%). Index just those.
CREATE INDEX idx_tickets_open_created ON tickets (created_at) WHERE status = 'open';

EXPLAIN SELECT ticket_id, created_at FROM tickets
WHERE status = 'open' AND created_at >= '2024-06-01'
ORDER BY created_at;                              -- uses the partial index

-- The partial index is a fraction of a full one.
CREATE INDEX idx_tickets_created_full ON tickets (created_at);
SELECT indexrelid::regclass AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_index
WHERE indexrelid IN ('idx_tickets_open_created'::regclass, 'idx_tickets_created_full'::regclass);
DROP INDEX idx_tickets_created_full;

-- Partial UNIQUE index = business rule "at most one ACTIVE subscription per user".
-- (Any number of inactive rows are allowed; a plain UNIQUE constraint can't express this.)
CREATE TABLE subscriptions (
    sub_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id   INT NOT NULL,
    plan      TEXT NOT NULL,
    is_active BOOLEAN NOT NULL
);
CREATE UNIQUE INDEX uq_one_active_sub ON subscriptions (user_id) WHERE is_active;

INSERT INTO subscriptions (user_id, plan, is_active) VALUES
    (1, 'basic', FALSE), (1, 'pro', FALSE), (1, 'pro', TRUE);   -- many inactive, ONE active: OK
-- INSERT INTO subscriptions (user_id, plan, is_active) VALUES (1, 'enterprise', TRUE);
--   ERROR: duplicate key value violates unique constraint "uq_one_active_sub"

-- Case-insensitive uniqueness with a UNIQUE expression index.
CREATE TABLE app_users (user_id INT PRIMARY KEY, email TEXT NOT NULL);
CREATE UNIQUE INDEX uq_app_users_email_ci ON app_users (LOWER(email));
INSERT INTO app_users VALUES (1, 'Asha@Mail.com');
-- INSERT INTO app_users VALUES (2, 'asha@mail.com');
--   ERROR: duplicate key value violates unique constraint "uq_app_users_email_ci"


-- -----------------------------------------------------------------------------
-- 5. GIN on JSONB: "contains" queries
-- -----------------------------------------------------------------------------

CREATE INDEX idx_tickets_meta_gin ON tickets USING gin (meta jsonb_path_ops);
-- jsonb_path_ops: smaller/faster GIN variant supporting @> (containment).

EXPLAIN SELECT COUNT(*) FROM tickets WHERE meta @> '{"tags": ["vip"]}';
-- Expect: Bitmap Index Scan on idx_tickets_meta_gin


-- -----------------------------------------------------------------------------
-- 6. Trigram GIN: fast LIKE '%...%' and fuzzy search
-- -----------------------------------------------------------------------------

EXPLAIN SELECT COUNT(*) FROM tickets WHERE subject ILIKE '%refund%';     -- Seq Scan

CREATE INDEX idx_tickets_subject_trgm ON tickets USING gin (subject gin_trgm_ops);

EXPLAIN SELECT COUNT(*) FROM tickets WHERE subject ILIKE '%refund%';     -- Bitmap Index Scan on trgm
-- Note: "refund" matches ~1/6 of rows here; the bigger win is for rare terms:
EXPLAIN SELECT * FROM tickets WHERE subject ILIKE '%#123456%';

-- Fuzzy matching: similarity() is between 0 and 1; typos still match.
SELECT DISTINCT split_part(subject, ' #', 1) AS subject,
       ROUND(similarity(split_part(subject, ' #', 1), 'Payment faild')::numeric, 2) AS score
FROM tickets
WHERE ticket_id <= 50
ORDER BY score DESC
LIMIT 3;


-- -----------------------------------------------------------------------------
-- 7. BRIN: tiny index for naturally ordered, huge tables
-- -----------------------------------------------------------------------------

-- created_at increases with the physical row order, so each block range covers
-- a narrow time span: BRIN stores just min/max per range of pages.
CREATE INDEX idx_tickets_created_brin ON tickets USING brin (created_at);
CREATE INDEX idx_tickets_created_btree ON tickets (created_at);

SELECT indexrelid::regclass AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_index
WHERE indexrelid IN ('idx_tickets_created_brin'::regclass, 'idx_tickets_created_btree'::regclass);
-- BRIN: a few dozen kB.  B-tree: several MB.

DROP INDEX idx_tickets_created_btree;
EXPLAIN SELECT COUNT(*) FROM tickets
WHERE created_at >= '2023-03-01' AND created_at < '2023-03-02';    -- Bitmap Index Scan on BRIN


-- -----------------------------------------------------------------------------
-- 8. Inspecting and maintaining indexes
-- -----------------------------------------------------------------------------

-- Every index on the table with its size and how often it has been used.
-- (times_used is 0 here: EXPLAIN without ANALYZE doesn't execute anything.
--  On a real server, an index with idx_scan = 0 for weeks is a drop candidate.)
SELECT s.indexrelname                                AS index,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
       s.idx_scan                                     AS times_used
FROM pg_stat_user_indexes s
WHERE s.schemaname = 'sandbox' AND s.relname = 'tickets'
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- Rebuild an index (e.g. after heavy updates caused bloat). CONCURRENTLY
-- avoids blocking writes but can't run inside a transaction block.
REINDEX INDEX idx_tickets_channel;


-- -----------------------------------------------------------------------------
-- Clean up
-- -----------------------------------------------------------------------------
RESET search_path;
DROP SCHEMA sandbox CASCADE;
