# BLS flat-file layer: recommendations

Notes from a working session on 2026-08-19. Nothing here is from memory. Every
fact about BLS was verified by fetching `https://download.bls.gov/pub/time.series/`
that day: the directory listing for all 66 folders, and the header row of every
`.series` and lookup file in them. Every claim about the current package code
was verified by running it.

Two companion files:

* **`BLS_COVERAGE_PLAN.md`** has the full survey inventory, the tiering, and
  the per-source detail. Read that second.
* **`proposed/bls_rewrite.R`** is a staged, runnable implementation. It is not
  wired into the package. Sourcing it defines new functions alongside
  `getBLSFiles()` without masking it. Read that third, or not at all until you
  decide to go ahead.

---

## The question you asked

Rewrite from scratch in a new file, or extend `getBLSFiles()`?

**Answer: neither, quite.** Decompose into new files and make `getBLSFiles()` a
thin wrapper over them. That gets every benefit of the clean sheet and pays
none of its cost. The reasoning is below, but the short version is that the
code is more defensible than you remember and the test suite is thinner than
you'd want for a rewrite.

---

## 1. What is actually in there

`R/getBLSFiles.R` is 448 lines: 124 of roxygen, ~320 of code. Thirteen commits
since the initial one. It is exported, it is on CRAN (0.1.0 released 2025-07-09,
0.2.0 submitted), and it appears in `README.md`, `vignettes/tidyusmacro.Rmd`,
and `_pkgdown.yml`.

**Good, and worth keeping verbatim:**

* The dynamic collision detection. It finds columns that would clash on a join
  and prefixes them with the file name, so you never get `.x`/`.y`. That is not
  half-assed code; most people write the naive version and ship the suffixes.
* `relationship = "many-to-one"` on every join, so a bad key errors instead of
  silently fanning out rows.
* The final invariant check that greps for `\\.[xy]$` and stops.
* `on.exit(options(old_opts))` to restore the user's user-agent, which is a
  CRAN policy requirement most packages get wrong.
* The entire CPI relative-importance block, roughly 80 lines plus the long
  roxygen section on the off-by-one, verified against the June 2026 release
  Tables 6 and 7. This is the most valuable code in the file and the least
  worth rewriting.

**Dated:**

* `file_mappings`, a hardcoded list of one line per source. Twelve entries
  today. It does not scale to 34 live surveys, and it is the reason coverage
  stalled.
* The period parser. See section 2.
* No seams. One function does URL construction, downloading, auxiliary joins,
  date parsing, and CPI weighting. Nothing in the middle is reachable or
  testable on its own. **This is the actual problem.** It is not that the code
  is bad. It is that there is nowhere to stand while you change it.

**Coupling is negligible.** Nothing else in the package calls `getBLSFiles()`.
It calls `getCPIAspects()`, not the reverse. The only other references are
doc cross-links. So the internal blast radius of a rewrite is nearly zero. The
external one is not, because it is a released, exported function.

## 2. The bug that decides the sequencing

`getBLSFiles()` computes the month as `substr(period, 2, 3)` for every source
except ECI. BLS period codes are not all monthly. Verified mapping of what the
current code does to `cu.data.1.AllItems` (63,945 rows, fetched 2026-08-19):

| code | means | current code produces | rows |
|---|---|---|---|
| `M01`–`M12` | month | correct | 47,410 |
| `M13` | annual average | `NA`, silently | 6,110 |
| `S01` | first half average | **January** | 3,523 |
| `S02` | second half average | **February** | 3,447 |
| `S03` | annual average | **March** | 3,455 |

So 10,425 rows get a silently wrong date and 6,110 get a silent `NA`. That is
16,535 of 63,945 rows, 26%.

**I initially wrote that the half-year rows collide with real monthly rows for
the same `series_id`. I checked, and that is wrong.** BLS publishes semiannual
observations on separate series (the `CUUS....AA0` family), never mixed with
monthly rows in the same series-year. Measured collisions on the old date key:
zero, in all four files I checked.

