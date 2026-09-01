# Shared BLS period parser, used by getBLSFiles() for every data source.
#
# The bug this replaces: getBLSFiles() used to compute the date as
# substr(period, 2, 3) for every source except ECI (which was special-cased
# to Q01-Q04). BLS period codes are not all monthly -- M13 (annual average),
# S01/S02 (half-year average), S03 (annual average), Q05 (annual average),
# and A01 (annual, the only code CEX ever publishes) all exist. Under the old
# parser, S01/S02/S03 silently became January/February/March and M13 became
# a silent NA. See recommendations.md and BLS_COVERAGE_PLAN.md section 2.1
# for the verified row counts.
#
# Convention: end of period, matching the pre-existing ECI behavior (Q01 ->
# March). Annual and averaged rows land on December of their year. They are
# NOT dropped by default -- see the note on getBLSFiles(include_averages=)
# for why (CEX publishes nothing but A01; dropping "averages" by default
# would silently zero out that entire source).

#' Parse a BLS (year, period) pair into a date, frequency, and average flag
#' @param year Character or integer vector, the BLS `year` column.
#' @param period Character vector, the BLS `period` column (e.g. "M01", "Q01",
#'   "S01", "A01").
#' @return A data frame with `date`, `freq` ("monthly", "quarterly",
#'   "semiannual", or "annual"), and `is_average` (TRUE for M13/S01/S02/S03/
#'   Q05: values BLS computed as an average or aggregate rather than observed
#'   in that period).
#' @noRd
bls_parse_period <- function(year, period) {
  period <- toupper(trimws(as.character(period)))
  year <- suppressWarnings(as.integer(year))

  kind <- substr(period, 1, 1)
  num <- suppressWarnings(as.integer(substr(period, 2, 3)))

  n <- length(period)
  month <- rep(NA_integer_, n)
  freq <- rep(NA_character_, n)
  avg <- rep(FALSE, n)

  set <- function(sel, m, f, is_avg) {
    sel[is.na(sel)] <- FALSE
    month[sel] <<- m
    freq[sel] <<- f
    avg[sel] <<- is_avg
  }

  ok <- !is.na(num)
  monthly <- kind == "M" & ok & num >= 1 & num <= 12
  set(monthly, num[monthly], "monthly", FALSE)
  set(kind == "M" & ok & num == 13, 12L, "annual", TRUE)
  qtr <- kind == "Q" & ok & num >= 1 & num <= 4
  set(qtr, num[qtr] * 3L, "quarterly", FALSE)
  set(kind == "Q" & ok & num == 5, 12L, "annual", TRUE)
  half <- kind == "S" & ok & num >= 1 & num <= 2
  set(half, num[half] * 6L, "semiannual", TRUE)
  set(kind == "S" & ok & num == 3, 12L, "annual", TRUE)
  set(kind == "A" & ok, 12L, "annual", TRUE)

  date <- as.Date(ifelse(
    is.na(month) | is.na(year),
    NA_character_,
    sprintf("%04d-%02d-01", year, month)
  ))

  data.frame(date = date, freq = freq, is_average = avg, stringsAsFactors = FALSE)
}
