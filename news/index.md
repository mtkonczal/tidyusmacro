# Changelog

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