The real failure mode is cross-series, and it is still bad. `getBLSFiles()`
returns many series in one frame, so filtering or grouping by date mixes them.
Concretely, for `cu.data.1.AllItems`:

```
Rows the current code returns for date == 1984-01-01 : 117
  genuine January observations (M01)                 :  39
  first-half averages (S01) mislabeled as January    :  78
```

Two thirds of that January slice is not January data. Anyone doing
`group_by(date) |> summarise(...)` across items is silently averaging half-year
figures into monthly ones. Since `ap` (average prices) has no `S` rows at all,
this bites CPI, chained CPI, and the other index surveys, not everything.

The fix is a shared parser returning `date`, `freq`, and `is_average`, with
annual and half-year rows dropped by default and reachable via
`include_averages = TRUE`. It is implemented and tested in the staged file.

## 3. Rewrite from scratch: pros and cons

**Pros**

* The registry-plus-derived-key design is a different shape from a hardcoded
  mapping list. Retrofitting it means gutting the middle of the function anyway.
* You get to name things right immediately. `laus` and `sae` instead of `se`
  and `su`, without carrying a deprecation apology in the code.
* Natural seams: registry, fetch, join engine, period parser as separate units,
  each independently testable. That is the thing you cannot do today.
* A new exported name means the old one keeps working while you build. No flag
  day, no half-migrated state.
* The fetch layer becomes mockable, which is the only way to get real test
  coverage on a networked function.

**Cons**

* **No regression net.** This is the one that decides it. `test-cpi-weights.R`
  has 8 tests. Seven cover `build_weight_bases()`, a helper. Exactly one touches
  `getBLSFiles()`, and it asserts that a bad source string errors before hitting
  the network. The join engine, the collision renaming, the date parsing, and
  the merge invariants have zero coverage. Rewriting 320 lines of networked code
  with that behind you is flying blind.
* It is exported and on CRAN, and it is in your own scripts.
* The CPI weights block is subtle, verified, and documented. Rewriting it buys
  nothing and risks a lot. Any honest "clean sheet" has to preserve it verbatim,
  so the sheet is not clean.
* Two functions doing the same job is worse than one dated function.
  Deprecation cycles have a way of never finishing.

## 4. What I would do instead

Decompose in place. Same files a rewrite would create, but the public entry
point never moves.

```
R/bls-registry.R    bls_registry(), blsSources(), blsFiles()
R/bls-fetch.R       URL construction, download, user agent, cache hook
R/bls-join.R        derived join keys, collision renaming, invariants
R/bls-period.R      period -> date + freq + is_average
R/getBLSFiles.R     wrapper: resolve alias, call the above, keep CPI weights
```

Every pro from section 3 survives. New files, right names, real seams, mockable
fetch, registry-driven. The cons go away because the CPI block is lifted rather
than rewritten and the exported signature is unchanged.

### The one design idea worth the trouble

Do not hand-maintain a mapping of lookup files. **Derive the join key as every
column ending in `_code` that appears in both the lookup file and `.series`.**

I tested this against every lookup file in all 65 survey directories. It
produces a valid key for **474 lookup joins** and auto-detects **30 compound
keys**, including two the current code hardcodes and 28 it does not know about.
The ones that matter:

```
wp.item     (group_code, item_code)        PPI item codes repeat across groups
pc.product  (industry_code, product_code)
la.area     (area_type_code, area_code)
oe.area     (state_code, area_code, areatype_code)
```

`wp.item` has 4,013 rows but only 2,734 unique `item_code` values. A
`{file}_code` rule would fan the data out; the existing many-to-one guard would
catch it and error, which is correct but not useful. The derived key just works.

Of the 169 lookup files with no derivable key, 132 are files that should not be
joined to `series` at all: `footnote` (54), `seasonal` (40, one special case),
`period` (27), `aspect` (11, and `cu.aspect` alone is 31 MB). The remaining ~37
are almost all headerless files in discontinued surveys. Tier 4, skip with a
warning.

