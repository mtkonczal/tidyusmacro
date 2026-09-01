# Shared BLS period parser, used by getBLSFiles() and getCPIAspects() for every
# data source.
#
# The bug this replaces: getBLSFiles() used to compute the date as
# substr(period, 2, 3) for every source except ECI (which was special-cased
# to Q01-Q04). BLS period codes are not all monthly: M13 (annual average),
# S01/S02 (half-year average), S03 (annual average), Q05 (annual average),
# and A01 (annual, the only code CEX ever publishes) all exist. Under the old
# parser, S01/S02/S03 silently became January/February/March and M13 became
# a silent NA. See BLS_COVERAGE_PLAN.md section 2.1 for the verified counts.
#
# Convention, in two parts:
#
#   1. MONTH is the end of the period, matching the pre-existing ECI behavior
#      (Q01 -> March). Annual and half-year rows land in the last month they
#      cover: M13/S03/Q05/A01 -> December, S01 -> June, S02 -> December.
#
#   2. DAY separates observed values from BLS-computed averages. An observed
#      value (M01-M12, Q01-Q04) is stamped on the FIRST of its month, matching
#      every other date in this package (getFRED, getNIPAFiles). A computed
#      average (is_average = TRUE) is stamped on the LAST day of its terminal
#      month: 2024-12-31 for M13, 2024-06-30 for S01.
#
# Part 2 exists because month alone cannot separate them. There is no month an
# annual average can occupy that some observed month does not already own, so
# under a uniform day-01 rule the M13 row for 2024 and the real December 2024
# observation are the same Date. That made a stray group_by(date) double-count
# silently. With the day rule, no computed average ever shares a date with an
# observed value, so the mistake is impossible rather than merely documented.
#
# Averages still collide with each OTHER (M13, S02, and S03 all land on
# December 31). That is deliberate: they are all averages, so is_average or
# freq separates them and no observed data is ever contaminated. The full key
# is (series_id, date, freq), not date alone.
#
# Averages are not dropped by default (include_averages = TRUE): CEX publishes
# nothing but A01, so a drop-by-default would silently zero out that source.

#' Parse a BLS (year, period) pair into a date, frequency, and average flag
#' @param year Character or integer vector, the BLS `year` column.
#' @param period Character vector, the BLS `period` column (e.g. "M01", "Q01",
#'   "S01", "A01").
#' @return A data frame with `date`, `freq` ("monthly", "quarterly",
#'   "semiannual", or "annual"), and `is_average` (TRUE for M13/S01/S02/S03/
#'   Q05/A01: values BLS computed as an average or aggregate rather than
#'   observed in that period). Observed rows are dated the first of their
#'   month; averages are dated the last day of their terminal month.
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

  # Dates are built from the DISTINCT (year, month) pairs, then indexed back
  # out, rather than formatted row by row. sprintf() and as.Date() over
  # millions of strings otherwise dominate the entire pipeline: on the 8.3M-row
  # CES file, the row-wise version cost 61 of the 73 seconds the whole
  # getBLSFiles("ces") call took. A survey spans a few hundred year/month
  # combinations at most, so this does ~1000 conversions instead of 8.3M.
  ymd <- function(y, m) {
    # Double arithmetic, not integer: a corrupt year cannot overflow the key.
    key <- y * 100 + m
    u <- unique(key)
    ud <- as.Date(ifelse(
      is.na(u), NA_character_,
      sprintf("%04d-%02d-01", u %/% 100, u %% 100)
    ))
    ud[match(key, u)]
  }

  date <- ymd(year, month)

  # Last day of the terminal month, for the averages: first of the next month
  # minus one day. Computed over the average rows only, which on most sources
  # is a small fraction of the table.
  if (any(avg)) {
    idx <- which(avg)
    m_i <- month[idx]
    y_i <- year[idx]
    date[idx] <- ymd(
      ifelse(m_i == 12L, y_i + 1L, y_i),
      ifelse(m_i == 12L, 1L, m_i + 1L)
    ) - 1L
  }

  data.frame(date = date, freq = freq, is_average = avg, stringsAsFactors = FALSE)
}
