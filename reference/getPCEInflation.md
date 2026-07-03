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

  Character string indicating the frequency of the data: `"M"` (monthly,
  the default) or `"Q"` (quarterly). Also sets the compounding used to
  annualize `WDataValue_P1a` (12 for monthly, 4 for quarterly).

- NIPA_data:

  Optional data frame. If provided, it will be used as the raw NIPA
  dataset instead of loading fresh data with
  [`getNIPAFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md).
  Make sure `frequency` matches the frequency of the supplied data,
  since it determines the annualization exponent.

## Value

A tibble with one row per (date, PCE component), containing the columns
from
[`getNIPAFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md)
for price-index table `"U20404"` (including `date`, `SeriesLabel`, and
the price index in `Value`), plus:

- PCEweight:

  Nominal consumption share: component spending divided by total PCE
  (both from table `"U20405"`).

- quantity:

  Real quantity index from table `"U20403"`.

- DataValue_P1:

  1-period percent change in the price index (decimal).

- DataValue_P3:

  3-period percent change (decimal).

- DataValue_P6:

  6-period percent change (decimal).

- WDataValue_P1:

  Contribution to 1-period PCE inflation: `DataValue_P1` times the
  lagged `PCEweight`.

- WDataValue_P1a:

  `WDataValue_P1` annualized by compounding over the periods per year
  implied by `frequency`: `(1 + x)^12 - 1` for monthly, `(1 + x)^4 - 1`
  for quarterly.

## Details

The function performs the following steps:

1.  Loads NIPA data using
    [`getNIPAFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md)
    (or uses pre-loaded data).

2.  Extracts total PCE from table `"U20405"` (series code `"DPCERC"`).

3.  Computes PCE component weights as the nominal consumption share
    (component value divided by total PCE).

4.  Extracts quantity indices from table `"U20403"`.

5.  Loads price indices from table `"U20404"`, joins weights and
    quantities, and calculates period-over-period growth measures.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Load monthly PCE data
  pce_data <- getPCEInflation("M")
} # }
```