**This is verified, not theoretical.** From the staged file, live:

```
> getBLS("ppi", email, file = "data.1.AllCommodities")
  join group on (group_code)
  join item on (group_code, item_code)      <- auto-detected compound key
  join seasonal on (seasonal)
1,459 x 20, 0 duplicate series_id/date pairs, 0 NA dates
```

### The name collision to resolve

`getBLSFiles("su", ...)` currently downloads the **`la`** (LAUS) files. But `su`
is a real BLS prefix: the **Chained CPI**. `se` is not a prefix at all; it maps
to `sm`. Once chained CPI exists we cannot call it `su` without breaking
released code.

Recommendation: canonical `laus` and `sae`; keep `se` and `su` as deprecated
aliases that warn; ship chained CPI as `cpi_chained`. Implemented and working.

## 5. Sequencing, and why the order matters

**Step 0. Capture fixtures before touching anything.**
`bls_capture_fixtures()` in the staged file snapshots row counts, column names
and types, date ranges, period tables, duplicate-key counts, and the first 50
rows for all 12 current sources. That is the regression net you do not have. It
costs one afternoon of downloads and it is the difference between a verifiable
refactor and a hopeful one.

**Step 1. Period fix alone, as its own commit.**
This legitimately changes row counts and dates. Snapshot again to
`fixtures/period-fixed` and eyeball that diff. It should be entirely `S` and
`M13` rows, nothing else. If anything else moved, stop.

**Step 2. Refactor onto the new files.**
Diff against `fixtures/period-fixed`. That diff should be **empty**. Any
difference is a refactor bug.

Doing steps 1 and 2 in one commit is the trap. You could not tell an intended
correction from a regression, which is exactly the situation that makes a
rewrite feel risky in the first place.

**Step 3.** Tier 1 sources. Start with `ppi`, since it is the first real
exercise of the derived compound key.

**Step 4.** `blsSources()`, `blsFiles()`, fuzzy-match errors, generated pkgdown
coverage table, vignette.

**Step 5.** Tier 2 and 3, plus the on-disk cache. BLS exposes an mtime per file
in its directory listing, so cache invalidation can be exact instead of a TTL
guess. `bls_list_files()` already returns it.

## 6. What is already verified in the staged file

Run live on 2026-08-19, not asserted:

* Period parser, all seven code families, end-of-period convention matching the
  existing ECI behavior where `Q01` maps to March.
* `getBLS("cpi_chained")`: 9,252 x 30, five lookups joined, 0 NA dates,
  0 duplicate `series_id`/`date` pairs.
* `getBLS("ppi", file = "data.1.AllCommodities")`: compound key auto-detected,
  1,459 x 20, clean.
* `getBLS("productivity")`: 60,514 x 35, all rows correctly typed quarterly.
* `blsFiles("ppi")`: all 35 data files with sizes and remote mtimes.
* Fuzzy source matching: `"ppi_indsutry"` suggests `ppi_industry`.
* Deprecation warning on `"su"` pointing at both `laus` and `cpi_chained`.

Not yet done: no unit tests written, no CPI weights path exercised through the
new wrapper, nothing run against the large sources (`ces`, `cps`, `sae`,
`oews`). The staged file is a working proof of the design, not a finished
migration.

## 7. Honest cost estimate

* Step 0, fixtures: half a day, mostly waiting on downloads.
* Steps 1 and 2, period fix and refactor: two to three days, most of it
  verifying rather than writing.
* Step 3, Tier 1: a day. The derived-key engine means new sources are usually
  one registry row.
* Steps 4 and 5: a day or two, plus however long you want to spend on the
  vignette.

The refactor is the expensive part and it is expensive because of verification,
not because of code volume. That is also the argument for doing it rather than
a rewrite: a rewrite has the same verification cost and a larger surface.
