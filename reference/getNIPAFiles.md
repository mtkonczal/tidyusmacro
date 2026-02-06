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

A data frame containing the merged and formatted NIPA data.

## Examples

``` r
# \donttest{
  nipadata <- getNIPAFiles(type = "Q")
#> Start time: 2026-02-06 01:20:56.058559
#> Loading Q data from https://apps.bea.gov/national/Release/TXT//nipadataQ.txt
#> Formatting date column...
#> Splitting TableId:LineNo using stringi and unnesting...
#> End time: 2026-02-06 01:21:08.094141
# }
```
