# 10 · JSON & Semi-Structured Data

## What it is
Modern data often doesn't fit fixed columns: product attributes differ per category, API payloads,
event properties, user settings. Relational databases now store and query **JSON documents** natively.
PostgreSQL has two types:

| | `JSON` | `JSONB` (use this) |
|---|---|---|
| Storage | text, kept exactly as typed | parsed binary |
| Key order / whitespace / duplicate keys | preserved | normalized (last duplicate wins) |
| Read speed | re-parsed every access | fast |
| Indexable (GIN) | ❌ | ✅ |
| Operators `@>`, `?` | ❌ | ✅ |

## Navigating
| Operator | Returns | Example on `{"brand":"Lumen","ram_gb":16,"tags":["work","portable"]}` |
|---|---|---|
| `->  'key'` | JSONB | `attributes -> 'ram_gb'` → `16` (jsonb) |
| `->> 'key'` | **text** | `attributes ->> 'brand'` → `'Lumen'` |
| `-> 0` | array element (JSONB) | `attributes -> 'tags' -> 0` → `"work"` |
| `#>  '{a,b}'` / `#>> '{a,b}'` | path (JSONB / text) | `attributes #>> '{tags,1}'` → `'portable'` |
| `@>` | contains? | `attributes @> '{"brand":"Lumen"}'` |
| `?` / `?|` / `?&` | key exists / any / all | `attributes ? 'gpu'` |
| `jsonb_path_query` / `@?` / `@@` | SQL/JSON path (PG 12+) | `attributes @? '$.tags[*] ? (@ == "work")'` |

`->>` returns **text**: cast before comparing numbers — `(attributes ->> 'ram_gb')::int >= 16`
(otherwise `'8' > '16'` as text!).

## Building JSON (relational → JSON)
| Function | Builds |
|---|---|
| `jsonb_build_object('k', v, …)` | object from key/value pairs |
| `jsonb_build_array(…)` | array |
| `to_jsonb(row)` / `row_to_json(row)` | object from a whole row |
| `jsonb_agg(expr ORDER BY …)` | array from many rows (aggregate) |
| `jsonb_object_agg(k, v)` | object from many rows |
Great for APIs: return an order with its nested items in **one** query.

## Shredding JSON (JSON → relational)
| Function | Produces |
|---|---|
| `jsonb_array_elements(arr)` / `_text` | one row per element |
| `jsonb_each(obj)` / `_text` | one row per key/value |
| `jsonb_object_keys(obj)` | one row per key |
| `jsonb_to_record(obj) AS x(a int, b text)` | typed columns |
| `jsonb_to_recordset(arr) AS x(…)` | typed rows from an array of objects |

## Modifying
| Operation | Syntax |
|---|---|
| set/replace a path | `jsonb_set(doc, '{a,b}', '"new"'::jsonb, create_missing => true)` |
| merge (shallow) | `doc || '{"color":"red"}'` |
| remove a key | `doc - 'color'` |
| remove a path | `doc #- '{tags,0}'` |

## Indexing JSONB
- `CREATE INDEX … USING gin (doc)` — supports `@>`, `?`, `?|`, `?&`.
- `USING gin (doc jsonb_path_ops)` — smaller/faster, supports `@>` (and jsonpath) only.
- Expression B-tree for a hot scalar field: `CREATE INDEX ON t ((doc ->> 'customer_id'))`.

## Validation
JSON columns accept any shape unless you constrain them:
```sql
CHECK (jsonb_typeof(attributes) = 'object')
CHECK (attributes ? 'brand')                              -- required key
CHECK (jsonb_typeof(attributes -> 'tags') IS DISTINCT FROM 'string')
```
(PG 16+ adds `IS JSON` predicates; full JSON-Schema validation needs an extension.)

## When to use JSON — and when not
| Use JSONB for | Use real columns for |
|---|---|
| sparse / per-type attributes (laptop RAM vs book pages) | attributes every row has |
| raw payloads you store but rarely query (webhooks, events) | values you filter, join, or aggregate often |
| user preferences, feature flags | anything needing FKs, NOT NULL, precise types |
| evolving schemas during prototyping | money, dates (JSON has no date or decimal type!) |

**Hybrid** is common: core columns + a JSONB "extras" column (exactly like our `products.attributes`).
Promote a JSON field to a real column (or generated column) once it becomes important.

## Significance
JSON support lets one PostgreSQL database cover document-store use cases (MongoDB-style), feed APIs
directly, and ingest semi-structured data in ELT pipelines. Snowflake (`VARIANT`), BigQuery (`JSON`),
Databricks and DuckDB have equivalents — the concepts transfer.

## Common mistakes
- Comparing `->>` text values numerically without casting.
- Using `->` (jsonb) where text is expected → `"Lumen"` with quotes vs `Lumen`.
- Putting everything in JSON ("schemaless") and losing types, constraints and fast joins.
- GIN index + `->>` equality queries (GIN doesn't serve them).
- `jsonb_set` on a missing parent path silently does nothing (parents aren't created).

## Dialect notes
MySQL: `JSON` type, `->`/`->>`, `JSON_EXTRACT`, `JSON_TABLE`. SQL Server: JSON stored as `NVARCHAR` +
`JSON_VALUE`, `OPENJSON`. Snowflake: `VARIANT`, `col:key::type`, `FLATTEN`. BigQuery: `JSON_VALUE`, `UNNEST`.
