# Offline tests for bls_parse_period(), the shared period parser that
# replaced substr(period, 2, 3). See recommendations.md and
# BLS_COVERAGE_PLAN.md section 2.1 for the live-verified bug this fixes:
# S01/S02/S03 silently became January/February/March and M13 became a
# silent NA under the old parser.

test_that("monthly codes map to the matching month, end of period", {
  out <- bls_parse_period(rep(2024, 12), sprintf("M%02d", 1:12))
  expect_equal(out$date, as.Date(sprintf("2024-%02d-01", 1:12)))
  expect_equal(out$freq, rep("monthly", 12))
  expect_false(any(out$is_average))
})

test_that("M13 (annual average) lands on December and is flagged", {
  out <- bls_parse_period(2024, "M13")
  expect_equal(out$date, as.Date("2024-12-01"))
  expect_equal(out$freq, "annual")
  expect_true(out$is_average)
})

test_that("quarterly codes match the pre-existing ECI convention (Q01 -> March)", {
  out <- bls_parse_period(rep(2024, 4), sprintf("Q%02d", 1:4))
  expect_equal(out$date, as.Date(c("2024-03-01", "2024-06-01", "2024-09-01", "2024-12-01")))
  expect_equal(out$freq, rep("quarterly", 4))
  expect_false(any(out$is_average))
})

test_that("Q05 (annual average) lands on December and is flagged", {
  out <- bls_parse_period(2024, "Q05")
  expect_equal(out$date, as.Date("2024-12-01"))
  expect_equal(out$freq, "annual")
  expect_true(out$is_average)
})

test_that("S01/S02 (half-year average) do NOT collide with January/February", {
  out <- bls_parse_period(rep(2024, 2), c("S01", "S02"))
  expect_equal(out$date, as.Date(c("2024-06-01", "2024-12-01")))
  expect_equal(out$freq, rep("semiannual", 2))
  expect_true(all(out$is_average))
  # The bug being regression-tested: the old parser produced Jan/Feb here.
  expect_false(any(out$date %in% as.Date(c("2024-01-01", "2024-02-01"))))
})

test_that("S03 (annual average) lands on December, not March", {
  out <- bls_parse_period(2024, "S03")
  expect_equal(out$date, as.Date("2024-12-01"))
  expect_true(out$is_average)
})

test_that("A01 (the only code CEX publishes) is annual and NOT dropped by is_average alone", {
  out <- bls_parse_period(2024, "A01")
  expect_equal(out$date, as.Date("2024-12-01"))
  expect_equal(out$freq, "annual")
  expect_true(out$is_average)
})

test_that("M13 gets a real date, never a silent NA", {
  out <- bls_parse_period(c(2020, 2021, 2022), c("M13", "M13", "M13"))
  expect_false(any(is.na(out$date)))
})

test_that("an unrecognized period code yields NA rather than a guess", {
  out <- bls_parse_period(2024, "X99")
  expect_true(is.na(out$date))
  expect_true(is.na(out$freq))
  expect_false(out$is_average)
})

test_that("vectorized input preserves order and length", {
  out <- bls_parse_period(
    c(2020, 2020, 2021, 2021),
    c("M01", "M13", "S01", "Q02")
  )
  expect_equal(nrow(out), 4)
  expect_equal(out$is_average, c(FALSE, TRUE, TRUE, FALSE))
})
