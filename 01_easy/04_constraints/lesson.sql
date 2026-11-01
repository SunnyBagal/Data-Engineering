-- =============================================================================
-- 01_easy/04 · Constraints — LESSON
-- Statements that FAIL on purpose are commented out with the error they give.
-- Uncomment them one at a time to see the database protect your data.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS sandbox;
SET search_path TO sandbox, public;


-- -----------------------------------------------------------------------------
-- 1. A table using every common constraint
-- -----------------------------------------------------------------------------

CREATE TABLE members (
    member_id   INT GENERATED ALWAYS AS IDENTITY,
    email       VARCHAR(100) NOT NULL,          -- NOT NULL: must always be supplied
    username    VARCHAR(30)  NOT NULL,
    age         INT,
    country     CHAR(2)      NOT NULL DEFAULT 'IN',   -- DEFAULT used when value omitted
    joined_on   DATE         NOT NULL DEFAULT CURRENT_DATE,
    plan        VARCHAR(10)  NOT NULL DEFAULT 'free',

    -- Table-level constraints with explicit names (readable errors, easy to drop).
    CONSTRAINT pk_members          PRIMARY KEY (member_id),
    CONSTRAINT uq_members_email    UNIQUE (email),
    CONSTRAINT chk_members_age     CHECK (age BETWEEN 13 AND 120),
    CONSTRAINT chk_members_plan    CHECK (plan IN ('free', 'pro', 'enterprise')),
    -- A CHECK can involve an expression: usernames must be lowercase.
    CONSTRAINT chk_members_username_lower CHECK (username = lower(username))
);

-- Valid insert: omitted columns get their DEFAULTs.
INSERT INTO members (email, username, age) VALUES ('asha@mail.com', 'asha', 29);
SELECT * FROM members;

-- NOT NULL violation
-- INSERT INTO members (username) VALUES ('ravi');
--   ERROR: null value in column "email" ... violates not-null constraint

-- UNIQUE violation
-- INSERT INTO members (email, username) VALUES ('asha@mail.com', 'asha2');
--   ERROR: duplicate key value violates unique constraint "uq_members_email"

-- CHECK violation
-- INSERT INTO members (email, username, age) VALUES ('kid@mail.com', 'kid', 9);
--   ERROR: new row ... violates check constraint "chk_members_age"

-- Gotcha #1: CHECK passes when the expression is NULL (unknown is not false).
INSERT INTO members (email, username, age) VALUES ('noage@mail.com', 'noage', NULL);  -- allowed!

-- Gotcha #2: UNIQUE allows many NULLs, because NULL is never equal to NULL.
CREATE TABLE badges (code VARCHAR(10) UNIQUE);
INSERT INTO badges VALUES (NULL), (NULL), ('GOLD');      -- 2 NULLs accepted
SELECT COUNT(*) AS rows_with_null FROM badges WHERE code IS NULL;   -- 2


-- -----------------------------------------------------------------------------
-- 2. Composite keys: uniqueness across a combination of columns
-- -----------------------------------------------------------------------------

CREATE TABLE enrollments (
    member_id  INT NOT NULL,
    course     VARCHAR(30) NOT NULL,
    enrolled_on DATE NOT NULL DEFAULT CURRENT_DATE,
    -- Same member may take many courses, same course many members,
    -- but the PAIR may appear only once.
    CONSTRAINT pk_enrollments PRIMARY KEY (member_id, course),
    CONSTRAINT fk_enrollments_member FOREIGN KEY (member_id) REFERENCES members(member_id)
        ON DELETE CASCADE         -- enrollment means nothing without the member
);

INSERT INTO enrollments (member_id, course) VALUES (1, 'SQL'), (1, 'Python');
-- INSERT INTO enrollments (member_id, course) VALUES (1, 'SQL');
--   ERROR: duplicate key value violates unique constraint "pk_enrollments"
-- INSERT INTO enrollments (member_id, course) VALUES (999, 'SQL');
--   ERROR: insert or update ... violates foreign key constraint "fk_enrollments_member"


-- -----------------------------------------------------------------------------
-- 3. Referential actions: what happens to children when a parent is deleted
-- -----------------------------------------------------------------------------

