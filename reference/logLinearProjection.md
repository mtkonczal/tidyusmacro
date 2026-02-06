# Log-Linear Projection (data-masked, dplyr-native)

Fits a log-linear trend `log(value) ~ t` on a calibration window and
projects it for rows on/after `start_date`. Designed for use inside
dplyr verbs (no need to pass `.`).

## Usage

``` r
logLinearProjection(
  date,
  value,
  start_date,
  end_date,
  group = NULL,
  data = NULL
)
```

## Arguments

- date:

  Bare column name for the date variable (coercible to Date).

- value:

  Bare column name for the positive numeric series to project.

- start_date:

  Date or string coercible to Date; start of calibration.

- end_date:

  Date or string coercible to Date; end of calibration.

- group:

  Optional bare column name to group by before projecting.

- data:

  Optional data frame. If omitted, uses the current data mask (e.g.,
  inside
  [`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)) via
  [`dplyr::cur_data_all()`](https://dplyr.tidyverse.org/reference/deprec-context.html).

## Value

A numeric vector `projection` aligned to the input rows; `NA` before
`start_date`. Respects grouping if `group` is supplied.
