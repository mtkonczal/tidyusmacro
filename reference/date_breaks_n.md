# Create evenly spaced breaks

Generate a sequence of date breaks for ggplot scales, taking every `n`th
unique date.

## Usage

``` r
date_breaks_n(dates, n = 6, decreasing = TRUE)
```

## Arguments

- dates:

  A vector of dates.

- n:

  Integer, keep every n-th date (default = 6).

- decreasing:

  Logical, if TRUE (default) sorts dates in descending order.

## Value

A vector of dates suitable for use as ggplot2 axis breaks.

## Examples

``` r
library(ggplot2)
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union

df <- tibble(
  date = seq.Date(as.Date("2020-01-01"), as.Date("2025-01-01"), by = "month"),
  value = rnorm(61)
)

ggplot(df, aes(date, value)) +
  geom_line() +
  scale_x_date(breaks = date_breaks_n(df$date, 6))
```
