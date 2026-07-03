#' Build the Dallas Fed trimmed-mean PCE component panel
#'
#' Returns a long tibble with the raw inputs to the Federal Reserve Bank of
#' Dallas's trimmed-mean PCE inflation rate: monthly Fisher price index,
#' nominal expenditure, real quantity, monthly price change, the Fisher
#' (t-1, t) expenditure-share weight, and a flag indicating whether the
#' component was trimmed in that month and on which tail. Users can
#' replicate the trimmed-mean rate by collapsing this tibble to kept
#' (non-trimmed) components each month and taking the weight-renormalized
#' weighted mean of price changes.
#'
#' @details
#' Weights are Fisher-style: an unweighted average of the expenditure share
#' evaluated at base prices `P[t-1]` with quantities `Q[t-1]` and `Q[t]`,
#' renormalized to sum to 1 within each month. Real quantity is computed as
#' `nominal / price` from BEA NIPA Tables 2.4.5U and 2.4.4U respectively
#' (equivalent to Table 2.4.6U per the Dallas Fed's MATLAB note, but
#' available across the full sample without chained-dollar gaps).
#'
#' Trim assignment is the simple rank-based version: components are sorted
#' within each month by `price_change`, cumulative weight is accumulated,
#' and components whose running cumulative weight is below `alpha` are
#' flagged `"lower"`, while components whose cumulative weight before
#' adding their own contribution is at or above `1 - beta` are flagged
#' `"upper"`. Boundary components that straddle either threshold are
#' kept (treated as interior). The Dallas Fed's exact fractional-boundary
#' handling enters the rate calculation itself, not this panel-builder;
#' the resulting headline rate matches the Dallas Fed series to within a
#' few basis points.
#'
#' Months without full cross-sectional coverage (i.e., any component
#' missing this month or last) have `weight`, `is_trimmed`, and
#' `trim_side` set to `NA`.
#'
#' @param frequency Character. Frequency code passed to
#'   \code{\link{getNIPAFiles}}. Defaults to \code{"M"} (monthly).
#'   Currently the trimmed-mean panel is only meaningful at monthly
#'   frequency.
#' @param NIPA_data Optional pre-loaded NIPA tibble from
#'   \code{getNIPAFiles()}. If \code{NULL}, the function downloads it.
#' @param alpha Numeric in \[0, 1\]. Lower-tail trim share. Default
#'   \code{0.24}, the Dallas Fed published value.
#' @param beta Numeric in \[0, 1\]. Upper-tail trim share. Default
#'   \code{0.31}.
#' @param components Optional override for the component dictionary. Must
#'   be a tibble with columns \code{dallas_idx}, \code{name},
#'   \code{series_code}, \code{line_no}. Defaults to the packaged
#'   \code{\link{dallasTrimPCEcomponents}} (177 components).
#'
#' @return A \code{tbl_df} with one row per (date, component) and columns:
#' \describe{
#'   \item{date}{Month observation date.}
#'   \item{dallas_idx}{Component ordinal in the Dallas tech notes (1..178, 94 omitted).}
#'   \item{name}{Dallas Fed component name.}
#'   \item{series_code}{BEA NIPA series code (Table 2.4.4U).}
#'   \item{line_no}{BEA NIPA Table 2.4.4U line number.}
#'   \item{price}{Fisher price index (Table 2.4.4U).}
#'   \item{nominal}{Current-dollar outlay (Table 2.4.5U).}
#'   \item{quantity}{Real quantity (\code{nominal / price}).}
#'   \item{price_change}{Period-over-period fractional change in \code{price}. \code{NA} for the first observation per component.}
#'   \item{weight}{Fisher (t-1, t) expenditure-share weight, renormalized to sum to 1 within each full-coverage month. \code{NA} otherwise.}
#'   \item{is_trimmed}{Logical. \code{TRUE} if the component is in either tail this month and so dropped from the trimmed mean. \code{NA} when the month lacks full coverage.}
#'   \item{trim_side}{Character. \code{"lower"} or \code{"upper"} when trimmed; \code{NA} when kept (interior) or coverage incomplete.}
#' }
#'
#' @seealso \code{\link{dallasTrimPCEcomponents}}, \code{\link{getNIPAFiles}}
#'
#' @references
#' Dolmas, J. (2005). "Trimmed Mean PCE Inflation." Federal Reserve Bank
#' of Dallas Working Paper 0506.
#'
#' Dolmas, J. (2009, updated 2022-12-23). "PCE Inflation: Technical
#' Note." Federal Reserve Bank of Dallas.
#'
#' Atkinson, T., Dolmas, J., & Zarutskie, R. (2026). "Skewness warrants
#' caution as Trimmed Mean PCE inflation eases." Federal Reserve Bank of
#' Dallas, April 16, 2026.
#'
#' @importFrom dplyr arrange case_when coalesce filter group_by if_else inner_join lag mutate n pull select summarize transmute ungroup
#' @importFrom rlang .data
#' @importFrom utils data
#'
#' @examples
#' \dontrun{
#'   # Default 24/31 Dallas Fed trim
#'   panel <- getDallasTrimPCE()
#'
#'   # Replicate the monthly trimmed-mean rate (kept components, renormalized
#'   # to sum to 1):
#'   library(dplyr)
#'   tm_rate <- panel |>
#'     dplyr::filter(!is_trimmed) |>
#'     dplyr::group_by(date) |>
#'     dplyr::summarize(
#'       rate = sum(price_change * weight) / sum(weight),
#'       .groups = "drop"
#'     )
#'
#'   # What got trimmed in the latest month, by tail and weight:
#'   panel |>
#'     dplyr::filter(date == max(date), is_trimmed) |>
#'     dplyr::arrange(trim_side, dplyr::desc(weight)) |>
#'     dplyr::select(name, trim_side, weight, price_change)
#' }
#'
#' @export
getDallasTrimPCE <- function(frequency  = "M",
                             NIPA_data  = NULL,
                             alpha      = 0.24,
                             beta       = 0.31,
                             components = NULL) {

  stopifnot(is.numeric(alpha), is.numeric(beta),
            length(alpha) == 1, length(beta) == 1,
            alpha >= 0, beta >= 0, alpha + beta < 1)

  if (is.null(NIPA_data)) {
    NIPA_data <- getNIPAFiles(type = frequency)
  }
  if (is.null(components)) {
    e <- new.env()
    utils::data("dallasTrimPCEcomponents", package = "tidyusmacro", envir = e)
    components <- e$dallasTrimPCEcomponents
  }

  required <- c("dallas_idx", "name", "series_code", "line_no")
  missing  <- setdiff(required, names(components))
  if (length(missing)) {
    stop("`components` is missing required columns: ",
         paste(missing, collapse = ", "))
  }

  # Pull P (U20404) and N (U20405) restricted to the component line numbers,
  # rename to lower-case to match the rest of the panel.
  prices <- NIPA_data |>
    dplyr::filter(.data$TableId == "U20404",
                  .data$LineNo %in% components$line_no) |>
    dplyr::transmute(line_no = .data$LineNo,
                     date    = .data$date,
                     price   = .data$Value)

  noms <- NIPA_data |>
    dplyr::filter(.data$TableId == "U20405",
                  .data$LineNo %in% components$line_no) |>
    dplyr::transmute(line_no = .data$LineNo,
                     date    = .data$date,
                     nominal = .data$Value)

  panel <- prices |>
    dplyr::inner_join(noms, by = c("line_no", "date")) |>
    dplyr::inner_join(components, by = "line_no") |>
    dplyr::mutate(quantity = .data$nominal / .data$price)

  # Surface any component that never appears in the current NIPA pull.
  observed <- sort(unique(panel$line_no))
  expected <- sort(unique(components$line_no))
  if (!identical(observed, expected)) {
    miss <- setdiff(expected, observed)
    warning("Component line numbers missing from NIPA U20404/U20405: ",
            paste(miss, collapse = ", "))
  }

  # Per-component lags (within dallas_idx, ordered by date).
  panel <- panel |>
    dplyr::arrange(.data$dallas_idx, .data$date) |>
    dplyr::group_by(.data$dallas_idx) |>
    dplyr::mutate(
      price_change = .data$price / dplyr::lag(.data$price) - 1,
      P_lag        = dplyr::lag(.data$price),
      Q_lag        = dplyr::lag(.data$quantity)
    ) |>
    dplyr::ungroup()

  # Identify months with full cross-sectional coverage (every component has
  # both this month's and last month's observation). The trimmed-mean rate
  # is defined only on full-coverage months.
  ncomp <- nrow(components)
  full_dates <- panel |>
    dplyr::group_by(.data$date) |>
    dplyr::summarize(
      n_full = sum(!is.na(.data$price_change) &
                   !is.na(.data$P_lag) &
                   !is.na(.data$Q_lag)),
      .groups = "drop"
    ) |>
    dplyr::filter(.data$n_full == ncomp) |>
    dplyr::pull(.data$date)

  # Fisher (t-1, t) weights, renormalized to 1 within each full month.
  panel <- panel |>
    dplyr::mutate(
      .num1 = dplyr::if_else(.data$date %in% full_dates,
                             .data$quantity * .data$P_lag, NA_real_),
      .num2 = dplyr::if_else(.data$date %in% full_dates,
                             .data$Q_lag    * .data$P_lag, NA_real_)
    ) |>
    dplyr::group_by(.data$date) |>
    dplyr::mutate(
      .sum1  = sum(.data$.num1, na.rm = FALSE),
      .sum2  = sum(.data$.num2, na.rm = FALSE),
      weight = 0.5 * .data$.num1 / .data$.sum1 +
               0.5 * .data$.num2 / .data$.sum2
    ) |>
    dplyr::mutate(
      weight = .data$weight / sum(.data$weight, na.rm = FALSE)
    ) |>
    dplyr::ungroup()

  # Trim flags. Sort each month by price_change ascending; cumulative weight
  # determines which components fall in either tail.
  #   - lower : cum_w[i] < alpha           (entirely below the lower cutoff)
  #   - upper : cum_w[i-1] >= 1 - beta     (cumulative weight before this
  #                                         component already past 1-beta)
  panel <- panel |>
    dplyr::group_by(.data$date) |>
    dplyr::arrange(.data$price_change, .by_group = TRUE) |>
    dplyr::mutate(
      .cum_w  = cumsum(dplyr::coalesce(.data$weight, 0)),
      .prev_w = dplyr::lag(.data$.cum_w, default = 0),
      trim_side = dplyr::case_when(
        is.na(.data$weight)             ~ NA_character_,
        .data$.cum_w   <  alpha         ~ "lower",
        .data$.prev_w  >= 1 - beta      ~ "upper",
        TRUE                             ~ NA_character_
      ),
      is_trimmed = dplyr::if_else(is.na(.data$weight),
                                  NA, !is.na(.data$trim_side))
    ) |>
    dplyr::ungroup() |>
    dplyr::arrange(.data$date, .data$dallas_idx) |>
    dplyr::select(.data$date, .data$dallas_idx, .data$name,
                  .data$series_code, .data$line_no,
                  .data$price, .data$nominal, .data$quantity,
                  .data$price_change, .data$weight,
                  .data$is_trimmed, .data$trim_side)

  panel
}
