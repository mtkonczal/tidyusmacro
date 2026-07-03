# Tests for getFRED() ---------------------------------------------------
#
# Two layers:
#   1. Offline unit tests that mock the network helper (fred_fetch_csv),
#      so naming, lagging, joining, and failure handling are tested
#      deterministically with no internet.
#   2. A live integration test against fred.stlouisfed.org, skipped on CRAN
#      and when offline. This is the test that catches transport-level
#      breakage (e.g. FRED's HTTP/2 stream resets) and runs identically
#      whether invoked from a terminal (R CMD check, Rscript, devtools::test())
#      or an IDE console (Positron/RStudio: devtools::test() or test_file()).

# A fake FRED CSV result: column names intentionally differ from the final
# output, since getFRED() renames the first two columns positionally.
fake_series <- function(values, start = "2024-01-01") {
  data.frame(
    observation_date = seq(as.Date(start), by = "month", length.out = length(values)),
    VALUE = values
  )
}

# --- Naming ------------------------------------------------------------

test_that("unnamed series use the lowercase ticker as column name", {
  local_mocked_bindings(fred_fetch_csv = function(var) fake_series(1:3))
  df <- suppressMessages(getFRED("UNRATE", "PAYEMS"))

  expect_s3_class(df, "tbl_df")
  expect_named(df, c("date", "unrate", "payems"))
  expect_s3_class(df$date, "Date")
})

test_that("named arguments give friendly column names", {
  local_mocked_bindings(fred_fetch_csv = function(var) fake_series(1:3))
  df <- suppressMessages(getFRED(unrate = "UNRATE", payroll = "PAYEMS"))

  expect_named(df, c("date", "unrate", "payroll"))
})

test_that("legacy character vector and rename_variables still work", {
  local_mocked_bindings(fred_fetch_csv = function(var) fake_series(1:3))

  df1 <- suppressMessages(getFRED(c(u = "UNRATE", p = "PAYEMS")))
  expect_named(df1, c("date", "u", "p"))

  df2 <- suppressMessages(
    getFRED("UNRATE", "PAYEMS", rename_variables = c("u", "p"))
  )
  expect_named(df2, c("date", "u", "p"))
})

test_that("supplying names in ... and rename_variables errors", {
  local_mocked_bindings(fred_fetch_csv = function(var) fake_series(1:3))
  expect_error(
    getFRED(u = "UNRATE", rename_variables = "u2"),
    "only one way to name columns"
  )
})

# --- Transformations ---------------------------------------------------

test_that("lagged = TRUE computes one-period percentage change", {
  local_mocked_bindings(
    fred_fetch_csv = function(var) fake_series(c(100, 110, 121))
  )
  df <- suppressMessages(getFRED("CPIAUCSL", lagged = TRUE))

  expect_equal(df$cpiaucsl, c(NA, 0.1, 0.1), tolerance = 1e-12)
})

test_that("lagged recycles across multiple series", {
  local_mocked_bindings(
    fred_fetch_csv = function(var) fake_series(c(100, 110, 121))
  )
  df <- suppressMessages(getFRED("A1", "A2", lagged = TRUE))

  expect_equal(df$a1, df$a2)
  expect_equal(df$a1, c(NA, 0.1, 0.1), tolerance = 1e-12)
})

# --- Joins -------------------------------------------------------------

test_that("keep_all controls full vs inner join", {
  local_mocked_bindings(fred_fetch_csv = function(var) {
    if (var == "SHORT") fake_series(1:2) else fake_series(1:4)
  })

  full <- suppressMessages(getFRED("SHORT", "LONG"))
  expect_equal(nrow(full), 4)
  expect_equal(sum(is.na(full$short)), 2)

  inner <- suppressMessages(getFRED("SHORT", "LONG", keep_all = FALSE))
  expect_equal(nrow(inner), 2)
  expect_false(anyNA(inner$short))
})

# --- Failure handling --------------------------------------------------

test_that("a failed series warns but the rest still download", {
  local_mocked_bindings(fred_fetch_csv = function(var) {
    if (var == "BAD") stop("HTTP 404 for BAD")
    fake_series(1:3)
  })

  expect_warning(
    df <- suppressMessages(getFRED("GOOD", "BAD")),
    "Error downloading BAD"
  )
  expect_named(df, c("date", "good"))
})

test_that("all series failing raises a clear error", {
  local_mocked_bindings(fred_fetch_csv = function(var) stop("boom"))

  suppressWarnings(
    expect_error(
      suppressMessages(getFRED("BAD1", "BAD2")),
      "No data downloaded successfully"
    )
  )
})

test_that("no arguments raises a clear error", {
  expect_error(getFRED(), "at least one FRED series ID")
})

# --- Live integration (skipped on CRAN / offline) ----------------------

test_that("live: getFRED downloads real series from FRED", {
  skip_on_cran()
  skip_if_offline("fred.stlouisfed.org")

  df <- suppressMessages(getFRED("CPIAUCSL", "UNRATE"))

  expect_named(df, c("date", "cpiaucsl", "unrate"))
  expect_gt(nrow(df), 500) # monthly since 1947/1948
  expect_s3_class(df$date, "Date")
  # "." missings must parse as NA, not flip the column to character
  expect_type(df$cpiaucsl, "double")
  expect_type(df$unrate, "double")
  expect_true(all(diff(df$date) > 0))
  # sanity: unemployment rate in percent, plausible range
  expect_true(all(df$unrate >= 2 & df$unrate <= 15, na.rm = TRUE))
})

test_that("live: getUnrateFRED returns a plausible unemployment rate", {
  skip_on_cran()
  skip_if_offline("fred.stlouisfed.org")

  df <- suppressMessages(getUnrateFRED())

  expect_named(df, c("date", "unemploy_level", "lf_level", "full_unrate"))
  # decimal rate, plausible historical range (~2.5% to ~15%)
  expect_true(all(df$full_unrate > 0.02 & df$full_unrate < 0.16, na.rm = TRUE))
})
