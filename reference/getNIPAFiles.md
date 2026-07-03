# Download and Process BEA NIPA Files with Fast Row Expansion

This function downloads and processes National Income and Product
Accounts (NIPA) data files from the BEA website. It reads the necessary
register files, formats the date column, and then uses the fast stringi
functions together with tidyr's unnest() to split the combined
`TableId:LineNo` field into separate rows and columns. Finally, it
merges the datasets.

## Usage

``` r
getNIPAFiles(
  location = "https://apps.bea.gov/national/Release/TXT/",
  type = "Q"
)
```

## Arguments

- location:

  The URL or path where the BEA files are located. Default:
  "https://apps.bea.gov/national/Release/TXT/".

- type:

  A character string indicating the type of data to load. For example,
  "Q" for quarterly or "M" for monthly data. Default is "Q".

## Value

A tibble with one row per (series, period, table line). Because a NIPA
series can appear on multiple table lines, series-periods are duplicated
across rows; filter on `TableId` (and `LineNo`) before analysis. Key
columns:

- SeriesCode:

  BEA series mnemonic (from `SeriesRegister.txt`).

- Period:

  Raw BEA period string, e.g. `"2024Q1"` or `"2024M01"`.

- date:

  Period as a `Date` (quarters mapped to their final month).

- Value:

  Numeric data value.

- TableId:

  NIPA table identifier, e.g. `"U20404"`.

- LineNo:

  Numeric line number within the table.

- ...:

  Additional series metadata from `SeriesRegister.txt` (including
  `SeriesLabel`) and table metadata from `TablesRegister.txt`.

## Examples

``` r
if (FALSE) { # \dontrun{
  nipadata <- getNIPAFiles(type = "Q")
} # }
```
