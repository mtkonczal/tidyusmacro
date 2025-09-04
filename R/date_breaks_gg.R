#' Date breaks anchored to last data month (for ggplot)
#'
#' @description Create a breaks function for \code{scale_x_date()} that
#'   always includes the last actual data month and then selects every
#'   \code{n}th month counting backward.
#'
#' @param n Integer; keep every n-th month counting backward from \code{last}. Default 6.
#' @param last Date; the last (max) date in your data. Required to ensure no break
#'   is placed after your actual data.
#' @param decreasing Logical; if TRUE, return breaks in descending order. Default FALSE.
#'
#' @return A function usable in \code{scale_x_date(breaks = ...)}.
#' @export
#'
#' @examples
#' # Minimal reproducible example (avoid using the name `df`, which masks stats::df)
#' set.seed(1)
#' dat <- data.frame(
#'   date  = seq(as.Date("2023-01-01"), by = "month", length.out = 24),
#'   value = cumsum(rnorm(24))
#' )
#'
#' library(ggplot2)
#'
#' ggplot(dat, aes(date, value)) +
#'   geom_line() +
#'   scale_x_date(
#'     date_labels = "%b\n%Y",
#'     breaks = date_breaks_gg(n = 6, last = max(dat$date))
#'   ) +
#'   labs(x = NULL, y = NULL)
date_breaks_gg <- function(n = 6, last, decreasing = FALSE) {
  if (missing(last) || is.null(last)) {
    stop("date_breaks_gg(): `last` (the last data date) is required.", call. = FALSE)
  }
  if (n <= 0L) stop("date_breaks_gg(): `n` must be a positive integer.", call. = FALSE)

  # snap to month start without extra deps
  month_start <- function(x) as.Date(cut(as.Date(x), "month"))

  last <- month_start(last) # ensure we align to the month
  force(n); force(last); force(decreasing)

  function(limits) {
    # Build monthly candidates from the left limit up to *last* (never beyond)
    start_month <- month_start(limits[1])
    if (last < start_month) start_month <- last

    months <- seq.Date(from = start_month, to = last, by = "month")
    if (length(months) == 0L) return(months)

    k <- length(months)
    # Select indices counting backward from the last element: k, k-n, k-2n, ...
    idx <- seq.int(from = k, to = 1L, by = -n)
    out <- months[sort(idx)]  # ascending by default

    if (decreasing) rev(out) else out
  }
}
