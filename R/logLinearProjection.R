#' Log-Linear Projection (data-masked, dplyr-native)
#'
#' Fits a log-linear trend \code{log(value) ~ t} on a calibration window and
#' projects it for rows on/after \code{start_date}. Designed for use inside
#' dplyr verbs (no need to pass \code{.}).
#'
#' @param date Bare column name for the date variable (coercible to Date).
#' @param value Bare column name for the positive numeric series to project.
#' @param start_date Date or string coercible to Date; start of calibration.
#' @param end_date Date or string coercible to Date; end of calibration.
#' @param group Optional bare column name to group by before projecting.
#' @param data Optional data frame. If omitted, uses the columns visible in
#'   the current data mask (e.g., inside \code{mutate()}) via
#'   \code{dplyr::pick()}.
#'
#' @return A numeric vector \code{projection} aligned to the input rows; \code{NA}
#'   before \code{start_date}. Respects grouping if \code{group} is supplied.
#' @export
#' @importFrom stats lm predict
logLinearProjection <- function(date, value, start_date, end_date, group = NULL, data = NULL) {
  rlang::check_installed(c("dplyr", "rlang"))

  date_q  <- rlang::enquo(date)
  value_q <- rlang::enquo(value)
  group_q <- rlang::enquo(group)

  # Catch calls using the pre-0.2.0 interface, which passed a data frame
  # first: logLinearProjection(tbl, "date_col", "value_col", ...)
  first_arg <- tryCatch(rlang::eval_tidy(date_q), error = function(e) NULL)
  if (is.data.frame(first_arg)) {
    stop(
      "As of tidyusmacro 0.2.0, logLinearProjection() takes bare column ",
      "names and is designed for use inside mutate(): ",
      "mutate(proj = logLinearProjection(date, value, start_date, end_date)). ",
      "The old interface logLinearProjection(tbl, \"date_col\", \"value_col\", ...) ",
      "is no longer supported. See ?logLinearProjection.",
      call. = FALSE
    )
  }

  if (is.null(data)) {
    # pick() replaces the deprecated cur_data_all(), but unlike
    # cur_data_all() it excludes grouping variables in a grouped mutate;
    # bind them back so `group` can still reference a grouping column.
    data <- dplyr::pick(dplyr::everything())
    grp_vals <- dplyr::cur_group()
    if (ncol(grp_vals) > 0) {
      data <- dplyr::bind_cols(
        grp_vals[rep(1, nrow(data)), , drop = FALSE],
        data
      )
    }
  }

  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)

  has_group <- !rlang::quo_is_null(group_q)

  df <- data |>
    dplyr::mutate(
      .row_id = dplyr::row_number(),
      .date   = as.Date(!!date_q),
      .value  = suppressWarnings(as.numeric(!!value_q))
    )

  if (has_group) {
    df <- dplyr::group_by(df, !!group_q, .add = FALSE)
  }

  out <- df |>
    # sort by date within each group (or just by date if ungrouped)
    dplyr::arrange(.date, .by_group = TRUE) |>
    dplyr::mutate(
      .calib = .date >= start_date & .date <= end_date,
      .t     = as.numeric(.date)  # days since epoch
    ) |>
    dplyr::group_modify(function(d, ...) {
      fit_data <- d[d$.calib & is.finite(d$.value) & d$.value > 0, ]
      proj <- rep(NA_real_, nrow(d))

      if (nrow(fit_data) >= 2) {
        fit <- stats::lm(log(.value) ~ .t, data = fit_data)
        idx <- which(d$.date >= start_date)
        if (length(idx)) {
          # column is ".t" with no leading space
          proj[idx] <- exp(stats::predict(fit, newdata = d[idx, c(".t"), drop = FALSE]))
        }
      }

      dplyr::tibble(.row_id = d$.row_id, projection = proj)
    }) |>
    dplyr::ungroup() |>
    dplyr::arrange(.row_id)

  out$projection
}