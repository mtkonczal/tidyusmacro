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
# \donttest{
  getUnrateFRED()
#> Downloading UNEMPLOY
#> Downloading CLF16OV
#> # A tibble: 936 × 4
#>    date       unemploy_level lf_level full_unrate
#>    <date>              <dbl>    <dbl>       <dbl>
#>  1 1948-01-01           2034    60095      0.0338
#>  2 1948-02-01           2328    60524      0.0385
#>  3 1948-03-01           2399    60070      0.0399
#>  4 1948-04-01           2386    60677      0.0393
#>  5 1948-05-01           2118    59972      0.0353
#>  6 1948-06-01           2214    60957      0.0363
#>  7 1948-07-01           2213    61181      0.0362
#>  8 1948-08-01           2350    60806      0.0386
#>  9 1948-09-01           2302    60815      0.0379
#> 10 1948-10-01           2259    60646      0.0372
#> # ℹ 926 more rows
# }
```
