-- =============================================================================
-- 03_hard/05 · Query Execution & EXPLAIN — EXERCISES
-- Uses: EXPLAIN + indexes (medium/09) + joins/subqueries (medium/01, 03)
--       + window functions (01) + transactions (medium/10)
-- Work in schema "lab"; plans vary by machine — describe NODE TYPES and
-- estimated vs actual rows rather than exact numbers.
-- =============================================================================


-- Q1. Setup: create lab.accounts (30,000 rows: account_id PK, region among
--     5 values, created_on date) and lab.txns (600,000 rows: txn_id PK,
--     account_id 1..30000, txn_time in 2025, amount -500..500, kind among
--     'card','transfer','fee'). Use setseed; ANALYZE both. No other indexes.



-- Q2. EXPLAIN ANALYZE "all transactions of account 4242". Write down the scan
--     type, estimated rows and actual rows. Add the index that fixes it and
--     compare execution times.
--     Expected: Parallel Seq Scan before, Bitmap/Index Scan after (~20 rows)



-- Q3. EXPLAIN this join and name the join algorithm used, and WHY:
--       SELECT a.region, SUM(t.amount)
--       FROM lab.txns t JOIN lab.accounts a ON a.account_id = t.account_id
--       GROUP BY a.region;
--     Then restrict to accounts 1..10 and explain why the algorithm changes.
--     Expected: Hash Join for the full join; Nested Loop for 10 accounts



-- Q4. Statistics: insert 150,000 rows with kind = 'refund' and EXPLAIN ANALYZE
--     a COUNT(*) WHERE kind = 'refund' before and after ANALYZE. Report the
--     estimated vs actual row counts each time.



-- Q5. Rewrite for performance and prove it with EXPLAIN ANALYZE:
--       SELECT a.account_id,
--              (SELECT MAX(t.txn_time) FROM lab.txns t WHERE t.account_id = a.account_id) AS last_txn
--       FROM lab.accounts a WHERE a.region = 'north';
--     Try (a) GROUP BY + LEFT JOIN and (b) a composite index that makes the
--     original fast. Which plan node disappears or changes?



-- Q6. The query below is slow. Explain why from its plan, and fix it without
--     changing its result:
--       SELECT COUNT(*) FROM lab.txns WHERE txn_time::date = '2025-06-15';
--     Expected: index on txn_time + half-open range -> Index (Only) / Bitmap scan



-- Q7. Show a sort spilling to disk (Sort Method: external merge) for
--       SELECT * FROM lab.txns ORDER BY amount;
--     by lowering work_mem, then make it in-memory by raising work_mem.
--     Finally, which index would remove the Sort node entirely for
--       SELECT * FROM lab.txns ORDER BY amount DESC LIMIT 20; ?
--     Drop schema lab at the end.
