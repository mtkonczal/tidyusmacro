# Offline tests for bls_parse_period(), the shared period parser that
# replaced substr(period, 2, 3). See BLS_COVERAGE_PLAN.md section 2.1 for the
# live-verified bug this fixes: S01/S02/S03 silently became January/February/
# March and M13 became a silent NA under the old parser.
#
# The day-of-month rule is the second half of the fix: observed values are
# stamped on the first of their month, BLS-computed averages on the last day of
# their terminal month, so an average can never share a Date with an observed
# value.

test_that("monthly codes map to the matching month, first of the month", {
  out <- bls_parse_period(rep(2024, 12), sprintf("M%02d", 1:12))
  expect_equal(out$date, as.Date(sprintf("2024-%02d-01", 1:12)))
  expect_equal(out$freq, rep("monthly", 12))
  expect_false(any(out$is_average))
})

test_that("M13 (annual average) lands on the last day of December and is flagged", {
  out <- bls_parse_period(2024, "M13")
  expect_equal(out$date, as.Date("2024-12-31"))
  expect_equal(out$freq, "annual")
  expect_true(out$is_average)
})

test_that("quarterly codes match the pre-existing ECI convention (Q01 -> March)", {
  out <- bls_parse_period(rep(2024, 4), sprintf("Q%02d", 1:4))
  expect_equal(out$date, as.Date(c("2024-03-01", "2024-06-01", "2024-09-01", "2024-12-01")))
  expect_equal(out$freq, rep("quarterly", 4))
  expect_false(any(out$is_average))
})

test_that("Q05 (annual average) lands on December 31 and is flagged", {
  out <- bls_parse_period(2024, "Q05")
  expect_equal(out$date, as.Date("2024-12-31"))
  expect_equal(out$freq, "annual")
  expect_true(out$is_average)
})

test_that("S01/S02 (half-year average) do NOT collide with January/February", {
  out <- bls_parse_period(rep(2024, 2), c("S01", "S02"))
  expect_equal(out$date, as.Date(c("2024-06-30", "2024-12-31")))
  expect_equal(out$freq, rep("semiannual", 2))
  expect_true(all(out$is_average))
  # The bug being regression-tested: the old parser produced Jan/Feb here.
  expect_false(any(out$date %in% as.Date(c("2024-01-01", "2024-02-01"))))
})

test_that("S03 (annual average) lands in December, not March", {
  out <- bls_parse_period(2024, "S03")
  expect_equal(out$date, as.Date("2024-12-31"))
  expect_true(out$is_average)
})

test_that("A01 (the only code CEX publishes) is annual and NOT dropped by is_average alone", {
  out <- bls_parse_period(2024, "A01")
  expect_equal(out$date, as.Date("2024-12-31"))
  expect_equal(out$freq, "annual")
  expect_true(out$is_average)
})

test_that("M13 gets a real date, never a silent NA", {
  out <- bls_parse_period(c(2020, 2021, 2022), c("M13", "M13", "M13"))
  expect_false(any(is.na(out$date)))
})

test_that("no computed average ever shares a date with an observed value", {
  # The whole point of the day rule. Every period code CPI publishes, one year.
  codes <- c(sprintf("M%02d", 1:13), sprintf("S%02d", 1:3), sprintf("Q%02d", 1:5))
  out <- bls_parse_period(rep(2024, length(codes)), codes)
  observed <- out$date[!out$is_average]
  averaged <- out$date[out$is_average]
  expect_length(intersect(observed, averaged), 0)
})

test_that("averages land on the correct last day, including a 30-day month", {
  out <- bls_parse_period(rep(2023, 2), c("S01", "S02"))
  expect_equal(out$date, as.Date(c("2023-06-30", "2023-12-31")))
})

test_that("leap years do not shift the December stamp", {
  out <- bls_parse_period(c(2024, 2023), c("M13", "M13"))
  expect_equal(out$date, as.Date(c("2024-12-31", "2023-12-31")))
})

test_that("an unrecognized period code yields NA rather than a guess", {
  out <- bls_parse_period(2024, "X99")
  expect_true(is.na(out$date))
  expect_true(is.na(out$freq))
  expect_false(out$is_average)
})

test_that("an NA period does not corrupt neighbouring rows", {
  out <- bls_parse_period(c(2024, 2024, 2024), c("M01", NA, "M13"))
  expect_equal(out$date, as.Date(c("2024-01-01", NA, "2024-12-31")))
  expect_equal(out$is_average, c(FALSE, FALSE, TRUE))
})

test_that("vectorized input preserves order and length", {
  out <- bls_parse_period(
    c(2020, 2020, 2021, 2021),
    c("M01", "M13", "S01", "Q02")
  )
  expect_equal(nrow(out), 4)
  expect_equal(out$is_average, c(FALSE, TRUE, TRUE, FALSE))
})
