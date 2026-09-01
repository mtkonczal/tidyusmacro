# Plan: complete flat-file coverage for getBLSFiles()

> **Status, 2026-08-31: complete.** All three bugs in section 2 are
> fixed, the architecture in section 3 shipped for *every* source (the
> legacy/derived split it proposed was removed; see the banner in
> `recommendations.md`), and the validation checks in section 7 have
> been run live. The period fix gained a second half after this was
> written: computed averages are dated the last day of their period, not
> the first of December, so they can no longer share a date with an
> observed value. See `NEWS.md`.

> **Read `recommendations.md` first.** It covers the rewrite-vs-refactor
> decision, the sequencing, and the verified bug detail. This file is
> the survey inventory and tiering it refers to.
> `proposed/bls_rewrite.R` is the staged, runnable implementation.

Written 2026-08-19. All facts below were verified against
`https://download.bls.gov/pub/time.series/` on that date by fetching the
directory listings and the header row of every `.series` and lookup
file. Nothing here is from memory.

------------------------------------------------------------------------

## 1. Where we are

[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
exposes **12 aliases over 8 survey prefixes**: `cu`, `ci`, `cx`, `jt`,
`ln`, `ce`, `ap`, `sm`, `la`.

BLS publishes **65 survey directories** with data files (66 counting
`esbr`, which holds only `.sf` and `.gif` files and is not a time
series). So we cover about 12% of the prefixes, and within the prefixes
we do cover we join a subset of the available lookup tables.

## 2. Three bugs to fix before adding anything

### 2.1 Period parsing is wrong for non-monthly rows (P0)

[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
builds the date as `substr(period, 2, 3)` for every source except `eci`.
BLS period codes are not all monthly:

| code         | meaning             |
|--------------|---------------------|
| `M01`–`M12`  | month               |
| `M13`        | annual average      |
| `S01`, `S02` | first / second half |
| `S03`        | annual average      |
| `Q01`–`Q04`  | quarter             |
| `Q05`        | annual average      |
| `A01`        | annual              |

Under the current parser `S01`, `S02`, and `S03` become months 01, 02,
and 03, so half-year and annual-average rows are silently stamped as
January, February, and March. `M13` becomes `NA` with no warning.

This is not hypothetical. In `cu.data.1.AllItems` (63,945 rows, fetched
2026-08-19) the period distribution is:

    M13  6110    S01  3523    S03  3455    S02  3447

That is 10,425 rows silently mis-dated and 6,110 silently `NA`: 16,535
of 63,945 rows, 26%.

The harm is cross-series, not within-series. BLS publishes semiannual
observations on separate series (the `CUUS....AA0` family), never mixed
with monthly rows in the same series-year, so there are no duplicate
`series_id`/`date` pairs; I checked four files and measured zero. But
[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
returns many series in one frame, so grouping by date mixes them. For
`cu.data.1.AllItems`, the current code returns 117 rows for
`date == 1984-01-01`: 39 genuine January observations and 78 first-half
averages mislabeled as January.

**Fix**: one shared parser that returns `date` plus a `freq` column
(`"monthly"`, `"quarterly"`, `"semiannual"`, `"annual"`) and an
`is_average` flag, so average rows can be filtered rather than silently
mis-dated. Default
[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
to `include_averages = FALSE`. Implemented and tested in
`proposed/bls_rewrite.R`.

### 2.2 The `se` and `su` aliases collide with real BLS prefixes

Today `getBLSFiles("su", ...)` downloads the **`la`** (LAUS) files, and
`getBLSFiles("se", ...)` downloads the **`sm`** (SAE) files. But `su` is
a real BLS prefix: it is the **Chained CPI (C-CPI-U)**. `se` is not a
prefix at all.

Once we add chained CPI we cannot name it `su` without breaking released
code. Recommendation:

- Canonical names become `laus` and `sae`.
- `se` and `su` stay as deprecated aliases with a
  `lifecycle`/[`warning()`](https://rdrr.io/r/base/warning.html)
  pointing at the new names.
- Chained CPI ships as `cpi_chained`, never as `su`.

Flag this in `NEWS.md` explicitly. It is a naming change, not an
empirical one, but it will bite anyone with `"su"` in a script.

### 2.3 Two sources join fewer lookups than BLS provides

**Resolved 2026-08-31.** `cex` and `cps` were moved from the legacy
hand-mapped join list to the derived-key engine (section 3.1). Verified
live: row counts and `value` sums unchanged for both; CEX gained the
`subcategory` join below, CPS went from 7 lookups to 35. See `NEWS.md`.

- **CEX (`cx`)**: `cx.subcategory` is not in the mapping, so
  `subcategory_code` comes back as a bare code with no label, even
  though the `item` join already depends on it.
- **CPS (`ln`)**: we join 9 lookups; `ln` publishes about 35 (`ln.absn`,
  `ln.activity`, `ln.class`, `ln.disa`, `ln.duration`, `ln.indy`,
  `ln.mari`, `ln.mjhs`, `ln.pcts`, `ln.tdat`, `ln.vets`, `ln.wkst`, and
  more). Series carrying those dimensions come back unlabeled.

## 3. The architectural recommendation

**Stop hand-maintaining `file_mappings`. Derive the joins.**

The current code hardcodes a join key per lookup file (`{file}_code`)
plus a growing list of exceptions. That does not scale to 65 surveys,
and it is already wrong in places.

### 3.1 Derive join keys by column intersection

The rule that works: **the join key is every column ending in `_code`
that appears in both the lookup file and the `.series` file.**

I tested this against every lookup file in all 65 surveys. It produces a
valid key for **474 lookup joins** and auto-detects **30 compound
keys**, including the two currently hardcoded (`cx.characteristics`,
`cx.item`) and 28 the current code does not know about:

    wp.item      (group_code, item_code)          <- 4,013 rows, only 2,734 unique item_codes
    pc.product   (industry_code, product_code)
    nd.product   (industry_code, product_code)
    pd.product   (industry_code, product_code)
    wd.item      (group_code, item_code)
    la.area      (area_type_code, area_code)
    oe.area      (state_code, area_code, areatype_code)
    ii.industry  (supersector_code, industry_code)
    is.industry  (supersector_code, industry_code)
    cx.subcategory (category_code, subcategory_code)
    or.occupation  (occupation_code, soc_code)
    ... plus the injury/fatality surveys, all (case_code, category_code)

`wp.item` is the one that matters most in practice: PPI item codes are
only unique within a commodity group. Joining on `item_code` alone would
fan out the data. The existing `relationship = "many-to-one"` guard
would catch it and error, which is the right behavior, but the derived
key means it just works.

### 3.2 Handle the four cases where derivation fails

Of 169 lookup files with no derivable key, 132 are files that *should
not* be joined to `series` at all and are correctly skipped:

- `footnote` (54) and `period` (27) key to the **data** file, not
  `series`. Optional `join_footnotes = TRUE` /
  `join_period_labels = TRUE` arguments.
- `seasonal` (40) keys on the bare `seasonal` column against
  `seasonal_code`. Worth a single special case: it turns `"S"`/`"U"`
  into readable text.
- `aspect` (11) is a separate data file, not a lookup.
  [`getCPIAspects()`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md)
  already handles this for CPI; generalize it rather than folding it in.

The remaining ~37 failures cluster almost entirely in **discontinued**
surveys where BLS shipped the lookup file with no header row (`bg`,
`bp`, `ml`, `mu`, `mw`, `nc`, `cf`, `cd.category2`, `gp.charact`,
`ec.group`). These need hand-supplied column names, and they are all
Tier 4. Skip them with a warning until someone asks.

### 3.3 A registry users can actually read

Add an exported data frame and a function:

``` r

blsSources()                    # all sources, tier, frequency, size, status
blsSources(tier = 1)            # just the workhorses
blsFiles("cpi")                 # every data file inside a survey, with sizes
```

Columns: `name`, `prefix`, `title`, `data_file`, `frequency`,
`approx_mb`, `status` (`"current"` / `"discontinued"`), `tier`, `notes`,
`url`.

This solves the “clean way to communicate that” half of the ask. Right
now the only way to learn what is available is to read the roxygen block
or trigger the [`stop()`](https://rdrr.io/r/base/stop.html). Three
concrete improvements:

1.  [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
    with a bad name should suggest near matches
    (`agrep`/[`utils::adist`](https://rdrr.io/r/utils/adist.html))
    instead of dumping the full list.
2.  The pkgdown site gets a generated coverage table from
    [`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md),
    so it cannot drift from the code.
3.  Size warning: if `approx_mb > 200` and the session is interactive,
    message the download size before starting. Several of these are
    genuinely large (see §5).

### 3.4 Let users name a file directly

Many surveys ship one giant `AllData` file plus dozens of pre-sliced
ones. CPI has 21 data files, CES 55, SAE 86, LAUS 71, PPI industry 71. A
registry that names one file per survey throws away the rest.

Add a `file` argument:

``` r

getBLSFiles("ppi", email)                              # wp.data.0.Current
getBLSFiles("ppi", email, file = "data.21.Aggregates") # FD-ID aggregates only
blsFiles("ppi")                                        # discover what exists
```

This is how we get “all the potential data sources” without a 500-row
registry. The registry names the sensible default; `file` reaches the
rest.

## 4. Tiering

Ranked by how much a macro/policy shop actually uses them.

### Tier 1: monthly and quarterly release workhorses (7 new, 8 existing)

Everything on a release calendar you would write about.

| name | prefix | survey | status | notes |
|----|----|----|----|----|
| `cpi` | `cu` | CPI-U | **have** |  |
| `ces` | `ce` | CES national | **have** |  |
| `cps` | `ln` | CPS labor force | **have** | lookup coverage gap, §2.3 |
| `jolts` | `jt` | JOLTS | **have** |  |
| `eci` | `ci` | Employment Cost Index | **have** |  |
| `laus` | `la` | Local area unemployment | **have** (as `su`) | rename, §2.2 |
| `sae` | `sm` | State & area employment | **have** (as `se`) | rename, §2.2 |
| `avgprice` | `ap` | Average prices | **have** |  |
| **`ppi`** | `wp` | PPI commodity | new | 71.6 MB. The single biggest gap. |
| **`ppi_industry`** | `pc` | PPI industry/product | new | 64.3 MB |
| **`import_export`** | `ei` | Import/export prices | new | 11.7 MB. Tariff work. |
| **`productivity`** | `pr` | Major sector productivity & costs | new | 1.6 MB. ULC lives here. |
| **`cpi_w`** | `cw` | CPI-W | new | 46.7 MB. Social Security COLA. |
| **`cpi_chained`** | `su` | Chained CPI (C-CPI-U) | new | 0.4 MB. Tax bracket indexing. |
| **`ecec`** | `cm` | Employer costs for compensation | new | 15.0 MB. Benefits share of comp. |

### Tier 2: annual and structural, heavily used in research (6 new)

| name | prefix | survey | MB | why |
|----|----|----|----|----|
| **`oews`** | `oe` | Occupational employment & wages | 331.5 | Occupational wage distributions |
| **`bed`** | `bd` | Business employment dynamics | 197.6 | Gross job flows, firm dynamics |
| **`cex`** | `cx` | Consumer expenditure survey | 120.8 | **have**, add `subcategory` |
| **`cps_earnings`** | `le` | CPS earnings | 10.3 | Median usual weekly earnings |
| **`cps_union`** | `lu` | CPS union membership | 1.4 | Union density series |
| **`ind_productivity`** | `ip` | Industry productivity | 27.5 | Detailed-industry productivity |

### Tier 3: specialist, add on request (8 new)

`tfp` (`mp`, total factor productivity, 7.4 MB) · `cps_family` (`fm`,
marital/family LFS, 1.6 MB) · `atus` (`tu`, time use, 110 MB) ·
`ncs_benefits` (`nb`, benefits, 42 MB) · `ors` (`or`, occupational
requirements, 3.4 MB) · `work_stoppages` (`ws`, 0.2 MB) · `cfoi` (`fa`,
fatal injuries, 35 MB) · `osh_industry` (`is`, injury/illness industry,
241 MB) · `emp_projections` (`ep`, 6.2 MB) · `cps_veterans` (`kv`, 1.2
MB)

Also in this tier but flag the size: `osh_characteristics` (`ca`) is a
**2.9 GB** single file. Register it, warn loudly, do not make it easy to
trigger by accident.

### Tier 4: discontinued, register but do not implement (31 prefixes)

`bg` `bp` `cb` `cc` `cd` `cf` `ch` `cs` `ec` `ee` `eb` `fi` `fw` `gg`
`gp` `hc` `hs` `ii` `in` `jl` `li` `ml` `mu` `mw` `nc` `nd` `nw` `pd`
`sa` `sh` `si` `wd` `wm`

All have data files whose last update is 2024 or earlier; most are 2013
or earlier. Ship them in
[`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md)
with `status = "discontinued"` and a `last_updated` date so users can
see they exist and see why they should not use them. Do not write lookup
handling for them. Two exceptions worth implementing if anyone asks:
`wd`/`nd`/`pd` are still being *refreshed* (2026-08-13) even though they
hold discontinued series, so they are cheap to support once `wp`/`pc`
work.

## 5. Download sizes to warn about

Verified sizes of the representative file, 2026-08-19:

| survey                   | MB    | survey       | MB  |
|--------------------------|-------|--------------|-----|
| `ca` osh characteristics | 2,886 | `oe` OEWS    | 332 |
| `ln` CPS                 | 390   | `sm` SAE all | 543 |
| `ce` CES all series      | 350   | `bd` BED     | 198 |
| `is` osh industry        | 241   | `cx` CEX     | 121 |
| `tu` ATUS                | 110   | `wp` PPI     | 72  |

[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
currently downloads these with no size signal. At minimum, message the
size before starting. Better: an opt-in on-disk cache keyed by
`(url, remote mtime)`, which the existing `CLAUDE.md` backlog already
lists as medium priority. The BLS listing exposes an mtime per file, so
cache invalidation is exact rather than a guess at a TTL.

## 6. Proposed sequence

**Step 1 (bug fixes, no new sources).** Ship the period parser, the
`se`/`su` rename with deprecation, and the CEX/CPS lookup gaps. Add
regression tests that assert `S01` rows do not collide with `M01` rows,
and that `M13` produces either a labeled annual row or is filtered,
never a silent `NA`.

**Step 2 (refactor).** Replace `file_mappings` with a registry data
frame plus the derived-key join. Verify against the eight existing
sources first: same columns out, same row counts, before adding
anything. This is the step where an empirical regression could hide, so
diff the output of every current source before and after.

**Step 3 (Tier 1).** Add the seven new Tier 1 sources. `wp` is the first
real test of the derived compound key, so do it first.

**Step 4 (surface).**
[`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md),
[`blsFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/blsFiles.md),
fuzzy-match error message, generated pkgdown coverage table, and a
vignette.

**Step 5 (Tier 2 and 3, plus caching).**

## 7. Validation checks

- Every source in the registry: fetch, assert non-zero rows, assert no
  `.x`/`.y` columns, assert no `NA` dates outside declared
  annual-average rows.
- Assert each lookup join is many-to-one (already enforced; keep it).
- Spot-check three known values against published BLS tables: CPI-U all
  items NSA index, PPI final demand 12-month change, ECI total comp
  12-month change.
- Confirm frequency labeling: `ci` and `pr` quarterly, `cx` annual, `oe`
  annual, the rest monthly.
- Confirm the CPI weight logic in §“CPI relative importance” is
  unaffected by the period-parser change. It joins on `date`, so the
  S01/S02 fix changes which rows exist. Re-run
  `tests/testthat/test-cpi-weights.R`.

## Appendix: full survey inventory

Fetched 2026-08-19. “Representative file” is the largest `AllData` /
`AllItems` / `Current` file in the directory. “Auto-joinable lookups” is
the count of lookup files for which the §3.1 intersection rule produces
a valid key.

| prefix | survey | last data update | \# data files | representative file | MB | auto-joinable lookups |
|----|----|----|----|----|----|----|
| `ei` | Import/Export Price Indexes | 2026-08-18 | 14 | `ei.data.0.Current` | 11.7 | 1 |
| `ws` | Work Stoppages | 2026-08-14 | 1 | `ws.data.1.AllData` | 0.2 | 1 |
| `nd` | PPI Industry (discontinued codes) | 2026-08-13 | 70 | `nd.data.0.Current` | 46.7 | 2 |
| `pc` | PPI Industry | 2026-08-13 | 71 | `pc.data.0.Current` | 64.3 | 2 |
| `wd` | PPI Commodity (discontinued) | 2026-08-13 | 34 | `wd.data.0.Current` | 27.6 | 2 |
| `wp` | PPI Commodity | 2026-08-13 | 35 | `wp.data.0.Current` | 71.6 | 2 |
| `ap` | Average Price Data | 2026-08-12 | 4 | `ap.data.0.Current` | 8.9 | 2 |
| `ce` | CES National (Employment, Hours, Earnings) | 2026-08-12 | 55 | `ce.data.0.AllCESSeries` | 350.2 | 3 |
| `cu` | CPI-U (All Urban Consumers) | 2026-08-12 | 21 | `cu.data.0.Current` | 48.9 | 4 |
| `cw` | CPI-W (Urban Wage Earners) | 2026-08-12 | 21 | `cw.data.0.Current` | 46.7 | 4 |
| `su` | Chained CPI (C-CPI-U) | 2026-08-12 | 2 | `su.data.1.AllItems` | 0.4 | 4 |
| `ln` | CPS Labor Force Statistics | 2026-08-07 | 1 | `ln.data.1.AllData` | 389.7 | 34 |
| `pr` | Major Sector Productivity and Costs | 2026-08-06 | 2 | `pr.data.1.AllData` | 3.2 | 4 |
| `jt` | JOLTS | 2026-08-04 | 9 | `jt.data.1.AllItems` | 34.4 | 6 |
| `ci` | Employment Cost Index | 2026-07-31 | 2 | `ci.data.1.AllData` | 8.6 | 7 |
| `bd` | Business Employment Dynamics | 2026-07-29 | 2 | `bd.data.1.AllItems` | 253.5 | 11 |
| `la` | Local Area Unemployment Statistics (LAUS) | 2026-07-29 | 71 | `la.data.0.CurrentU20-24` | 121.4 | 5 |
| `le` | CPS Earnings | 2026-07-21 | 2 | `le.data.1.AllData` | 10.5 | 16 |
| `sm` | State & Area Employment, Hours, Earnings (SAE) | 2026-07-21 | 86 | `sm.data.1.AllData` | 543.1 | 5 |
| `tu` | American Time Use Survey | 2026-06-25 | 2 | `tu.data.1.AllData` | 110.3 | 35 |
| `ip` | Industry Productivity | 2026-06-24 | 2 | `ip.data.1.AllData` | 41.4 | 6 |
| `cm` | Employer Costs for Employee Compensation (ECEC) | 2026-06-12 | 2 | `cm.data.1.AllData` | 26.3 | 7 |
| `fa` | Census of Fatal Occupational Injuries (current) | 2026-05-20 | 2 | `fa.data.1.AllData` | 35.1 | 9 |
| `oe` | Occupational Employment & Wage Statistics (OEWS) | 2026-05-15 | 2 | `oe.data.1.AllData` | 331.5 | 6 |
| `kv` | CPS Veterans Supplement | 2026-04-28 | 1 | `kv.data.1.AllData` | 1.2 | 10 |
| `fm` | CPS Marital & Family Labor Force Stats | 2026-04-23 | 2 | `fm.data.1.AllData` | 1.6 | 24 |
| `mp` | Major Sector Total Factor Productivity | 2026-03-19 | 1 | `mp.data.1.AllData` | 7.4 | 3 |
| `lu` | CPS Union Membership | 2026-02-18 | 2 | `lu.data.1.AllData` | 1.4 | 14 |
| `ca` | Occ. Injuries & Illnesses - Characteristics | 2026-01-22 | 2 | `ca.data.1.AllData` | 2885.9 | 19 |
| `is` | Occ. Injuries & Illnesses Industry Data | 2026-01-22 | 1 | `is.data.1.AllData` | 241.2 | 5 |
| `or` | Occupational Requirements Survey | 2026-01-16 | 1 | `or.data.1.AllData` | 3.4 | 9 |
| `cx` | Consumer Expenditure Survey | 2025-12-19 | 1 | `cx.data.1.AllData` | 120.8 | 6 |
| `nb` | National Compensation Survey - Benefits | 2025-09-25 | 1 | `nb.data.1.AllData` | 42.3 | 8 |
| `ep` | Employment Projections | 2025-08-28 | 1 | `ep.data.1.AllData` | 6.2 | 7 |
| `wm` | Modeled Wage Estimates | 2024-08-22 | 1 | `wm.data.1.AllData` | 26.8 | 8 |
| `fw` | Census of Fatal Occupational Injuries | 2024-01-25 | 2 | `fw.data.1.AllData` | 621.7 | 9 |
| `cb` | Occ. Injuries & Illnesses - Characteristics | 2023-12-01 | 2 | `cb.data.1.AllData` | 2233.7 | 19 |
| `cs` | Occ. Injuries & Illnesses - Characteristics | 2023-04-06 | 2 | `cs.data.1.AllData` | 6072.4 | 19 |
| `li` | Department Store Inventory Price Index | 2016-07-15 | 2 | `li.data.1.AllData` | 0.6 | 2 |
| `ii` | Occ. Injuries & Illnesses Industry Data | 2014-12-18 | 1 | `ii.data.1.AllData` | 148.0 | 5 |
| `in` | International Labor Statistics | 2013-08-21 | 2 | `in.data.1.AllData` | 2.6 | 5 |
| `ml` | Mass Layoff Statistics | 2013-06-21 | 2 | `ml.data.1.AllData` | 260.8 | 1 |
| `gg` | Green Goods and Services | 2013-03-19 | 1 | `gg.data.1.AllData` | 0.2 | 9 |
| `fi` | Census of Fatal Occupational Injuries | 2012-04-25 | 2 | `fi.data.1.AllData` | 228.8 | 9 |
| `ch` | Occ. Injuries & Illnesses - Characteristics | 2012-01-09 | 2 | `ch.data.1.AllData` | 3369.7 | 19 |
| `nw` | National Compensation Survey (wages) | 2011-08-04 | 1 | `nw.data.1.AllData` | 2526.0 | 8 |
| `mu` | CPI-U (discontinued areas) | 2010-02-23 | 20 | `mu.data.0.Current` | 6.2 | 1 |
| `mw` | CPI-W (discontinued areas) | 2010-02-23 | 20 | `mw.data.0.Current` | 6.1 | 1 |
| `eb` | Employee Benefits Survey | 2006-09-13 | 1 | `eb.data.1.AllData` | 0.1 | 2 |
| `nc` | National Compensation Survey | 2006-08-31 | 1 | `nc.data.1.AllData` | 19.2 | 3 |
| `ec` | Employment Cost Index (historical) | 2006-05-10 | 2 | `ec.data.1.AllData` | 3.3 | 4 |
| `pd` | PPI Industry (SIC, discontinued) | 2005-04-19 | 29 | `pd.data.0.Current` | 55.2 | 2 |
| `cf` | Census of Fatal Occupational Injuries 1992-2002 | 2004-10-28 | 2 | `cf.data.1.AllData` | 23.7 | 7 |
| `hc` | Occ. Injuries & Illnesses - Characteristics | 2004-03-26 | 2 | `hc.data.1.AllData` | 11.2 | 15 |
| `cc` | Employer Costs for Employee Compensation (old) | 2004-02-26 | 2 | `cc.data.1.AllData` | 4.1 | 4 |
| `si` | Occ. Injuries & Illnesses Incidence Rates | 2003-12-18 | 1 | `si.data.1.AllData` | 0.8 | 4 |
| `jl` | JOLTS (historical) | 2003-08-08 | 2 | `jl.data.1.AllItems` | 0.3 | 4 |
| `ee` | CES National (historical AE/PW files) | 2003-05-16 | 81 | `ee.data.60.ManufactureAWHist` | 12.7 | 2 |
| `cd` | Occ. Injuries & Illnesses - Characteristics | 2003-04-09 | 2 | `cd.data.1.AllData` | 115.0 | 14 |
| `sa` | State & Area Employment (historical) | 2003-01-28 | 108 | `sa.data.0.Current` | 119.8 | 5 |
| `sh` | Occ. Injuries & Illnesses Incidence Rates | 2002-12-19 | 2 | `sh.data.1.AllData` | 15.4 | 3 |
| `gp` | Geographic Profile | 2000-02-04 | 1 | `gp.data.1.AllData` | 5.6 | 3 |
| `hs` | Occ. Injuries & Illnesses Incidence Rates | 1996-11-26 | 4 | `hs.data.1.1976to1980` | 4.0 | 3 |
| `bp` | Collective Bargaining - Private Sector | 1996-02-16 | 1 | `bp.data.1.AllData` | 0.2 | 1 |
| `bg` | Collective Bargaining - State/Local Govt | 1995-09-18 | 1 | `bg.data.1.AllData` | 0.0 | 0 |
