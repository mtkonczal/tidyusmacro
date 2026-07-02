# Get Full Unemployment Rate from FRED

Downloads the civilian unemployment level and labor force level from
FRED, and calculates the unemployment rate as \\\text{unemploy\\level} /
\text{lf\\level}\\.

## Usage

``` r
getUnrateFRED()
```

## Value

A tibble with columns:

- date:

  Observation date

- unemploy_level:

  Civilian unemployment level (in thousands)

- lf_level:

  Civilian labor force level (in thousands)

- full_unrate:

  Unemployment rate (decimal)

## Examples

``` r
if (FALSE) { # \dontrun{
  getUnrateFRED()
} # }
```
