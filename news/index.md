# Changelog

## tidyusmacro 0.3.0

### Breaking changes

- **[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  now uses one join engine for every source.** The hand-maintained
  per-source lookup list that served `cpi`, `eci`, `jolts`, `ces`,
  `ces_allemp`, `ces_total`, `averageprice`, `food`, `sae` and `laus` is
  gone; all ten now go through the same derived-key engine as everything
  else. The practical effect is that they join every lookup BLS
  publishes for the survey rather than a curated subset, so each gains
  columns: all ten gain `seasonal_text`, CPI also gains `base_text` and
  `periodicity_text`, ECI gains `area_*`, and JOLTS gains `area_*` and
  `ratelevel_*`. No column was renamed or dropped. Verified live, before
  and after, for all ten: row counts, `value` sums, the series universe,
  and per-column NA counts are identical (`verification/capture.R` and
  `compare.R` re-run the diff).
- **Column types changed.** Every BLS file is now read as all-character
  and then selectively re-typed, instead of letting `readr` guess per
  column. Codes that readr used to guess as numeric are now character,
  which is the point: a code like `"0000"` no longer becomes `0`.
  `year`, `begin_year`, `end_year`, `*_display_level` and
  `*_sort_sequence` are integer; `*_selectable` is logical; `value` is
  numeric. Anything else is character. `display_level` is the one to
  watch: as character it compares lexically, so it is deliberately
  re-typed to integer and a hierarchy filter still sorts numerically.
- **BLS-computed average rows are dated the last day of their period.**
  `M13` is now `YYYY-12-31` rather than `YYYY-12-01`, `S01` is
  `YYYY-06-30`, and `S02`/`S03`/`Q05`/`A01` are `YYYY-12-31`. Observed
  values (`M01`-`M12`, `Q01`-`Q04`) are unchanged on the first of the
  month. Previously an annual average shared a `Date` with the real
  December observation for the same series, so `group_by(date)` across
  many series double-counted silently. It now cannot: no computed
  average shares a date with an observed value. Averages still share a
  date with each other, which `is_average` or `freq` separates. Only
  affects rows where `is_average` is `TRUE`.
- [`getCPIAspects()`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md)
  gained `freq` and `is_average` columns, and its dates now come from
  the shared period parser. Additive; positional column indexing will
  shift.
- `getBLSFiles("se", ...)` and `getBLSFiles("su", ...)` now warn on
  every call and redirect to the new canonical names `"sae"` and
  `"laus"`. The old names still work and return the same data (`se` was
  never a real BLS prefix; `su`, however, *is* a real prefix – Chained
  CPI – which is why the rename was necessary before that source could
  be added; see `"cpi_chained"` below). Update scripts to the new names
  to silence the warning; there is no deadline to do so yet.
- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  gained two new columns for every source, `freq` and `is_average` (see
  the period-parsing fix below). This is additive and does not change
  existing columns, but code that assumes a fixed column count or does
  `names(df)[n]` positionally will see the shift.

### Bug fixes and improvements

- **[`getCPIAspects()`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md)
  had the same period-parsing bug
  [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  did**, and it was missed when that was fixed. It computed `date` as
  `substr(period, 2, 3)`, and `build_weight_bases()` computed the month
  index the same way, so an `M13` relative-importance row would have
  been treated as January of the following year, shifting the CPI weight
  panel. The uniqueness check would not have caught it, because month 13
  collides with no real month. Verified live 2026-08-31 that `cu.aspect`
  publishes only `M01`-`M12` for every aspect type, so no published
  weight was ever wrong; this closes the trap rather than fixing a live
  error. Both now use the shared parser, and `build_weight_bases()`
  explicitly keeps observed monthly rows only.

- **All BLS downloads now retry.** Every request goes through
  [`httr::RETRY`](https://httr.r-lib.org/reference/RETRY.html) with an
  HTTP/1.1 fallback for transport-level resets and a hard status check,
  matching the hardening
  [`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
  already had. This covers the directory listing, the lookup tables, the
  main data file and `cu.aspect`. Previously a single transient failure
  aborted the call, which is a poor property for a script that runs at
  8:31am on a release day. The contact email is now passed as an
  explicit `User-Agent` rather than through the process-global
  `options(HTTPUserAgent=)`; BLS returns 403 without it.

- **Release-day pulls no longer depend on scraping BLS’s HTML directory
  listing.** `bls_registry()` now pins the lookup file list for every
  tier 1 source, so
  [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  can build the fully labeled series table without the listing. The
  listing is still used for the `max_mb` size guard, but its failure is
  now a warning with a `HEAD`-request fallback rather than a fatal
  error. Sources outside tier 1 still discover their lookups from the
  listing.

- Fixed an unhelpful failure on the discontinued (tier 4) surveys. They
  have no default data file, and the `NA` fell through to a subset that
  returned NA-filled rows, so the call died with
  `missing value where TRUE/FALSE needed` after a wasted round trip. It
  now errors immediately with the
  [`blsFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/blsFiles.md)
  call that lists what the survey still publishes.

- `include_averages = FALSE` now errors on a source that publishes
  nothing but averages (CEX, which publishes only `A01`) instead of
  silently returning zero rows.

- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  now reports how many `value` entries were non-numeric and became `NA`,
  rather than converting silently.

- **Fixed silently wrong dates for BLS period codes other than plain
  monthly/quarterly.**
  [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  computed `date` as `substr(period, 2, 3)` for every source but ECI.
  That is correct for `M01`-`M12` and, via a special case, ECI’s
  `Q01`-`Q04`, but BLS also publishes computed-average rows on other
  period codes, and the old parser mis-stamped them: half-year averages
  (`S01`, `S02`) became January and February, `S03` became March, and
  the annual average (`M13`) became a silent `NA`. Verified on
  `cu.data.1.AllItems` (2026-08-19): 26% of rows were affected, and
  grouping by date across the many series
  [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  returns in one table would silently mix half-year averages into
  January and February. All period codes now go through one shared
  parser (`freq`/`is_average` columns document the result), and every
  row gets a correct date. **Row counts and `value` are unchanged for
  every existing source** – this was verified by diffing live output
  before and after for all 12 previously supported sources, including
  full row-count and value-sum parity. Average rows are not dropped by
  default (unlike an earlier draft of this fix): CEX publishes nothing
  but annual (`A01`) rows, so defaulting to drop “averages” would have
  silently zeroed out that entire source. Pass
  `include_averages = FALSE` to drop them explicitly.

- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  now supports 7 new sources beyond the original 12: `ppi`,
  `ppi_industry`, `import_export`, `productivity`, `ecec`, `cpi_w`, and
  `cpi_chained`. Their lookup-table joins are derived automatically (the
  key is any `*_code` column shared between a lookup file and `series`,
  which also auto-detects compound keys BLS uses in some surveys,
  e.g. `wp.item` is keyed on `(group_code, item_code)`, not `item_code`
  alone) rather than hand-mapped per source, so future sources are
  usually a one-line registry addition. See
  [`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md).

- New
  [`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md)
  lists every registered BLS source (68 total: 19 in Tier 1, 5 in Tier
  2, and 11 in Tier 3, all live-verified against BLS’s flat files as of
  2026-08-31 with the exception of `osh_characteristics` (a 2.9 GB file,
  intentionally gated behind `max_mb`, not pulled routinely) – plus 33
  discontinued sources registered for discoverability, excluded by
  default) with size, frequency, and tier. New `blsFiles(source, email)`
  lists every file BLS publishes within a source’s directory, with size
  and last-modified date, for use with the new `file =` argument.

- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  gained `file =` (pick a non-default data file within a survey; only
  the 7 new sources above, not the original 12, whose joins are tied to
  their default file) and `max_mb =` (refuse an unexpectedly large
  download, e.g. the 2.9 GB `osh_characteristics` case in
  [`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md),
  without an explicit override).

- An unknown `data_source` now suggests near matches
  (e.g. `"ppi_indsutry"` suggests `ppi_industry`) instead of dumping the
  full source list.

- Fixed two lookup-coverage gaps flagged in `BLS_COVERAGE_PLAN.md`
  section 2.3: `getBLSFiles("cex", ...)` was missing the
  `cx.subcategory` lookup (`subcategory_code` came back unlabeled even
  though the `item` join already depends on it), and
  `getBLSFiles("cps", ...)` joined only 7 of the roughly 35 lookups `ln`
  publishes. Both sources moved from the hand-maintained legacy join
  list to the derived-key engine (the same one the new sources above
  use). Verified live: row counts and `value` sums are unchanged for
  both; CEX gains 4 new `subcategory_*` columns and CPS gains 28 new
  lookup joins (`absn`, `activity`, `cert`, `chld`, `class`, `disa`,
  `duration`, `entr`, `expr`, `hheader`, `hour`, `indy`, `jdes`, `look`,
  `mari`, `mjhs`, `orig`, `pcts`, `periodicity`, `rjnw`, `rnlf`, `rwns`,
  `seasonal`, `seek`, `tdat`, `tlwk`, `vets`, `wkst`) on top of the 7 it
  already had, matching `ln`’s ~35 lookup files. All additive – no
  existing column was renamed or dropped.

- [`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
  downloads are now more robust: transient failures are retried up to 3
  times with backoff, and transport-level errors (FRED’s intermittent
  “HTTP/2 stream was not closed cleanly” resets) trigger a fallback
  request over HTTP/1.1. Bad series IDs (HTTP 400/404) still fail fast.

- [`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
  now parses FRED’s `"."` missing-value marker as `NA`, so value columns
  stay numeric instead of silently becoming character.

- The network layer of
  [`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
  was factored into an internal helper so it can be mocked; added a full
  offline unit-test suite plus live integration tests (skipped on CRAN
  and when offline) for
  [`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
  and
  [`getUnrateFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getUnrateFRED.md).

- [`getPCEInflation()`](https://www.mikekonczal.com/tidyusmacro/reference/getPCEInflation.md)
  now annualizes `WDataValue_P1a` using the compounding implied by
  `frequency` (12 periods for monthly, 4 for quarterly). It previously
  always used `^4`, which understated annualized contributions for
  monthly data (the default) by roughly a factor of three. Monthly
  values of `WDataValue_P1a` will change; other columns are unaffected.

- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  join handling is hardened: colliding non-key columns in lookup files
  are now detected dynamically and prefixed with the file name (in
  addition to the always-prefixed metadata columns), all joins validate
  `relationship = "many-to-one"` so a non-unique lookup key errors
  loudly instead of silently duplicating rows, and a final invariant
  check guarantees no `.x`/`.y` columns. Output for all currently
  supported data sources is unchanged.

- tidyusmacro now requires dplyr \>= 1.1.0 (for join `relationship`
  validation).

- `getBLSFiles("su")` works again: the LAU state/region/division lookup
  is now requested as `la.state_region_division` (a misspelling,
  `state_region_divison`, made every `su` call fail with a 404) and
  joined on its actual key, `srd_code`, so `srd_text` is attached to the
  output.

- Documentation improvements throughout: a package-level help page
  ([`?tidyusmacro`](https://www.mikekonczal.com/tidyusmacro/reference/tidyusmacro-package.md)),
  examples and fuller descriptions for
  [`theme_esp()`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md),
  `esp_pal`, and `esp_navy`, documented return columns for
  [`getNIPAFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md)
  and
  [`getPCEInflation()`](https://www.mikekonczal.com/tidyusmacro/reference/getPCEInflation.md),
  and cross-references between
  [`date_breaks_gg()`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_gg.md)
  and
  [`date_breaks_n()`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_n.md).

## tidyusmacro 0.2.0

CRAN release: 2026-06-12

### Breaking changes

- [`logLinearProjection()`](https://www.mikekonczal.com/tidyusmacro/reference/logLinearProjection.md)
  has a new data-masked interface designed for use inside dplyr verbs:
  it now takes bare column names
  (`logLinearProjection(date, value, start_date, end_date)`) instead of
  a data frame plus column-name strings
  (`logLinearProjection(tbl, "date", "value", ...)`). Code using the old
  string-based interface must be updated.

### New features

- [`getDallasTrimPCE()`](https://www.mikekonczal.com/tidyusmacro/reference/getDallasTrimPCE.md)
  downloads the component-level data underlying the Dallas Fed Trimmed
  Mean PCE inflation rate and returns a tidy panel with trimming weights
  and trim-side flags.
- [`getUnrateFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getUnrateFRED.md)
  retrieves unemployment and labor force levels from FRED and computes
  the unemployment rate.
- [`date_breaks_gg()`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_gg.md)
  and
  [`date_breaks_n()`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_n.md)
  provide evenly spaced date breaks for ggplot2 axes.
- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  supports Consumer Expenditure Survey flat files
  (`data_source = "cex"`).
- New dataset `dallasTrimPCEcomponents` maps PCE line items to Dallas
  Fed trimmed-mean components.

### Bug fixes and improvements

- [`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
  downloads via
  [`httr::GET()`](https://httr.r-lib.org/reference/GET.html) with an
  explicit user agent, fixing intermittent “HTTP/2 stream was not closed
  cleanly” failures against FRED’s CSV endpoint.
- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  no longer produces duplicate `.x`/`.y` columns when lookup files share
  metadata column names; shared metadata columns are prefixed with the
  lookup file name.
- [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  now restores the user’s `HTTPUserAgent` option on exit.
- [`logLinearProjection()`](https://www.mikekonczal.com/tidyusmacro/reference/logLinearProjection.md)
  no longer calls the deprecated
  [`dplyr::cur_data_all()`](https://dplyr.tidyverse.org/reference/deprec-context.html),
  which warned on every use under dplyr \>= 1.1.0; it now uses
  [`dplyr::pick()`](https://dplyr.tidyverse.org/reference/pick.html).
  Calls using the old pre-0.2.0 string interface fail with an
  informative error pointing to the new interface.
- Added a testthat suite covering
  [`logLinearProjection()`](https://www.mikekonczal.com/tidyusmacro/reference/logLinearProjection.md).

## tidyusmacro 0.1.0

CRAN release: 2025-09-30

- Initial CRAN submission.
