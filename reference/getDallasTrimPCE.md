# Build the Dallas Fed trimmed-mean PCE component panel

Returns a long tibble with the raw inputs to the Federal Reserve Bank of
Dallas's trimmed-mean PCE inflation rate: monthly Fisher price index,
nominal expenditure, real quantity, monthly price change, the Fisher
(t-1, t) expenditure-share weight, and a flag indicating whether the
component was trimmed in that month and on which tail. Users can
replicate the trimmed-mean rate by collapsing this tibble to kept
(non-trimmed) components each month and taking the weight-renormalized
weighted mean of price changes.

## Usage

``` r
getDallasTrimPCE(
  frequency = "M",
  NIPA_data = NULL,
  alpha = 0.24,
  beta = 0.31,
  components = NULL
)
```

## Arguments

- frequency:

  Character. Frequency code passed to
  [`getNIPAFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md).
  Defaults to `"M"` (monthly). Currently the trimmed-mean panel is only
  meaningful at monthly frequency.

- NIPA_data:

  Optional pre-loaded NIPA tibble from
  [`getNIPAFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md).
  If `NULL`, the function downloads it.

- alpha:

  Numeric in \[0, 1\]. Lower-tail trim share. Default `0.24`, the Dallas
  Fed published value.

- beta:

  Numeric in \[0, 1\]. Upper-tail trim share. Default `0.31`.

- components:

  Optional override for the component dictionary. Must be a tibble with
  columns `dallas_idx`, `name`, `series_code`, `line_no`. Defaults to
  the packaged
  [`dallasTrimPCEcomponents`](https://www.mikekonczal.com/tidyusmacro/reference/dallasTrimPCEcomponents.md)
  (177 components).

## Value

A `tbl_df` with one row per (date, component) and columns:

- date:

  Month observation date.

- dallas_idx:

  Component ordinal in the Dallas tech notes (1..178, 94 omitted).

- name:

  Dallas Fed component name.

- series_code:

  BEA NIPA series code (Table 2.4.4U).

- line_no:

  BEA NIPA Table 2.4.4U line number.

- price:

  Fisher price index (Table 2.4.4U).

- nominal:

  Current-dollar outlay (Table 2.4.5U).

- quantity:

  Real quantity (`nominal / price`).

- price_change:

  Period-over-period fractional change in `price`. `NA` for the first
  observation per component.

- weight:

  Fisher (t-1, t) expenditure-share weight, renormalized to sum to 1
  within each full-coverage month. `NA` otherwise.

- is_trimmed:

  Logical. `TRUE` if the component is in either tail this month and so
  dropped from the trimmed mean. `NA` when the month lacks full
  coverage.

- trim_side:

  Character. `"lower"` or `"upper"` when trimmed; `NA` when kept
  (interior) or coverage incomplete.

## Details

Weights are Fisher-style: an unweighted average of the expenditure share
evaluated at base prices `P[t-1]` with quantities `Q[t-1]` and `Q[t]`,
renormalized to sum to 1 within each month. Real quantity is computed as
`nominal / price` from BEA NIPA Tables 2.4.5U and 2.4.4U respectively
(equivalent to Table 2.4.6U per the Dallas Fed's MATLAB note, but
available across the full sample without chained-dollar gaps).

Trim assignment is the simple rank-based version: components are sorted
within each month by `price_change`, cumulative weight is accumulated,
and components whose running cumulative weight is below `alpha` are
flagged `"lower"`, while components whose cumulative weight before
adding their own contribution is at or above `1 - beta` are flagged
`"upper"`. Boundary components that straddle either threshold are kept
(treated as interior). The Dallas Fed's exact fractional-boundary
handling enters the rate calculation itself, not this panel-builder; the
resulting headline rate matches the Dallas Fed series to within a few
basis points.

Months without full cross-sectional coverage (i.e., any component
missing this month or last) have `weight`, `is_trimmed`, and `trim_side`
set to `NA`.

## References

Dolmas, J. (2005). "Trimmed Mean PCE Inflation." Federal Reserve Bank of
Dallas Working Paper 0506.

Dolmas, J. (2009, updated 2022-12-23). "PCE Inflation: Technical Note."
Federal Reserve Bank of Dallas.

Atkinson, T., Dolmas, J., & Zarutskie, R. (2026). "Skewness warrants
caution as Trimmed Mean PCE inflation eases." Federal Reserve Bank of
Dallas, April 16, 2026.

## See also

[`dallasTrimPCEcomponents`](https://www.mikekonczal.com/tidyusmacro/reference/dallasTrimPCEcomponents.md),
[`getNIPAFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Default 24/31 Dallas Fed trim
  panel <- getDallasTrimPCE()

  # Replicate the monthly trimmed-mean rate (kept components, renormalized
  # to sum to 1):
  library(dplyr)
  tm_rate <- panel |>
    dplyr::filter(!is_trimmed) |>
    dplyr::group_by(date) |>
    dplyr::summarize(
      rate = sum(price_change * weight) / sum(weight),
      .groups = "drop"
    )

  # What got trimmed in the latest month, by tail and weight:
  panel |>
    dplyr::filter(date == max(date), is_trimmed) |>
    dplyr::arrange(trim_side, dplyr::desc(weight)) |>
    dplyr::select(name, trim_side, weight, price_change)
} # }
```
