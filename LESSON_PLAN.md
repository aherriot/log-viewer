# Log Analytics & Search Dashboard — Ruby / Rails / Advanced Postgres Curriculum

A project-based curriculum for learning **Ruby**, **Ruby on Rails**, and
**advanced PostgreSQL** by building a log-aggregation and search tool (a
simplified, local Datadog). This doc is the map; we follow it phase by phase and
update it as decisions get made.

> **Learner profile:** strong HTML/CSS/JavaScript, comfortable with SQL basics
> (SELECT/JOIN/GROUP BY/indexes-as-a-concept). New to Ruby and Rails. Wants to go
> deep on **backend** and **advanced Postgres**, not frontend.
> **Teaching mode:** full explanations (slow down and teach), with constant
> contrasts to JavaScript/TypeScript. Drop to faster-with-stops if a section gets
> tedious. You drive; I advise and review for correctness *and* idiom.
> **Environment:** Ruby 4.0.5 (rbenv), Bundler 4.0.15, Homebrew 6.0.5, macOS
> (x86_64-darwin24). Rails + Postgres installed in Phase 0. No Docker → Postgres
> runs natively via Homebrew.

---

## Project vision

A **Log Analytics & Search Dashboard**: ingest high-volume log events from a mock
generator, store millions of them in Postgres, and query/filter/search them fast.
The app is deliberately backend-heavy — a thin JSON API and a bare-bones HTML page
are all the frontend we need. The *point* is to feel, with `EXPLAIN ANALYZE` in
hand, exactly what each Postgres index strategy does to read and write
performance at scale.

Why this project earns its keep as a teacher:

- **High write volume** → forces you to reckon with how indexes tax `INSERT`s and
  how to bulk-load millions of rows.
- **Diverse query patterns** → timestamps, status codes, user IDs, free-text
  messages, and semi-structured metadata each want a *different* index type.
- **Massive scale on a laptop** → seed millions of rows and watch Seq Scan vs
  Index Scan diverge in real milliseconds.

### The five index strategies we're here to master

| # | Strategy | The feature that forces it |
|---|---|---|
| 1 | **BRIN** (Block Range Index) | Time-series `created_at` on an append-only table |
| 2 | **GIN on JSONB** | A `metadata` column of varying, semi-structured keys |
| 3 | **Full-Text Search** (`tsvector` + GIN) | A searchable `message` field, no Elasticsearch |
| 4 | **Partial index** | An "errors only" dashboard over a `status` column |
| 5 | **Covering index** (`INCLUDE`) | A hot `(user_id, status)` endpoint that should never touch the heap |

### Locked architectural decisions

| Decision | Choice | Why |
|---|---|---|
| Language/framework | Ruby 4.0 + Rails (latest from `gem install rails`) | The stack you're here to learn |
| Database | PostgreSQL (Homebrew, native) | The whole point; no Docker on this box |
| API shape | JSON API (`--api`-ish) + one static HTML page | Backend focus; you already know the frontend |
| Test framework | **Minitest** (Rails default) | Learn Rails' native tooling first; RSpec is a later side-quest |
| Data generation | A **plain-Ruby** mock log generator (Phase 1) | Learn the *language* before the *framework* |
| ORM strategy | Active Record, but drop to **raw SQL** whenever it teaches more | Advanced Postgres often lives below the ORM |

The plain-Ruby generator in Phase 1 is a deliberate wedge: you learn Ruby the
language (blocks, symbols, hashes, everything-is-an-object) with zero Rails magic
in the way, *and* it becomes the tool that fills your tables for every later phase.

```
  ┌────────────────────┐   JSON      ┌─────────────────────┐   SQL     ┌──────────────┐
  │  Mock generator    │  /ingest    │   Rails API         │  AR /     │  PostgreSQL  │
  │  (plain Ruby, then │ ──────────► │  models, controllers│  raw SQL  │  logs table  │
  │  a rake task)      │             │  queries, EXPLAIN   │ ────────► │  + indexes   │
  └────────────────────┘             └─────────────────────┘           └──────────────┘
```

---

## How we work (the teaching loop)

Each phase repeats this rhythm so learning stays active:

1. **Concept intro** — the Ruby/Rails/Postgres feature and *why it exists*,
   contrasted with JavaScript/TypeScript (your home turf).
2. **Decision point** — options + tradeoffs at each interesting fork. You decide;
   I advise.
