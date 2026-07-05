# Date breaks anchored to last data month (for ggplot)

Create a breaks function for `scale_x_date()` that always includes the
last actual data month and then selects every `n`th month counting
backward.

## Usage

``` r
date_breaks_gg(n = 6, last, decreasing = FALSE)
```

## Arguments

- n:

  Integer; keep every n-th month counting backward from `last`. Default
  6.

- last:

  Date; the last (max) date in your data. Required to ensure no break is
  placed after your actual data.

- decreasing:

  Logical; if TRUE, return breaks in descending order. Default FALSE.

## Value

A function usable in `scale_x_date(breaks = ...)`.

## See also

[`date_breaks_n`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_n.md),
which takes the date vector directly and returns a vector of breaks
instead of a breaks function.

## Examples

``` r
# Minimal reproducible example (avoid using the name `df`, which masks stats::df)
set.seed(1)
dat <- data.frame(
  date  = seq(as.Date("2023-01-01"), by = "month", length.out = 24),
  value = cumsum(rnorm(24))
)

library(ggplot2)

ggplot(dat, aes(date, value)) +
  geom_line() +
  scale_x_date(
    date_labels = "%b\n%Y",
    breaks = date_breaks_gg(n = 6, last = max(dat$date))
  ) +
  labs(x = NULL, y = NULL)
```
