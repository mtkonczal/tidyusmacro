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
  also downloads `cu.aspect` and attaches monthly relative importance.
  Ignored for every other data source. Set to `FALSE` to skip the extra
  ~31 MB download.

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

For CPI with `weights = TRUE`, three further columns:

- weight:

  Relative importance in the observation month, in percent of all items

- weight_lag1:

  Relative importance one month earlier; the correct weight for a
  1-month contribution

- weight_lag12:

  Relative importance twelve months earlier; the correct weight for a
  12-month contribution

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

- BLS's published "Relative importance, December YYYY" tables are the
  **January YYYY+1** row of this file, not the December YYYY row.
  Verified exactly: the December 2024 table's shelter (35.483), owners'
  equivalent rent (26.282), gasoline (2.902), new vehicles (4.393) and
  used cars (2.391) are the January 2025 weights here, and December 2024
  itself carries different values. Anyone reconciling against a
  published December table should compare it to January.

- Contribution to the change in the all items index between *t-k* and
  *t* uses the weight at *t-k*, which is why the lagged columns are
  supplied. In percentage points,
  `weight_lag1 * (value / lag(value) - 1)` for the 1-month effect and
  `weight_lag12 * (value / lag(value, 12) - 1)` for the 12-month effect.
  These reproduce BLS's own `W1` and `WC` aspects, which
  [`getCPIAspects`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md)
  can retrieve as a cross-check.

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
