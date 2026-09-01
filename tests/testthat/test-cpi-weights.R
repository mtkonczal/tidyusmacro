# Offline tests for the CPI relative-importance weight bases. The download
# itself is not tested here; these cover the arithmetic that a silent bug would
# hide in: the dating convention, and shifts borrowed across gaps or items.

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

# ---------------------------------------------------------------- the shape

test_that("build_weight_bases returns the documented columns", {
  asp <- make_aspect("SA0E", 2020, c("M01", "M02"), c(6.1, 6.2))
  out <- build_weight_bases(asp)

  expect_equal(nrow(out), 2)
  expect_named(
    out,
    c("area_code", "item_code", "date", "weight", "weight_12mo")
  )
})

# ------------------------------------------------------- the dating convention
# This is the block that matters. A cu.aspect row stamped month t holds the RI
# BLS labels month t-1, so `weight` at t is already the base for the t-1 -> t
# change and must NOT be lagged, and the 12-month base is eleven rows back.
#
# The anchor is the June 2026 news release: Tables 6 and 7 both print
# "Relative importance May 2026", and that column equals the 2026-06-01 aspect
# rows for all 307 mappable items exactly (the 2026-05-01 rows match only 43).

test_that("weight is the contemporaneous row, not a lag of it", {
  asp <- make_aspect(
    "SETB01",
    2026,
    c("M04", "M05", "M06"),
    c(3.57, 3.94, 4.254)
  )
  out <- build_weight_bases(asp)

  # Published RI accompanying the June 2026 release for gasoline is 4.254, and
  # it is the weight base for the May -> June change.
  expect_equal(out$weight[out$date == as.Date("2026-06-01")], 4.254)

  # The May row (3.94) is the base for the April -> May change. If it ever shows
  # up as June's weight, someone has reintroduced the off-by-one.
  expect_false(isTRUE(all.equal(
    out$weight[out$date == as.Date("2026-06-01")],
    3.94
  )))
})

test_that("the 12-month base is eleven rows back, not twelve", {
  # RI labeled month m lives in the row dated m+1, so the base for a 12-month
  # change ending June 2026 (i.e. the RI labeled June 2025) is the July 2025 row.
  asp <- rbind(
    make_aspect("SA0E", 2025, c("M06", "M07"), c(6.30, 6.45)),
    make_aspect("SA0E", 2026, "M06", 7.79)
  )
  out <- build_weight_bases(asp)

  expect_equal(out$weight_12mo[out$date == as.Date("2026-06-01")], 6.45)
  expect_false(isTRUE(all.equal(
    out$weight_12mo[out$date == as.Date("2026-06-01")],
    6.30
  )))
})

test_that("the 12-month base is NA when the month eleven back is absent", {
  asp <- rbind(
    make_aspect("SA0E", 2025, "M06", 6.30),
    make_aspect("SA0E", 2026, "M06", 7.79)
  )
  out <- build_weight_bases(asp)

  # Only the t-12 row exists, never the t-11 row. Borrowing it would be the bug.
  expect_true(is.na(out$weight_12mo[out$date == as.Date("2026-06-01")]))
})

# ------------------------------------------------------------ gaps and leaks

test_that("a gap in the panel yields NA, not the neighboring month", {
  # BLS omits rows for intermittently priced items rather than writing NA, so a
  # positional shift would silently reach across the hole.
  asp <- rbind(
    make_aspect("SA0", 2025, c("M06", "M07"), c(100, 100)),
    make_aspect("SA0", 2026, c("M05", "M06"), c(100, 100))
  )
  out <- build_weight_bases(asp)

  # June 2026 needs the July 2025 row: present.
  expect_equal(out$weight_12mo[out$date == as.Date("2026-06-01")], 100)
  # May 2026 needs the June 2025 row: also present.
  expect_equal(out$weight_12mo[out$date == as.Date("2026-05-01")], 100)
  # July 2025 needs an August 2024 row that does not exist.
  expect_true(is.na(out$weight_12mo[out$date == as.Date("2025-07-01")]))
})

test_that("bases do not leak across items or areas", {
  asp <- rbind(
    make_aspect("SAF1", c(2025, 2026), c("M07", "M06"), c(13.1, 13.4)),
    make_aspect("SAH1", c(2025, 2026), c("M07", "M06"), c(35.6, 35.1)),
    make_aspect("SAF1", c(2025, 2026), c("M07", "M06"), c(9.1, 9.2), area = "0100")
  )
  out <- build_weight_bases(asp)

  expect_equal(
    out$weight_12mo[out$item_code == "SAH1" & out$date == as.Date("2026-06-01")],
    35.6
  )
  expect_equal(
    out$weight_12mo[
      out$item_code == "SAF1" &
        out$area_code == "0100" &
        out$date == as.Date("2026-06-01")
    ],
    9.1
  )
  expect_equal(nrow(out), 6)
})

test_that("duplicate area/item/month rows are an error, not a silent fan-out", {
  asp <- make_aspect("SA0", c(2020, 2020), c("M01", "M01"), c(100, 100))
  expect_error(build_weight_bases(asp), "not unique")
})

test_that("getBLSFiles rejects an unknown source before hitting the network", {
  expect_error(getBLSFiles("not_a_source", "test@example.com"), "Unknown BLS source")
})
