# tidyusmacro (development version)

## Breaking changes

* `getBLSFiles("se", ...)` and `getBLSFiles("su", ...)` now warn on every call
  and redirect to the new canonical names `"sae"` and `"laus"`. The old names
  still work and return the same data (`se` was never a real BLS prefix;
  `su`, however, *is* a real prefix -- Chained CPI -- which is why the rename
  was necessary before that source could be added; see `"cpi_chained"`
  below). Update scripts to the new names to silence the warning; there is no
  deadline to do so yet.
* `getBLSFiles()` gained two new columns for every source, `freq` and
  `is_average` (see the period-parsing fix below). This is additive and does
  not change existing columns, but code that assumes a fixed column count or
  does `names(df)[n]` positionally will see the shift.

## Bug fixes and improvements

* **Fixed silently wrong dates for BLS period codes other than plain
  monthly/quarterly.** `getBLSFiles()` computed `date` as
  `substr(period, 2, 3)` for every source but ECI. That is correct for
  `M01`-`M12` and, via a special case, ECI's `Q01`-`Q04`, but BLS also
  publishes computed-average rows on other period codes, and the old parser
  mis-stamped them: half-year averages (`S01`, `S02`) became January and
  February, `S03` became March, and the annual average (`M13`) became a
  silent `NA`. Verified on `cu.data.1.AllItems` (2026-08-19): 26% of rows
  were affected, and grouping by date across the many series `getBLSFiles()`
  returns in one table would silently mix half-year averages into January
  and February. All period codes now go through one shared parser
  (`freq`/`is_average` columns document the result), and every row gets a
  correct date. **Row counts and `value` are unchanged for every existing
  source** -- this was verified by diffing live output before and after
  for all 12 previously supported sources, including full row-count and
  value-sum parity. Average rows are not dropped by default (unlike an
  earlier draft of this fix): CEX publishes nothing but annual (`A01`) rows,
  so defaulting to drop "averages" would have silently zeroed out that
  entire source. Pass `include_averages = FALSE` to drop them explicitly.
* `getBLSFiles()` now supports 7 new sources beyond the original 12: `ppi`,
  `ppi_industry`, `import_export`, `productivity`, `ecec`, `cpi_w`, and
  `cpi_chained`. Their lookup-table joins are derived automatically (the key
  is any `*_code` column shared between a lookup file and `series`, which
  also auto-detects compound keys BLS uses in some surveys, e.g. `wp.item`
  is keyed on `(group_code, item_code)`, not `item_code` alone) rather than
  hand-mapped per source, so future sources are usually a one-line registry
  addition. See `blsSources()`.
* New `blsSources()` lists every registered BLS source (68 total: 19 in Tier
  1, 5 in Tier 2, and 11 in Tier 3 -- all reachable through `getBLSFiles()`
  today, though only Tier 1 is live-verified so far -- plus 33 discontinued
  sources registered for discoverability, excluded by default) with size,
  frequency, and tier.
  New `blsFiles(source, email)` lists every file BLS publishes within a
  source's directory, with size and last-modified date, for use with the new
  `file =` argument.
* `getBLSFiles()` gained `file =` (pick a non-default data file within a
  survey; only the 7 new sources above, not the original 12, whose joins are
  tied to their default file) and `max_mb =` (refuse an unexpectedly large
  download, e.g. the 2.9 GB `osh_characteristics` case in `blsSources()`,
  without an explicit override).
* An unknown `data_source` now suggests near matches (e.g. `"ppi_indsutry"`
  suggests `ppi_industry`) instead of dumping the full source list.
* `getFRED()` downloads are now more robust: transient failures are retried
  up to 3 times with backoff, and transport-level errors (FRED's intermittent
  "HTTP/2 stream was not closed cleanly" resets) trigger a fallback request
  over HTTP/1.1. Bad series IDs (HTTP 400/404) still fail fast.
* `getFRED()` now parses FRED's `"."` missing-value marker as `NA`, so value
  columns stay numeric instead of silently becoming character.
* The network layer of `getFRED()` was factored into an internal helper so it
  can be mocked; added a full offline unit-test suite plus live integration
  tests (skipped on CRAN and when offline) for `getFRED()` and
  `getUnrateFRED()`.
* `getPCEInflation()` now annualizes `WDataValue_P1a` using the compounding
  implied by `frequency` (12 periods for monthly, 4 for quarterly). It
  previously always used `^4`, which understated annualized contributions
  for monthly data (the default) by roughly a factor of three. Monthly
  values of `WDataValue_P1a` will change; other columns are unaffected.
* `getBLSFiles()` join handling is hardened: colliding non-key columns in
  lookup files are now detected dynamically and prefixed with the file name
  (in addition to the always-prefixed metadata columns), all joins validate
  `relationship = "many-to-one"` so a non-unique lookup key errors loudly
  instead of silently duplicating rows, and a final invariant check
  guarantees no `.x`/`.y` columns. Output for all currently supported data
  sources is unchanged.
* tidyusmacro now requires dplyr >= 1.1.0 (for join `relationship`
  validation).
* `getBLSFiles("su")` works again: the LAU state/region/division lookup is
  now requested as `la.state_region_division` (a misspelling,
  `state_region_divison`, made every `su` call fail with a 404) and joined
  on its actual key, `srd_code`, so `srd_text` is attached to the output.
* Documentation improvements throughout: a package-level help page
  (`?tidyusmacro`), examples and fuller descriptions for `theme_esp()`,
  `esp_pal`, and `esp_navy`, documented return columns for
  `getNIPAFiles()` and `getPCEInflation()`, and cross-references between
  `date_breaks_gg()` and `date_breaks_n()`.

# tidyusmacro 0.2.0

## Breaking changes

* `logLinearProjection()` has a new data-masked interface designed for use
  inside dplyr verbs: it now takes bare column names
  (`logLinearProjection(date, value, start_date, end_date)`) instead of a
  data frame plus column-name strings
  (`logLinearProjection(tbl, "date", "value", ...)`). Code using the old
  string-based interface must be updated.

## New features

* `getDallasTrimPCE()` downloads the component-level data underlying the
  Dallas Fed Trimmed Mean PCE inflation rate and returns a tidy panel with
  trimming weights and trim-side flags.
* `getUnrateFRED()` retrieves unemployment and labor force levels from FRED
  and computes the unemployment rate.
* `date_breaks_gg()` and `date_breaks_n()` provide evenly spaced date breaks
  for ggplot2 axes.
* `getBLSFiles()` supports Consumer Expenditure Survey flat files
  (`data_source = "cex"`).
* New dataset `dallasTrimPCEcomponents` maps PCE line items to Dallas Fed
  trimmed-mean components.

## Bug fixes and improvements

* `getFRED()` downloads via `httr::GET()` with an explicit user agent,
  fixing intermittent "HTTP/2 stream was not closed cleanly" failures
  against FRED's CSV endpoint.
* `getBLSFiles()` no longer produces duplicate `.x`/`.y` columns when
  lookup files share metadata column names; shared metadata columns are
  prefixed with the lookup file name.
* `getBLSFiles()` now restores the user's `HTTPUserAgent` option on exit.
* `logLinearProjection()` no longer calls the deprecated
  `dplyr::cur_data_all()`, which warned on every use under dplyr >= 1.1.0;
  it now uses `dplyr::pick()`. Calls using the old pre-0.2.0 string
  interface fail with an informative error pointing to the new interface.
* Added a testthat suite covering `logLinearProjection()`.

# tidyusmacro 0.1.0

* Initial CRAN submission.
