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

A vector of dates suitable for use as ggplot2 axis breaks. With the
default `decreasing = TRUE`, the first (most recent) date is always
included, so breaks are anchored to the last observation.

## See also

[`date_breaks_gg`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_gg.md),
which returns a breaks *function* for
[`scale_x_date()`](https://ggplot2.tidyverse.org/reference/scale_date.html)
and clips breaks to the plot limits.

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