3. **Fill in the blanks** — I scaffold code/migrations with `# TODO(you): ...` and
   a precise spec; you implement the guts; I review for correctness *and* idiom.
4. **Comprehension checks** — rotating so it's never just "did it run":
   - **Predict-the-plan** — read a query, predict Seq Scan vs Index Scan (and
     roughly the cost) *before* running `EXPLAIN ANALYZE`.
   - **Spot-the-seq-scan** — I hand you a slow query; you find why the index
     isn't used and fix it.
   - **Make-it-idiomatic** — refactor un-Ruby-ish Ruby / un-Rails-ish Rails.
   - **Explain-it-back** — put an index or design choice in your own words.

You can always say "just show me" — but the default is you drive.

**The prime directive for every Postgres phase:** never assume an index works.
Always confirm with `EXPLAIN (ANALYZE, BUFFERS)` — from `.explain` on an Active
Record relation or straight in `rails dbconsole` — and read whether you actually
got an Index Scan / Index Only Scan vs a Seq Scan.

---

## SQL baseline self-check ("confirm your basics")

Before Phase 4's advanced indexing lands well, we want your fundamentals solid.
Early on we'll run a quick calibration — you answer in plain words, no pressure:

- [ ] What does a **B-tree index** physically let Postgres skip, and why does that
      make `WHERE id = 5` fast?
- [ ] Why can an index on `(a, b)` serve `WHERE a = ?` and `WHERE a = ? AND b = ?`
      but **not** `WHERE b = ?` alone? (composite index left-prefix rule)
- [ ] What's the difference between `WHERE created_at::date = '2026-07-01'` and
      `WHERE created_at >= '2026-07-01' AND created_at < '2026-07-02'`, and why does
      one of them defeat an index? (sargability)
