# Download and Process Bureau of Labor Statistics Data

Downloads and processes data from Bureau of Labor Statistics (BLS) flat
files. Supports multiple data sources including CPI, ECI, JOLTS, CPS,
CES, and others. The function retrieves the main data file along with
associated metadata files, merges them, and returns a tidy tibble ready
for analysis.

## Usage

``` r
getBLSFiles(data_source, email)
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

## Details

The function constructs URLs to BLS flat files at
<https://download.bls.gov/pub/time.series/>, downloads the series
metadata and auxiliary lookup tables, then downloads and merges the main
data file. Date parsing handles both monthly (most sources) and
quarterly (ECI) data frequencies.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Download CPI data
  cpi_data <- getBLSFiles("cpi", "your.email@example.com")

  # Download JOLTS data
  jolts_data <- getBLSFiles("jolts", "your.email@example.com")
} # }
```
