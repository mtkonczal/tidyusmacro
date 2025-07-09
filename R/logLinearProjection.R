#' Log-Linear Projection Library
#'
#' This function performs a log-linear projection on a given data frame (or tibble)
#' using a calibration period defined by `start_date` and `end_date`.
#' It fits a log-linear model (`log(value) ~ t`) on the calibration data and then applies
#' the model to all dates on or after `start_date`.
#'
#' @param tbl A data frame or tibble containing the data.
#' @param date_col A character string specifying the column name in `tbl` that contains dates.
#' @param value_col A character string specifying the column name in `tbl` that contains the values to be projected.
#' @param start_date A character string or Date specifying the start date for the calibration period.
#' @param end_date A character string or Date specifying the end date for the calibration period.
#' @param group_col An optional character string specifying a column name in `tbl` to group by before performing projections.
#'
#' @return A numeric vector of projected values, with `NA` for rows where the date is before `start_date`.
#'
#' @import dplyr rlang
#' @importFrom stats lm as.formula predict
#' @export
logLinearProjection <- function(tbl, date_col, value_col, start_date, end_date, group_col = NA) {
  # Convert start_date and end_date to Date objects
  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)

  # Check if required columns exist in tbl
  required_cols <- c(date_col, value_col)
  if (!is.na(group_col)) {
    required_cols <- c(required_cols, group_col)
  }

  if (!all(required_cols %in% colnames(tbl))) {
    stop("One or more specified columns do not exist in 'tbl'.")
  }

  # Ensure the date column is of Date type; if not, convert it
  if (!inherits(tbl[[date_col]], "Date")) {
    tbl[[date_col]] <- as.Date(tbl[[date_col]])
  }

  # Function to apply log-linear projection within each group
  project_group <- function(data) {
    date_sym <- rlang::sym(date_col)
    value_sym <- rlang::sym(value_col)

    # Filter for calibration period
    calib <- data %>%
      dplyr::filter(!!date_sym >= start_date, !!date_sym <= end_date) %>%
      dplyr::mutate(t = as.numeric(!!date_sym - start_date))

    # Fit the log-linear model if there is enough data
    if (nrow(calib) < 2) {
      return(rep(NA_real_, nrow(data)))
    }
    model <- lm(as.formula(paste("log(", value_col, ") ~ t")), data = calib)

    # Compute time variable and initialize projection
    data <- data %>%
      dplyr::mutate(t = as.numeric(!!date_sym - start_date))

    projection <- rep(NA_real_, nrow(data))
    valid_idx <- which(data$t >= 0)

    if (length(valid_idx) > 0) {
      log_preds <- predict(model, newdata = data.frame(t = data$t[valid_idx]))
      projection[valid_idx] <- exp(log_preds)
    }

    return(projection)
  }

  # Apply function with or without grouping
  if (!is.na(group_col)) {
    tbl <- tbl %>%
      dplyr::group_by(!!rlang::sym(group_col)) %>%
      dplyr::mutate(projection = project_group(pick(everything()))) %>%
      dplyr::ungroup()
  } else {
    tbl$projection <- project_group(tbl)
  }

  return(tbl$projection)
}
