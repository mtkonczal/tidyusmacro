# Offline tests for the CPI relative-importance lag construction. The download
# itself is not tested here; these cover the arithmetic that a silent bug would
# hide in: lags borrowed across gaps, and lags borrowed across items.

make_aspect <- function(item, year, period, value, area = "0000") {
  data.frame(
    area_code = area,
    item_code = item,
    year = as.character(year),
    period = period,
    date = as.Date(paste0(year, "-", substr(period, 2, 3), "-01")),
    value_num = value,
    stringsAsFactors = FALSE
  )
}

test_that("weight lags come from the right month", {
  asp <- make_aspect(
    "SA0E",
    c(2020, 2020, 2020, 2021),
    c("M01", "M02", "M03", "M01"),
    c(6.1, 6.2, 6.3, 7.4)
  )
  out <- build_weight_lags(asp)

  expect_equal(nrow(out), 4)
  expect_named(
    out,
    c("area_code", "item_code", "date", "weight", "weight_lag1", "weight_lag12")
  )
  # First month has no predecessor
  expect_true(is.na(out$weight_lag1[out$date == as.Date("2020-01-01")]))
  expect_equal(out$weight_lag1[out$date == as.Date("2020-02-01")], 6.1)
  expect_equal(out$weight_lag1[out$date == as.Date("2020-03-01")], 6.2)
  # Jan 2021 is 12 months after Jan 2020
  expect_equal(out$weight_lag12[out$date == as.Date("2021-01-01")], 6.1)
  # ...and 11 months after Feb 2020, so no 1-month lag exists
  expect_true(is.na(out$weight_lag1[out$date == as.Date("2021-01-01")]))
})

test_that("a gap in the panel yields NA, not the neighboring month", {
  # October 2025 is genuinely missing from CPI: no index was published.
  asp <- make_aspect(
    "SA0",
    c(2025, 2025, 2025),
    c("M08", "M09", "M11"),
    c(100, 100, 100)
  )
  out <- build_weight_lags(asp)
  expect_true(is.na(out$weight_lag1[out$date == as.Date("2025-11-01")]))
  expect_equal(out$weight_lag1[out$date == as.Date("2025-09-01")], 100)
})

test_that("lags do not leak across items or areas", {
  asp <- rbind(
    make_aspect("SAF1", c(2020, 2020), c("M01", "M02"), c(13.1, 13.2)),
    make_aspect("SAH1", c(2020, 2020), c("M01", "M02"), c(33.1, 33.2)),
    make_aspect("SAF1", c(2020, 2020), c("M01", "M02"), c(9.1, 9.2), area = "0100")
  )
  out <- build_weight_lags(asp)

  expect_equal(
    out$weight_lag1[out$item_code == "SAH1" & out$date == as.Date("2020-02-01")],
    33.1
  )
  expect_equal(
    out$weight_lag1[
      out$item_code == "SAF1" &
        out$area_code == "0100" &
        out$date == as.Date("2020-02-01")
    ],
    9.1
  )
  expect_equal(nrow(out), 6)
})

test_that("duplicate area/item/month rows are an error, not a silent fan-out", {
  asp <- make_aspect("SA0", c(2020, 2020), c("M01", "M01"), c(100, 100))
  expect_error(build_weight_lags(asp), "not unique")
})

test_that("getBLSFiles rejects an unknown source before hitting the network", {
  expect_error(getBLSFiles("not_a_source", "test@example.com"), "Invalid data source")
})