- [ ] Roughly, what does `EXPLAIN ANALYZE` show you that `EXPLAIN` alone does not?
- [ ] What is a **Seq Scan** and when is it actually the *right* choice?
- [ ] What does an index cost you on `INSERT`/`UPDATE`? (so we know why "index
      everything" is wrong)

If any of these are fuzzy, that's not a gap — it's Phase 3.5, and we'll shore it
up right where it pays off.

---

## Phase roadmap

Each phase lists: **Ruby/Rails concepts**, the **Postgres focus**, the **decision
points** we'll discuss, what **you build**, and how we **check understanding**.
Checkboxes track progress.

### Phase 0 — Toolchain & first Ruby program
- [x] Done
- **Ruby/Rails concepts:** `gem`/`bundle`, rbenv version pinning, `irb`/`rails
  console`, running a `.rb` file, `puts`/`p`/`pp`. Install Rails; install Postgres
  via Homebrew and start the service.
- **JS/TS contrast:** gems ≈ npm packages, `Gemfile`/`Gemfile.lock` ≈
  `package.json`/lockfile, `bundle exec` ≈ `npx`, `irb` ≈ the Node REPL.
- **Decisions:** where to run Postgres (Homebrew native — chosen; Docker absent);
  Rails `--api` vs full stack (we'll go mostly-API with one HTML page).
- **You build:** `brew install postgresql@<v>` + start it, `gem install rails`,
  confirm `createdb` works, write and run a 5-line "hello Ruby" script.
- **Check:** predict-the-output on a couple of `puts` vs `p` snippets; explain
  what `bundle exec` protects you from.

### Phase 1 — Ruby the language (plain Ruby, zero Rails)
- [x] Done
- **Ruby/Rails concepts:** everything-is-an-object, **symbols vs strings**, hashes
  (incl. keyword args), **blocks / `yield` / `Proc` / lambda**, `Enumerable`
  (`map`/`select`/`reduce`/`each_with_object`), truthiness (only `nil`/`false` are
  falsy), string interpolation, `require`, defining classes/methods, `attr_reader`.
- **JS/TS contrast:** blocks vs arrow-function callbacks; symbols (no JS
  equivalent — interned identifiers); implicit return; `nil` vs
  `null`/`undefined`; duck typing vs TS structural types; `snake_case` everywhere.
- **Decisions:** how to model a log event in memory — `Hash` vs a `Struct` vs a
  full class; random-data approach (`Faker` gem vs hand-rolled).
- **You build:** `LogGenerator` — a plain-Ruby class that emits realistic random
  log events (timestamp, level, status, user_id, message, metadata hash) and can
  print N of them as JSON.
- **Check:** make-it-idiomatic on a `for`-loop you'd have written in JS →
  `Enumerable`; predict-the-output on a block/`yield` snippet.

### Phase 2 — Rails skeleton + the `logs` model & schema
- [x] Done
- **Ruby/Rails concepts:** `rails new -d postgresql`, MVC & convention-over-
  configuration, `bin/rails generate`, **migrations**, **Active Record models**,
  `schema.rb`, `rails console`, `rails dbconsole`.
- **Postgres focus:** picking real column types — `timestamptz` (never
  `timestamp`), `inet` for IP, an enum-ish `status`, and a **`jsonb` metadata**
  column from day one. Schema as the foundation everything else indexes.
- **Decisions:** `status` as a Postgres `enum` vs a plain string + check
  constraint vs a lookup table; `timestamptz` vs `timestamp` (we'll justify
  `timestamptz` hard); UUID vs bigint primary key at log scale.
- **You build:** `rails new`, the `Log` model + migration (`created_at`, `level`,
  `status`, `user_id`, `message`, `ip inet`, `metadata jsonb`), migrate it, insert
  a few rows from the console.
- **Check:** explain-it-back on what a migration *is* vs `schema.rb`; spot-the-bug
  in a migration that uses `timestamp` and a `string` where a type is wrong.

### Phase 3 — Ingestion at scale (make writes hurt, then fix them)
- [x] Done
- **Ruby/Rails concepts:** rake tasks (`lib/tasks`), the Rails runner, wrapping
  the Phase-1 generator, `create` vs `insert_all` vs raw `COPY`, transactions,
  batching, `find_each`.
- **Postgres focus:** **write performance** — why row-by-row `INSERT` via Active
  Record is slow, how `insert_all` (multi-row) and `COPY` change the game, and how
  each index you add later will tax these writes.
- **Decisions:** how to seed millions of rows without waiting all day —
  `insert_all` in batches vs `COPY FROM`; how many rows is "enough" to make scans
  visibly slow (target ~1–5M).
- **You build:** a `logs:seed[count]` rake task that streams the generator into
  the DB in batches; seed ~1M rows; time it three ways and record the numbers.
- **Check:** predict which of the three insert paths is fastest and by roughly how
  much; explain-it-back on why a transaction around a batch matters.

### Phase 3.5 — EXPLAIN ANALYZE & the SQL baseline, hands-on
- [x] Done
- **Postgres focus:** reading a query plan — Seq Scan vs Index Scan vs Index Only
  Scan, **cost vs actual time**, `rows` estimate vs actual (planner
  mis-estimates), `BUFFERS`, what "Heap Fetch" means. `.explain` in Rails and raw
  `EXPLAIN (ANALYZE, BUFFERS)` in `dbconsole`.
- **JS/TS contrast:** there's no analog — this is the "profiler" for your data
  layer; treat it like Chrome DevTools' performance panel for SQL.
- **Decisions:** when a Seq Scan is *correct* (small tables, low selectivity) —
  indexes are not free wins.
- **You build:** run a handful of `WHERE` queries against your 1M rows with no
  added indexes yet; capture baseline plans and timings. This is the "before"
  photo for every phase that follows.
- **Check:** the SQL baseline questions above, answered against *real* plans;
  spot-the-seq-scan on a non-sargable `WHERE`.

### Phase 4 — Time-series & BRIN indexes (strategy 1)
- [x] Done
- **Postgres focus:** **BRIN** (Block Range Index) vs a B-tree on `created_at`.
  Why BRIN is orders of magnitude smaller and ideal for **append-only,
  physically-ordered** time-series; the correlation requirement (BRIN degrades if
  rows aren't roughly in insert/time order); `pages_per_range` tuning.
- **Ruby/Rails concepts:** `add_index ... using: :brin` in a migration; range
  queries in Active Record (`where(created_at: start..finish)`).
- **Decisions:** B-tree vs BRIN for `created_at` — measure index size *and* query
  time for a time-range query; when B-tree still wins (need exact-row lookups,
  ordering, small ranges).
- **You build:** add both a B-tree and a BRIN index (separately), compare size via
  `\di+` / `pg_relation_size`, and `EXPLAIN ANALYZE` a "last 24h" query against
  each.
- **Check:** predict which index a `created_at BETWEEN ...` query uses; explain-it-
  back on *why* BRIN can be tiny yet fast for this shape of data.

### Phase 5 — JSONB & GIN indexes (strategy 2)
- [x] Done
- **Postgres focus:** querying `jsonb` (`->`, `->>`, `@>` containment,
  `jsonb_path_query`); **GIN** index with default `jsonb_ops` vs `jsonb_path_ops`
  (smaller, containment-only); expression B-tree index on a single hot key
  (`(metadata->>'error_code')`) as the alternative.
- **Ruby/Rails concepts:** querying jsonb through Active Record (`where("metadata
  @> ?", {browser: "Chrome"}.to_json)`), the store-accessor pattern, when to reach
  past AR into raw SQL.
- **Decisions:** GIN `jsonb_ops` vs `jsonb_path_ops` vs a targeted expression
  index — pick based on which queries you actually run (containment vs single-key
  equality vs nested paths).
- **You build:** index `metadata`, then `EXPLAIN ANALYZE` a containment query and a
  single-key query against each indexing choice; measure index size and write cost.
- **Check:** spot-the-seq-scan when a jsonb query uses `->>` in a way GIN can't
  serve; explain-it-back on containment (`@>`) semantics.

### Phase 6 — Full-Text Search (strategy 3)
- [x] Done
- **Postgres focus:** `to_tsvector` / `to_tsquery` / `plainto_tsquery` /
  `websearch_to_tsquery`, tokenization & stemming, `ts_rank`, a **generated
  `tsvector` column** + a **GIN** index on it. Why this beats `ILIKE '%...%'`
  (which can't use a normal index).
- **Ruby/Rails concepts:** `virtual`/generated columns in a migration, scopes for
  search, ordering by rank, sanitizing user input into a tsquery safely.
- **Decisions:** generated stored `tsvector` column vs an expression index vs
  indexing on the fly; `to_tsquery` vs `websearch_to_tsquery` for a user search
  bar; which language config.
- **You build:** add a generated `search_vector` column + GIN index over
  `message`, a `/search?q=` endpoint that ranks results, and compare it to a naive
  `ILIKE` scan.
- **Check:** predict-the-plan for `ILIKE '%error%'` vs the FTS query; explain-it-
  back on stemming (why "running" matches "run").

### Phase 7 — Partial indexes (strategy 4)
- [ ] Done
- **Postgres focus:** **partial index** (`CREATE INDEX ... WHERE status =
  'error'`) — index only the rows a hot query cares about, keeping it tiny and the
  writes cheap for everything else. The planner-must-prove-the-predicate rule (the
  query's `WHERE` has to imply the index's `WHERE`).
- **Ruby/Rails concepts:** `add_index ..., where: "status = 'error'"`; a
  `scope :errors` that lines up with the partial index.
- **Decisions:** partial index vs full index on `status` vs partial index on
  `created_at WHERE status='error'` (combine strategies) — sized against how rare
  errors are.
- **You build:** the partial index + an "error dashboard" query; confirm the
  planner uses it, and show a query that *doesn't* match the predicate falling
  back to a scan.
- **Check:** spot-the-seq-scan when a query's predicate doesn't imply the partial
  index's `WHERE`; explain-it-back on why partial indexes shrink write cost.

### Phase 8 — Covering indexes / `INCLUDE` (strategy 5)
- [ ] Done
- **Postgres focus:** **Index Only Scan**, covering indexes with `INCLUDE`,
  avoiding the **Heap Fetch**, and the crucial nuance: index-only scans still
  consult the **visibility map**, so `VACUUM` freshness matters (a table full of
  dead tuples still does heap fetches). B-tree only.
- **Ruby/Rails concepts:** `add_index [:user_id, :status]` with `include:
  [...]` (Rails migration support), designing an index around one hot endpoint.
- **Decisions:** composite key columns vs `INCLUDE` columns (what belongs in the
  key vs merely carried along); when the covering index isn't worth its write cost.
- **You build:** the `(user_id, status)` endpoint + a covering index; `EXPLAIN
  (ANALYZE, BUFFERS)` to see "Heap Fetches: 0"; run `VACUUM` and watch it change.
- **Check:** predict when you'll see `Heap Fetches: N > 0` even with the covering
  index; explain-it-back on key-columns vs included-columns.

### Phase 9 — Index maintenance & production ops
- [ ] Done
- **Postgres focus:** `pg_stat_user_indexes` (find never-used indexes wasting disk
  + slowing writes), `pg_stat_statements` (slowest queries), **`CREATE INDEX
  CONCURRENTLY`** and Rails' `disable_ddl_transaction!` +
  `algorithm: :concurrently` to avoid locking a big table, `VACUUM`/autovacuum,
  bloat, `REINDEX`.
- **Ruby/Rails concepts:** safe migrations on large tables, `strong_migrations`-
  style thinking, connection pooling basics (`database.yml` pool).
- **Decisions:** which of the indexes you built are actually earning their keep —
  drop the freeloaders; how you'd ship a new index to a live 100M-row table.
- **You build:** audit every index you've created against `pg_stat_user_indexes`,
  drop an unused one, and write one migration that adds an index *concurrently*.
- **Check:** explain-it-back on why `CREATE INDEX` (non-concurrent) is dangerous in
  production; spot-the-bug in a migration that adds an index inside a transaction
  concurrently.

### Phase 10+ — Optional deepening (as appetite grows)
- [ ] **Declarative range partitioning** by `created_at` (the natural next step for
  time-series at real scale; pairs beautifully with BRIN).
- [ ] **Materialized views** for the dashboard's rollups + refresh strategies.
- [ ] **Background ingestion** with Solid Queue / a job queue (decouple `/ingest`).
- [ ] Query-plan deep dive: statistics, `n_distinct`, extended statistics,
      planner hints-by-other-means.
- [ ] RSpec as a contrast to Minitest; request specs for the API.
- [ ] `pgvector` for similarity search over log messages (embeddings side-quest).

---

## Running log of decisions

We append here as we make real choices, so future sessions have the rationale.

| Date | Phase | Decision | Rationale |
|---|---|---|---|
| 2026-07-13 | — | Log Analytics & Search Dashboard; Ruby+Rails+Postgres; backend-focused | Forces all five target index types under real data volume |
| 2026-07-13 | — | Postgres native via Homebrew (not Docker) | Docker not installed on this box; native is simpler for a learning setup |
| 2026-07-13 | — | Minitest over RSpec to start | Learn Rails' default tooling first; RSpec is a Phase 10 side-quest |
| 2026-07-13 | — | Learn plain Ruby (Phase 1) before touching Rails | Separate "the language" from "the framework magic"; the generator becomes reusable |
| 2026-07-13 | 1 | Log event modeled as a plain Hash (symbol keys) | Simplest, most JS-object-literal-like; no behavior needed yet |
| 2026-07-13 | 1 | Faker gem for random field values | Realistic data (names/IPs/sentences) with minimal code; revisit hand-rolled randomness later if desired |
| 2026-07-13 | 2 | Rails app generated in place at repo root (`rails new . -d postgresql`) | Keeps Phase 1 artifacts and the Rails project in one repo; `.git` already present so Rails won't reinit it |
| 2026-07-13 | 2 | `status` column as a native Postgres enum type | DB-enforced valid values; storage-efficient; accepted the extra migration ceremony for adding values later |
| 2026-07-13 | 2 | Primary key: `bigint` (Rails default), not UUID | Single writer, no external exposure of IDs, no distributed-generation need; UUIDv7 (Postgres 18 has native `uuidv7()`) would be the right call only if ingestion becomes multi-writer or IDs go public |
| 2026-07-14 | 2 | App-wide `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz` via initializer (loaded through `ActiveSupport.on_load(:active_record_postgresqladapter)`) | Every future `t.datetime` becomes `timestamptz` automatically; can't be forgotten on a later migration the way a per-column override could be |
| 2026-07-14 | 2 | `logs` table: `level` (string), `status` (native `log_status` enum: ok/client_error/server_error), `http_status` (integer, raw HTTP code), `user_id` (bigint), `message` (text), `ip` (inet), `metadata` (jsonb), `created_at` only (no `updated_at` — logs are immutable) | Separates a small dashboard-friendly status category from the raw HTTP code; drops a dead `updated_at` column on an append-only table |
| 2026-07-14 | 3 | Two seed rake tasks: `logs:seed[count]` (`Log.create!`, one row at a time) and `logs:seed_bulk[count]` (`Log.insert_all`, batched at 1,000, `record_timestamps: false`) | Needed a slow baseline and a fast path to feel the difference firsthand |
| 2026-07-14 | 3 | Skipped the raw `COPY` comparison | `insert_all` already demonstrated the core lesson (batching beats row-by-row); `COPY` deemed not worth the extra plumbing right now |
| 2026-07-14 | 3.5 | Baseline captured with zero indexes on ~1M rows before any index work begins | Need an honest "before" photo — every later phase's index wins get measured against these numbers, not against each other |
| 2026-07-15 | 4 | `LogGenerator` reworked to advance an internal `@clock` per row (jittered step sized by `span`/`count`) instead of an independent random offset per row | Original random-per-row `timestamp` gave `created_at` ~0 correlation with physical insertion order, which silently defeats BRIN; a real log stream's timestamps naturally correlate with insert order |
| 2026-07-15 | 4 | Kept BRIN as the `created_at` index (dropped the B-tree, added only for comparison) | On the reseeded, correlated dataset, BRIN cut buffer reads from ~35,850 (full table) to ~5,268 for a ~13% selective range query and ran faster (38.8ms) than every prior plan; B-tree was only tested against the old, uncorrelated dataset so wasn't re-compared head-to-head on the same data |
| 2026-07-15 | 5 | GIN index on `metadata` with default `jsonb_ops`; skipped a `jsonb_path_ops` / expression-index size-and-plan comparison | Default `jsonb_ops` supports all the operators (`@>`, `?`, `?&`, `?|`) we might want later, not just containment; deferred the narrower comparison for time, same call as skipping `COPY` in Phase 3 |
| 2026-07-15 | 5 | Tested containment on `ip` (high cardinality) rather than `browser` (only 7 distinct values in this dataset) | `browser`'s low cardinality (~14% selectivity per value) wouldn't show GIN's real strength the way a highly selective key would — deliberate choice of query, not a data defect like the Phase 4 BRIN correlation bug |
| 2026-07-15 | 6 | `search_vector` generated column uses `to_tsvector('english', ...)` despite `message` being Lorem Ipsum, not real English | Kept for simplicity; documented the limitation (stop-word removal is a no-op on non-English tokens, though rule-based stemming still fires mechanically) rather than switching to `'simple'` |
| 2026-07-15 | 6 | Built a minimal HTML log viewer (`LogsController#index`, plain table, no JS framework) alongside the JSON API, plus time-range and `ip` filters reusing the Phase 4 BRIN and Phase 5 GIN indexes | User's stated goal is an eventual searchable/sortable/filterable log viewer; surfacing already-built indexes in the UI now, beyond what Phase 6 strictly required, avoids leaving proven-but-unused index work stranded |

---

## Resources

- **High Performance PostgreSQL for Rails** — Andrew Atkinson. The deep "why/how"
  for exactly this curriculum's Postgres topics. Primary companion book.
- Postgres docs: indexes (BRIN/GIN/partial/covering), full-text search, `EXPLAIN`.
- `use-the-index-luke.com` for index intuition (framework-agnostic).

---

## Progress notes

_(Short notes per session: what we finished, what's next, open questions.)_

- **2026-07-13:** Curriculum drafted. Environment confirmed: Ruby 4.0.5 (rbenv),
  Bundler 4.0.15, Homebrew 6.0.5; Rails and Postgres not yet installed; no Docker.
  Next: Phase 0 — install Rails + Postgres, first Ruby script, and run the SQL
  baseline self-check to calibrate before the advanced-index phases.
- **2026-07-13:** Phase 0 complete. Installed Postgres 18 via Homebrew and Rails
  8.1.3 via `gem install rails` (rbenv). Hit a stale-shell PATH issue where
  `/usr/bin/rails` shadowed the rbenv shim; resolved by re-checking `which -a
  rails` in a fresh shell. `createdb`/`psql` confirmed working. Wrote and ran
  `hello.rb` exercising `puts`/`p`/`nil`/symbols/hashes; predictions matched.
  Explained `bundle exec` (Gemfile.lock enforcement ≈ `npm ci` vs global
  installs). Next: Phase 1 — plain-Ruby `LogGenerator` (symbols, hashes, blocks,
  Enumerable), no Rails yet.
- **2026-07-13:** Phase 1 complete. Built `LogGenerator` (plain Hash events,
  Faker for random data). Bugs hit along the way, each a real teaching moment:
  (1) `Range#sample` doesn't exist — `.sample` is Array/Hash-only, not
  Enumerable; fixed with `rand(@user_pool)`. (2) `return` inside a block passed
  to `Array.new` performs a non-local return, exiting `generate_many` entirely
  after the first call — fixed by relying on the block's implicit last-expression
  return instead of an explicit `return`. Covered `%w[]` literals, `.sample`,
  instance vars (`@foo`) vs Ruby's rarely-used class vars (`@@foo`). Next: Phase 2
  — `rails new`, the `Log` model/migration, schema decisions (timestamptz, jsonb,
  status representation).
- **2026-07-14:** Phase 2 complete. `rails new . -d postgresql` in place; decided
  bigint PK, native Postgres enum for `status` (separate from raw `http_status`),
  app-wide `timestamptz` via an `ActiveSupport.on_load(:active_record_postgresqladapter)`
  initializer. Hit and fixed: initializer referencing `PostgreSQLAdapter` directly
  before it's loaded (NameError — fixed with the load hook), a stray trailing
  `)`, a `t.log_status` typo (real method is `t.enum ..., enum_type:`), a
  `t.jsonb : metadata` space-breaks-symbol-literal bug, and a missing `user_id`
  column. Verified via `\d logs` that `created_at` is genuinely `timestamp(6)
  with time zone`. No indexes added yet (deliberate — Phase 3.5 needs an honest
  Seq-Scan baseline). Confirmed in `rails console`: native enum round-trips as a
  plain string (no Rails `enum` macro needed), `inet` round-trips as `IPAddr`,
  `jsonb` round-trips as a real Hash, and single `.create!` implicitly wraps in a
  transaction. Next: Phase 3 — ingestion at scale (rake task wrapping
  `LogGenerator`, `insert_all`/`COPY` vs row-by-row `create`, seed ~1M rows).
- **2026-07-14:** Phase 3 complete. Built `logs:seed[count]` (`create!`, one row
  at a time) and `logs:seed_bulk[count]` (`insert_all`, batched at 1,000).
  Debugged along the way: `Range#sample`-style class/instance method mixups
  (`LogGenerator.generate_many` vs `LogGenerator.new.generate_many`), Hash
  dot-access typos (`log.status` vs `log[:status]`), a stray trailing `.` after
  a string causing a cascading `SyntaxError`, a missing `faker` entry in the
  Rails app's own `Gemfile` (global `gem install` doesn't satisfy `bundle`),
  and a `status_map` mapping raw HTTP codes to the `log_status` enum strings.
  Measured at 10,000 rows: `create!` took ~29.3s, `insert_all` batched took
  ~2.9s (~10x faster) — matches the theory (round-trips, per-row validation/
  callback overhead, individual commits vs batched multi-row `INSERT`).
  Refactored `seed_bulk` to generate-and-insert per batch instead of building
  the full array up front, after a large seed appeared to "hang" — it was
  actually still in the Faker-generation phase for all million hashes before
  any insert ran. Skipped `COPY` (see decisions log). Seeded the table past
  1M rows. Next: Phase 3.5 — `EXPLAIN ANALYZE` baseline (Seq Scan vs Index
  Scan, no indexes yet, capture "before" timings for common `WHERE` queries).
- **2026-07-14:** Phase 3.5 complete. Captured `EXPLAIN (ANALYZE, BUFFERS)`
  baselines on ~1M rows, zero indexes, in `dbconsole`:
  - `status = 'client_error'` (~14% selective): Seq Scan, 117ms, buffers
    ~35,850 (hit+read), estimate/actual rows matched closely.
  - `user_id = 1` (~0.1% selective): planner chose a parallel plan (`Gather`
    over `Parallel Seq Scan`, 2 workers), 56ms — about half of the
    non-parallel queries despite scanning the same table, since parallelism
    kicked in because the *output* row count was small (cheap to funnel
    back through `Gather`), not because the predicate itself was cheap.
  - `created_at > '2026-07-13'` (~23% selective, sargable range): Seq Scan,
    146ms.
  - `created_at::date = '2026-07-13'` (non-sargable, same logical rows as
    above): went parallel but still slower (194ms) than the sargable
    version, and the planner's row estimate was wildly off (5,000 estimated
    vs 143,102 actual) because wrapping the column in `::date` hides it from
    the column's statistics. Lesson: sargable = usable by an index/stats
    without transforming the column first; this predicate will stay unable
    to use a plain `created_at` index even after one exists later, unless
    rewritten as a range or backed by an expression index.
  All three real predicates scanned the same ~35,850 buffers total,
  confirming every one read the whole table — the expected state with no
  indexes. These numbers are the "before" baseline every later indexing
  phase gets compared against.
- **2026-07-15:** Phase 4 complete. Added a B-tree on `created_at` first: plan
  went `Seq Scan` → `Bitmap Index Scan` + `Bitmap Heap Scan`, but only a modest
  win (146ms → 116ms) because the ~23% selective query still touched almost
  every heap page. Then asked the sharper question before building
  BRIN: does this data actually satisfy BRIN's correlation requirement?
  Checked `pg_stats.correlation` on `created_at` — it was ~-0.003 (zero),
  because `LogGenerator` picked each row's timestamp independently at random
  from the last week, uncorrelated with insertion order. Built BRIN anyway
  (dropping the B-tree first) to see the failure mode directly: planner
  didn't even pick the BRIN index for a plain query (fell back to Seq Scan,
  same cost as no index); forcing it on via `enable_seqscan = off` showed
  `Heap Blocks: lossy=35849` (100% of the table, i.e. useless) and a slower
  183ms than plain Seq Scan — BRIN with broken correlation is worse than no
  index at all, not merely unhelpful. Fixed the root cause: reworked
  `LogGenerator` to advance an internal clock per row instead of picking
  timestamps independently, `TRUNCATE logs RESTART IDENTITY`, reseeded 1M
  rows, `VACUUM ANALYZE` to refresh stats and BRIN summaries. New
  correlation: ~0.99999905. Re-ran a ~13%-selective range query: `lossy`
  dropped to 5,266 blocks, buffers ~5,268 (vs ~35,850 full-table), 38.8ms —
  faster than every prior plan (Seq Scan, B-tree bitmap, and the broken BRIN
  run). Noted but didn't chase: this isn't a controlled B-tree-vs-BRIN
  comparison since the underlying dataset changed between the two tests, so
  the numbers show "BRIN works when correlation holds," not "BRIN beats
  B-tree" directly. The B-tree index was properly removed via `remove_index`
  inside the BRIN-adding migration itself (not raw SQL), so no
  schema_migrations/reality drift.
- **2026-07-15:** Phase 5 complete. Baselined a `metadata @> '{"browser": ...}'`
  containment query with no index: Seq Scan, 218ms, ~35,858 buffers — plus
  noticed the planner's row estimate (90,909) missed the actual (142,800) by
  ~57%, a bigger miss than any scalar-column query so far (jsonb stats are
  coarser than plain column stats). Discovered `browser` only has 7 distinct
  values in this dataset (`Faker::Internet.user_agent` draws from a small
  fixed pool), making single-value containment on it only ~14% selective —
  deliberately switched to testing `ip` (per-row unique) instead, for a
  cleaner demonstration. Added a GIN index (default `jsonb_ops`) on
  `metadata`. Re-ran the `ip` containment query: 0.23ms vs a 102.7ms
  no-index baseline (~450x), buffers dropped from ~35,858 to ~10,
  `Heap Blocks: exact=1`. Covered GIN's general use cases beyond jsonb
  (full-text `tsvector`, array containment/overlap, `pg_trgm` fuzzy text).
  Deferred the `jsonb_path_ops` / expression-index comparison (see decisions
  log).
- **2026-07-15:** Phase 6 complete. Added a generated `search_vector tsvector`
  column (`to_tsvector('english', message)`, `STORED`) + GIN index. Baselined
  `message ilike '%doloremque%'`: Seq Scan, ~219ms, ~35,858 buffers (same
  full-table shape as every prior no-index baseline). Confirmed the GIN index
  does *not* accelerate `ILIKE` at all — reran the identical `ILIKE` query
  after indexing and got the same ~220ms, since `ILIKE`'s `~~*` operator has
  no relationship to `tsvector`/GIN. Rewrote as
  `search_vector @@ to_tsquery('english', 'doloremque')`: 68ms (~3.2x faster,
  more modest than the jsonb GIN win) — traced the smaller gain to matching
  rows being scattered across ~38% of heap pages (`Heap Blocks: exact=13698`)
  despite only ~1.6% of rows matching, unlike the clustered/unique `ip` case
  in Phase 5. Noticed and corrected an assumption mid-session: the stemmer
  truncated `"doloremque"` to `"doloremqu"` in the query plan, proving
  rule-based stemming still fires on non-English/gibberish tokens even though
  dictionary-based stop-word removal doesn't. Covered `websearch_to_tsquery`
  (safe for raw user input, unlike `to_tsquery` which errors on malformed
  syntax) and `ts_rank`. Built `Log.search` (model scope) and
  `LogsController#index` responding to both HTML and JSON, using
  `websearch_to_tsquery` + `ts_rank`, verified via curl. Then built a minimal
  HTML log-viewer page (plain table, no JS framework) and added `in_time_range`
  and `with_ip` scopes to the same action, exercising the Phase 4 BRIN and
  Phase 5 GIN indexes from the UI (see decisions log). Next: Phase 7 —
  Partial indexes.
