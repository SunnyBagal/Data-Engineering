# 08 · User-Defined Functions & Stored Procedures

## What they are
Code stored **inside the database** and executed there.

| | Function | Procedure (PG 11+) |
|---|---|---|
| Called with | `SELECT f(…)`, inside any expression/query | `CALL p(…)` |
| Returns | a value, a row, or a set of rows | nothing (or INOUT params) |
| Usable in SELECT / WHERE / indexes | ✅ | ❌ |
| Can `COMMIT`/`ROLLBACK` inside | ❌ | ✅ (when not called inside an outer transaction block) |

## Languages
- **`LANGUAGE sql`** — one or more SQL statements; simple, can be **inlined** by the planner (fast).
- **`LANGUAGE plpgsql`** — procedural: variables, `IF`, `LOOP`, `FOR … IN query`, exceptions, `RAISE`.
- Others via extensions: `plpython3u`, `plv8` (JS), …

```sql
CREATE OR REPLACE FUNCTION order_total(p_order_id INT)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
    SELECT ROUND(SUM(quantity * unit_price * (1 - discount)), 2)
    FROM order_items WHERE order_id = p_order_id;
$$;
```
`$$ … $$` is dollar-quoting: the body is a string without needing to escape single quotes.

## Return shapes
| Declaration | Returns | Call |
|---|---|---|
| `RETURNS numeric` | scalar | `SELECT f(1)` |
| `RETURNS customers` / `RETURNS record` + OUT params | one row | `SELECT * FROM f(1)` |
| `RETURNS SETOF customers` | many rows of a table type | `SELECT * FROM f()` |
| `RETURNS TABLE (a int, b text)` | many rows, custom columns | `SELECT * FROM f()` |
| `RETURNS void` | nothing | `SELECT f()` / `PERFORM f()` |

## Volatility — tell the planner what the function does
| Category | Promise | Example | Effect |
|---|---|---|---|
| `IMMUTABLE` | same inputs → same output **forever**, no DB access | `net_price(price, discount)` | can be used in **indexes**, pre-evaluated with constants |
| `STABLE` | same output **within one statement**, reads DB | lookups, `now()`-based | can be used in index scans' comparisons |
| `VOLATILE` (default) | may change every call / has side effects | `random()`, inserts | evaluated per row, never optimized away |
Lying (marking a DB-reading function IMMUTABLE) gives **wrong results** silently. Also consider
`STRICT` (returns NULL on any NULL input without running) and `PARALLEL SAFE`.

## PL/pgSQL essentials
```sql
DECLARE  v_total numeric;  v_row customers%ROWTYPE;
BEGIN
    SELECT … INTO v_total FROM …;            -- single row into variables (INTO STRICT: error if not exactly 1)
    IF v_total > 1000 THEN … ELSIF … ELSE … END IF;
    FOR r IN SELECT … LOOP … END LOOP;       -- iterate a query
    RAISE NOTICE 'total = %', v_total;       -- log; RAISE EXCEPTION aborts with an error
    RETURN v_total;
EXCEPTION
    WHEN division_by_zero THEN RETURN NULL;  -- catch specific errors (creates a subtransaction: not free)
END;
```

## Dynamic SQL safely
`EXECUTE format('SELECT count(*) FROM %I WHERE status = %L', tbl, status)`
- `%I` quotes an **identifier**, `%L` quotes a **literal** → no SQL injection.
- Or pass values with `EXECUTE … USING v1, v2` (parameters, best).
- Never build SQL with `'…' || user_input || '…'`.

## When to put logic in the database
**Good fits:** data-integrity rules close to the data, set-based batch operations (one round-trip instead of
thousands), reusable reporting calculations, atomic multi-step operations (place order), triggers (next topic),
functions used in indexes/views.

**Poor fits:** heavy business workflows that change often, calls to external services, logic that needs
unit-testing/CI like normal code (possible — pgTAP — but less common), CPU-heavy computation that would be
better scaled out on app servers.

## Security
- `SECURITY INVOKER` (default) runs with the caller's privileges.
- `SECURITY DEFINER` runs with the **owner's** privileges — a controlled way to expose one privileged
  operation. Always `SET search_path = …` on such functions, or an attacker can shadow tables/functions.

## Common mistakes
- Row-by-row loops (`FOR r IN … LOOP UPDATE … WHERE id = r.id`) instead of one set-based UPDATE.
- Wrong volatility labels.
- `SELECT INTO` silently taking the first of many rows (use `INTO STRICT` when exactly one is expected).
- Catching all exceptions (`WHEN OTHERS`) and hiding real errors.
- Name clashes between parameters and columns (prefix params: `p_`, variables: `v_`).
- Dynamic SQL built by string concatenation.

## Dialect notes
SQL Server: T-SQL procedures/functions (`CREATE PROCEDURE … AS BEGIN … END`, `EXEC`). MySQL: `DELIMITER`
dance + `CREATE PROCEDURE`. Oracle: PL/SQL packages. Concepts transfer; syntax doesn't.
