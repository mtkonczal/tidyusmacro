# Changelog

## tidyusmacro (development version)

\<\<\<\<\<\<\< HEAD \## Bug fixes and improvements

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
  =======
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
  \>\>\>\>\>\>\> worktree-fix-getfred

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
