# tidyusmacro (development version)

## Bug fixes and improvements

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
