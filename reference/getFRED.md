# Download and Merge FRED Series

A flexible wrapper that downloads one or more data series from the St.
Louis Fed (FRED) API, optionally computes one-period percentage changes,
and merges them into a tidy tibble keyed by `date`.

## Usage

``` r
getFRED(..., keep_all = TRUE, rename_variables = NULL, lagged = NULL)
```

## Arguments

- ...:

  One or more FRED series IDs. Each element may be either

  Unnamed character string

  :   The raw FRED ticker; column keeps the lowercase ticker name,
      e.g.\\ `"UNRATE"`.

  Named character string

  :   The value is the FRED ticker and the name becomes the column
      label, e.g.\\ `payroll = "PAYEMS"`.

  You may also pass a single character vector (named or unnamed) for
  compatibility with older code.

- keep_all:

  Logical. `TRUE` (default) performs a full join that keeps all dates
  across series; `FALSE` performs an inner join.

- rename_variables:

  Optional character vector of new column names (one per series),
  retained for backward compatibility. Supply *either* this argument
  *or* names in `...`, not both.

- lagged:

  Logical scalar or logical vector. If `TRUE` (or the corresponding
  element is `TRUE`), the series is replaced by its one-period
  percentage change \\(x_t / x\_{t-1}) - 1\\. Recycled to match the
  number of series if length 1.

## Value

A tibble with a `date` column and one column per requested series.

## Details

You may supply the series in two ways:

- **Natural “`...`” style**:
  `getFRED(unrate = "UNRATE", payroll = "PAYEMS")`. Named arguments give
  friendly column names; unnamed arguments keep the (lower-case) ticker
  as the column name.

- **Legacy style**: pass a single (optionally named) character
  vector—e.g.\\ `c(unrate = "UNRATE", payroll = "PAYEMS")`—and/or use
  the `rename_variables=` argument. This remains supported for backward
  compatibility.

If you provide names in `...` *and* a non-`NULL` `rename_variables`
vector, the function stops and prompts you to choose a single naming
method.

## Examples

``` r
if (FALSE) { # \dontrun{
# New interface
getFRED(unrate = "UNRATE", payroll = "PAYEMS")

# Multiple unnamed series (columns become 'unrate' and 'payems')
getFRED("UNRATE", "PAYEMS")

} # }
```
