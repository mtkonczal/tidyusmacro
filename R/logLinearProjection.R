#' Log-Linear Projection (tidy-eval)
#'
#' Fits a log-linear trend \eqn{\log(value) ~ t} on a calibration window and
#' projects it forward for all rows on/after `start_date`. Accepts bare column
#' names for `date`, `value`, and an optional `group`.
#'
#' @param tbl A data frame or tibble.
#' @param date Bare column name for the date variable (coercible to Date).
#' @param value Bare column name for the numeric series to project.
#' @param start_date Date or string coercible to `Date`; start of calibration.
#' @param end_date Date or string coercible to `Date`; end of calibration.
#' @param group Optional bare column name to group by before projecting.
#'
#' @return A numeric vector `projection` with `NA` before `start_date`, aligned
#'   to the rows of `tbl` (and respecting grouping if supplied).
#'
#' @examples
#' # Deterministic, fast example with an upward (log-linear) trend
#' set.seed(123)
#' n <- 16
#' df <- data.frame(
#'   date  = seq(as.Date("2000-01-01"), by = "quarter", length.out = n),
#'   # upward trend on log-scale + small noise; strictly positive
#'   value = exp(log(100) + 0.03 * (0:(n - 1)) + rnorm(n, sd = 0.02))
#' )
#'
#' proj <- logLinearProjection(
#'   df, date, value,
#'   start_date = "2000-01-01",
#'   end_date   = "2003-12-31"
#' )
#' head(proj)
#'
#' @import dplyr rlang
#' @importFrom stats lm predict
#' @export
logLinearProjection <- function(tbl, date, value, start_date, end_date, group = NULL) {
  date_q  <- rlang::enquo(date)
  value_q <- rlang::enquo(value)
  group_q <- rlang::enquo(group)

  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)

  # Normalize inputs: ensure we have Date + numeric working columns
  df <- dplyr::mutate(
    tbl,
    ..date  = as.Date(!!date_q),
    ..value = as.numeric(!!value_q)
  )

  project_one <- function(d) {
    # Calibration window (require positive values for log)
    calib <- d %>%
      dplyr::filter(..date >= start_date, ..date <= end_date) %>%
      dplyr::mutate(t = as.numeric(..date - start_date)) %>%
      dplyr::filter(is.finite(..value), ..value > 0)

    if (nrow(calib) < 2) {
      return(rep(NA_real_, nrow(d)))
    }

    fit <- stats::lm(log(..value) ~ t, data = calib)

    d <- d %>% dplyr::mutate(t = as.numeric(..date - start_date))

    proj <- rep(NA_real_, nrow(d))
    idx  <- which(d$t >= 0)

    if (length(idx) > 0) {
      lp <- stats::predict(fit, newdata = data.frame(t = d$t[idx]))
      proj[idx] <- exp(lp)
    }
    proj
  }

  if (!rlang::quo_is_null(group_q)) {
    df <- df %>%
      dplyr::group_by(!!group_q, .add = FALSE) %>%
      dplyr::mutate(projection = project_one(dplyr::pick(dplyr::everything()))) %>%
      dplyr::ungroup()
  } else {
    df$projection <- project_one(df)
  }

  df$projection
}
