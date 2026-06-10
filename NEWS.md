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
