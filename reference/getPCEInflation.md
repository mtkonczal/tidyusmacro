# Load and Process Personal Consumption Expenditures (PCE) Inflation Data

Downloads and processes BEA NIPA data to compute Personal Consumption
Expenditures (PCE) price indices with weights and growth measures. This
is the Federal Reserve's preferred inflation measure.

## Usage

``` r
getPCEInflation(frequency = "M", NIPA_data = NULL)
```

## Arguments

- frequency:

  Character string indicating the frequency of the data. Defaults to
  `"M"` (monthly).

- NIPA_data:

  Optional data frame. If provided, it will be used as the raw NIPA
  dataset instead of loading fresh data with
  [`getNIPAFiles()`](https://mtkonczal.github.io/tidyusmacro/reference/getNIPAFiles.md).'

## Value

A `tbl_df` (data frame) containing the PCE data with calculated
variables.

## Details

The function performs the following steps:

1.  Loads NIPA data using
    [`getNIPAFiles`](https://mtkonczal.github.io/tidyusmacro/reference/getNIPAFiles.md)
    (or uses pre-loaded data).

2.  Extracts total PCE from table `"U20405"` (series code `"DPCERC"`).

3.  Computes PCE component weights as the nominal consumption share
    (component value divided by total PCE).

4.  Extracts quantity indices from table `"U20403"`.

5.  Loads price indices from table `"U20404"`, joins weights and
    quantities, and calculates period-over-period growth measures.

## Examples

``` r
# \donttest{
  # Load monthly PCE data
  pce_data <- getPCEInflation("M")
#> Start time: 2026-02-06 01:21:08.207363
#> Loading M data from https://apps.bea.gov/national/Release/TXT//nipadataM.txt
#> Formatting date column...
#> Splitting TableId:LineNo using stringi and unnesting...
#> End time: 2026-02-06 01:21:19.090909
# }
```
