# Download and Process Bureau of Labor Statistics Data

Downloads and processes data from Bureau of Labor Statistics (BLS) flat
files. Supports multiple data sources including CPI, ECI, JOLTS, CPS,
CES, and others. The function retrieves the main data file along with
associated metadata files, merges them, and returns a tidy tibble ready
for analysis.

## Usage

``` r
getBLSFiles(data_source, email, weights = TRUE)
```

## Arguments

- data_source:

  Character string specifying the BLS data source. Available options:

  `"cpi"`

  :   Consumer Price Index - current data

  `"eci"`

  :   Employment Cost Index (quarterly)

  `"cex"`

  :   Consumer Expenditure Survey

  `"jolts"`

  :   Job Openings and Labor Turnover Survey

  `"cps"`

  :   Current Population Survey

  `"ces"`

  :   Current Employment Statistics - all series

  `"ces_allemp"`

  :   Current Employment Statistics - all employees, seasonally adjusted

  `"ces_total"`

  :   Current Employment Statistics - total nonfarm employment

  `"averageprice"`

  :   Average price data - current

  `"food"`

  :   Average price data - food items

  `"se"`

  :   State and metro area employment

  `"su"`

  :   State and local area unemployment

- email:

  Character string with your email address. Required by BLS for
  identifying API users. Set as the HTTP User-Agent header.

- weights:

  Logical; for `data_source = "cpi"` only. When `TRUE` (the default),
  also downloads `cu.aspect` and attaches monthly relative importance
  plus BLS's own published contributions. Ignored for every other data
  source. Set to `FALSE` to skip the extra ~31 MB download.

## Value

A tibble containing the merged data with columns for:

- series_id:

  Unique identifier for each data series

- date:

  Observation date

- value:

  Numeric data value

- ...:

  Additional metadata columns vary by data source (e.g., item codes,
  industry codes, area codes)

For CPI with `weights = TRUE`, four further columns:

- weight:

  Relative importance, in percent of all items, on the base month for
  the 1-month change ending in this observation month. This is the
  weight for a 1-month contribution; do not lag it. See the dating note
  below.

- weight_12mo:

  Relative importance on the base month for the 12-month change ending
  in this observation month; the weight for a 12-month contribution

- effect_1m:

  BLS's own published effect on the 1-month all items change, in
  percentage points. Seasonally adjusted rows only.

- effect_12m:

  BLS's own published effect on the 12-month all items change, in
  percentage points. Not seasonally adjusted rows only.

## Details

The function constructs URLs to BLS flat files at
<https://download.bls.gov/pub/time.series/>, downloads the series
metadata and auxiliary lookup tables, then downloads and merges the main
data file. Date parsing handles both monthly (most sources) and
quarterly (ECI) data frequencies.

## CPI relative importance

Relative importance comes from `cu.aspect` (aspect type `"I"`), which
BLS restamps with every CPI release. Three things about the join are
worth knowing:

- It is keyed on `area_code` + `item_code` + `date`, not on `series_id`.
  BLS publishes relative importance only on the not seasonally adjusted
  series (`CUUR...`), but the weight describes the item, not the
  adjustment, so joining on `series_id` would return all `NA` for
  seasonally adjusted work. Codes rather than names, because BLS renames
  items and the codes are stable.

- Coverage is U.S. city average (`area_code == "0000"`) from March 2012
  forward. Outside that window `weight` is `NA` rather than back-filled:
  an imputed weight that looks like a real one is worse than a missing
  value. See the BLS relative importance archive for a pre-2012
  backfill.

- A row of `cu.aspect` stamped month *t* carries the relative importance
  BLS labels month *t-1*. This is the one thing about the file that
  reliably produces off-by-one errors, so it is worth stating twice: the
  weight you want for the change *ending* in month *t* is the row dated
  *t*, not a lag of it. Verified against the June 2026 release, where
  the "Relative importance May 2026" column of Tables 6 and 7 matches
  the 2026-06-01 rows for all 307 items exactly and the 2026-05-01 rows
  for only 43. The same shift is why BLS's published "Relative
  importance, December YYYY" table is the **January YYYY+1** row.

- Accordingly `weight` is the row dated *t* and needs no lag, and
  `weight_12mo` is the row dated *t-11* – eleven months back, because
  the RI labeled *t-12* lives in the *t-11* row.

- Both weight columns are joined on a month index, never by row
  position. BLS omits rows entirely for intermittently priced items
  rather than writing NA, so a positional lag borrows the wrong month's
  weight without warning.

## Contributions

`effect_1m` and `effect_12m` are BLS's own decomposition, and they equal
the "effect on All Items" columns of news release Tables 6 and 7
exactly. Use them for anything BLS publishes.

`weight` and `weight_12mo` are for aggregations BLS does not publish.
For a 12-month contribution, `weight_12mo * (value / lag12(value) - 1)`
on the NSA series is a good approximation. For a 1-month contribution on
the *seasonally adjusted* series, note that relative importance is
defined on the NSA index and has to be rescaled by the item's seasonal
factor relative to all items before it will reproduce BLS's number; see
[`getCPIAspects`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md)
for the exact formula.

In both cases lag by calendar month, not row position.

## See also

[`getCPIAspects`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md)
for the other CPI aspect types: BLS's own contribution decomposition,
median standard errors, and seasonal factors.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Download CPI data with monthly relative importance attached
  cpi_data <- getBLSFiles("cpi", "your.email@example.com")

  # Skip the weights download
  cpi_fast <- getBLSFiles("cpi", "your.email@example.com", weights = FALSE)

  # Download JOLTS data
  jolts_data <- getBLSFiles("jolts", "your.email@example.com")
} # }
```