CREATE TABLE teams (team_id INT PRIMARY KEY, team_name TEXT NOT NULL);

CREATE TABLE players (
    player_id INT PRIMARY KEY,
    name      TEXT NOT NULL,
    -- SET NULL: a player can exist without a team (free agent).
    team_id   INT REFERENCES teams(team_id) ON DELETE SET NULL
);

CREATE TABLE contracts (
    contract_id INT PRIMARY KEY,
    -- RESTRICT: you may NOT delete a team that still has contracts (legal history!).
    team_id     INT NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT,
    value       NUMERIC(12,2) NOT NULL CHECK (value > 0)
);

INSERT INTO teams     VALUES (1, 'Falcons'), (2, 'Sharks');
INSERT INTO players   VALUES (10, 'Ana', 1), (11, 'Ben', 2);
INSERT INTO contracts VALUES (100, 2, 50000);

DELETE FROM teams WHERE team_id = 1;            -- allowed; Ana becomes a free agent
SELECT * FROM players;                          -- Ana's team_id is now NULL

-- DELETE FROM teams WHERE team_id = 2;
--   ERROR: update or delete on table "teams" violates foreign key constraint ... on table "contracts"

-- ON DELETE CASCADE demo (from section 2): deleting the member removes enrollments.
DELETE FROM members WHERE member_id = 1;
SELECT COUNT(*) AS enrollments_left FROM enrollments;   -- 0


-- -----------------------------------------------------------------------------
-- 4. Constraints in our practice database
-- -----------------------------------------------------------------------------

-- Every constraint on public.order_items, with its definition.
-- pg_get_constraintdef() renders the constraint as SQL text.
SELECT conname AS constraint_name,
       contype AS type,               -- p=primary, f=foreign, u=unique, c=check
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.order_items'::regclass;

-- Try breaking the real data (inside a transaction, so nothing changes):
BEGIN;
-- UPDATE public.order_items SET discount = 1.5 WHERE order_id = 1;
--   ERROR: violates check constraint "order_items_discount_check"
-- DELETE FROM public.customers WHERE customer_id = 1;
--   ERROR: ... violates foreign key constraint "orders_customer_id_fkey" on table "orders"
ROLLBACK;


-- -----------------------------------------------------------------------------
-- 5. Adding / removing constraints on existing tables
-- -----------------------------------------------------------------------------

-- Adding a constraint validates all existing rows; it fails if any row breaks it.
ALTER TABLE players ADD CONSTRAINT chk_players_name_len CHECK (length(name) >= 2);

-- NOT VALID: enforce for new/updated rows only and skip the full-table scan now.
-- On a 500M-row table this avoids a long lock; VALIDATE later checks old rows.
ALTER TABLE contracts ADD CONSTRAINT chk_contracts_max CHECK (value < 10000000) NOT VALID;
ALTER TABLE contracts VALIDATE CONSTRAINT chk_contracts_max;

ALTER TABLE players DROP CONSTRAINT chk_players_name_len;
ALTER TABLE players ALTER COLUMN name DROP NOT NULL;      -- NOT NULL is removed via ALTER COLUMN


-- -----------------------------------------------------------------------------
-- 6. DEFERRABLE: check at COMMIT instead of after each statement
-- -----------------------------------------------------------------------------

CREATE TABLE seats (
    seat_no INT PRIMARY KEY,
    holder  TEXT,
    CONSTRAINT uq_seats_holder UNIQUE (holder) DEFERRABLE INITIALLY IMMEDIATE
);
INSERT INTO seats VALUES (1, 'Ana'), (2, 'Ben');

-- Swap holders. With an immediate check, the first UPDATE would create a
-- temporary duplicate ('Ben' twice) and fail. Deferring checks only the end state.
BEGIN;
SET CONSTRAINTS uq_seats_holder DEFERRED;
UPDATE seats SET holder = 'Ben' WHERE seat_no = 1;
UPDATE seats SET holder = 'Ana' WHERE seat_no = 2;
COMMIT;                                       -- checked here: unique again -> OK
SELECT * FROM seats ORDER BY seat_no;


-- -----------------------------------------------------------------------------
-- Clean up
-- -----------------------------------------------------------------------------
RESET search_path;
DROP SCHEMA sandbox CASCADE;
