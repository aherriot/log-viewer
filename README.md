# Log Viewer

A log analytics and search dashboard built on Ruby on Rails and PostgreSQL —
a working demonstration of how far you can get on nothing but a well-indexed
Postgres table, no search engine or analytics database required.

Query a table of 1,000,000+ synthetic log events by free-text search, time
range, log level, HTTP status, user ID, and IP address or CIDR subnet — all
sortable, all paginated, all through plain SQL against Postgres.

## What this demonstrates

**Every filter in the UI is backed by a purpose-picked index, not a generic
catch-all:**

| Filter | Index type | Why this one |
|---|---|---|
| Full-text search over log messages | GIN on a generated `tsvector` column | `websearch_to_tsquery` + `ts_rank` for relevance-ordered results; a plain `LIKE '%...%'` can't use an index at all |
| Time range | BRIN | Near-zero storage cost on an append-only, time-ordered table — a few kilobytes indexing a million rows |
| Recent-first default listing | B-tree on `created_at DESC` | BRIN can filter ranges but can't serve `ORDER BY ... LIMIT`; a B-tree alongside it answers "latest 50" without touching the rest of the table |
| IP address / CIDR subnet | GiST with `inet_ops` | Native network-containment operators (`<<=`) — a plain string index couldn't understand "is this address in this /24" |
| `metadata` JSON blob | GIN (`jsonb_ops`) | Containment queries (`@>`) into semi-structured per-request metadata without a rigid schema |
| `user_id` + `status` | Composite covering index (`INCLUDE`) | Index-only scans — the query is answered entirely from the index, zero heap fetches |
| Log level, status, HTTP status | B-tree | Cheap equality filtering and sorting on low-cardinality columns |

**The result, measured, not assumed** — every one of these choices was
validated with `EXPLAIN (ANALYZE, BUFFERS)` against the real 1M+ row table,
not guessed at:

- IP lookup: full table scan → **0.23ms** (about 450x faster)
- Covering index scan: **0.32ms** with zero heap fetches
- Default "recent logs" listing: full scan + sort → **0.14ms** via index-only backward scan
- Full-text search: beats a naive substring scan while supporting relevance ranking

**The UI treats query performance as a first-class concern, not an
afterthought.** Every keystroke-driven filter debounces before hitting the
database; format-sensitive fields (IP, user ID) wait for you to finish
rather than validating half-typed input; there's no `SELECT COUNT(*)` anywhere
in the pagination path, since counting a large filtered result set is its
own expensive query — "is there a next page" is answered by fetching one
extra row instead.

## Features

- Full-text search with relevance ranking
- Filter by time range, log level, HTTP status, user ID, IP/CIDR, and status — independently or combined
- Sort by any indexed column, ascending or descending
- Per-field and clear-all filter resets
- Real empty, error, and loading states — invalid input (a malformed IP, a
  non-numeric user ID) surfaces as a clear message, not a silent empty
  result or a stack trace
- A JSON API alongside the HTML UI, for every filter and sort combination

## Tech stack

- **Ruby on Rails 8** — server-rendered HTML with Turbo for smooth
  navigation and Stimulus for lightweight, debounced client-side behavior;
  no SPA framework
- **PostgreSQL 18** — BRIN, GIN (`jsonb_ops`), GiST (`inet_ops`), B-tree
  (plain, composite, and covering with `INCLUDE`), native enum types,
  generated/stored columns, `tsvector` full-text search
- Zero external search or analytics infrastructure — everything above runs
  on Postgres alone

## Getting started

Requires Ruby (see `.ruby-version`), Rails 8, and PostgreSQL 18+.

```bash
bin/setup
bin/rails db:create db:migrate
bin/rails server
```

Seed the `logs` table with synthetic data via the included rake tasks:

```bash
bin/rails "logs:seed_bulk[1000000]"   # batched insert_all, fast
bin/rails "logs:seed[1000]"           # row-by-row create!, for comparison
```

Then visit `http://localhost:3000`.
