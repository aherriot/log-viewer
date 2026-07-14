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
- [ ] Done
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
- [ ] Done
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
- [ ] Done
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
- [ ] Done
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
- [ ] Done
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
- [ ] Done
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
