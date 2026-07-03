#' Create evenly spaced breaks
#'
#' @description Generate a sequence of date breaks for ggplot scales,
#'              taking every `n`th unique date.
#'
#' @param dates A vector of dates.
#' @param n Integer, keep every n-th date (default = 6).
#' @param decreasing Logical, if TRUE (default) sorts dates in descending order.
#'
#' @return A vector of dates suitable for use as ggplot2 axis breaks. With the
#'   default \code{decreasing = TRUE}, the first (most recent) date is always
#'   included, so breaks are anchored to the last observation.
#'
#' @seealso \code{\link{date_breaks_gg}}, which returns a breaks
#'   \emph{function} for \code{scale_x_date()} and clips breaks to the plot
#'   limits.
#' @export
#'
#' @examples
#' library(ggplot2)
#' library(dplyr)
#'
#' df <- tibble(
#'   date = seq.Date(as.Date("2020-01-01"), as.Date("2025-01-01"), by = "month"),
#'   value = rnorm(61)
#' )
#'
#' ggplot(df, aes(date, value)) +
#'   geom_line() +
#'   scale_x_date(breaks = date_breaks_n(df$date, 6))
date_breaks_n <- function(dates, n = 6, decreasing = TRUE) {
  dates <- sort(unique(dates), decreasing = decreasing)
  dates[seq_along(dates) %% n == 1]
}
