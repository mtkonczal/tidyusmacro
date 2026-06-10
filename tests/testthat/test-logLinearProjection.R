# Deterministic two-group test panel. Group "a" and "b" are exact
# exponentials in calendar days, so a log-linear fit on any window must
# recover them to machine precision; val_noisy adds seeded lognormal noise.
make_test_panel <- function() {
  dates <- seq(as.Date("2014-01-01"), by = "month", length.out = 96)
  df <- dplyr::bind_rows(
    dplyr::tibble(grp = "a", date = dates, val = 100 * exp(0.002 * as.numeric(dates))),
    dplyr::tibble(grp = "b", date = dates, val = 50 * exp(0.001 * as.numeric(dates)))
  )
  set.seed(123)
  df$val_noisy <- df$val * exp(rnorm(nrow(df), 0, 0.005))
  df
}

test_that("logLinearProjection recovers an exact exponential trend", {
  df <- make_test_panel()
  res <- dplyr::mutate(
    df,
    proj = logLinearProjection(date, val, "2015-01-01", "2019-12-01", group = grp)
  )

  # NA before the calibration start: 12 months of 2014 per group
  expect_equal(sum(is.na(res$proj)), 24)
  expect_true(all(is.na(res$proj[res$date < as.Date("2015-01-01")])))

  # Exact recovery on and after start_date, including extrapolation
  # beyond end_date (relative tolerance; levels reach ~1e16)
  keep <- !is.na(res$proj)
  expect_equal(res$proj[keep], res$val[keep], tolerance = 1e-8)
})

test_that("logLinearProjection matches values pinned from version 0.2.0", {
  # Regression pins: computed 2026-06-10 from the deterministic panel
  # above, before the cur_data_all() -> pick() migration. Group "b" only.
  df <- make_test_panel()
  res <- dplyr::mutate(
    df,
    proj  = logLinearProjection(date, val, "2015-01-01", "2019-12-01", group = grp),
    projn = logLinearProjection(date, val_noisy, "2015-01-01", "2019-12-01", group = grp)
  )
  pin_dates <- as.Date(c("2015-01-01", "2020-06-01", "2021-12-01"))
  pins <- res[res$grp == "b" & res$date %in% pin_dates, ]
  expect_equal(pins$proj,
    c(6.8712240355e+08, 4.9667076130e+09, 8.5913610429e+09),
    tolerance = 1e-9
  )
  expect_equal(pins$projn,
    c(6.8625796507e+08, 4.9697634743e+09, 8.6011112959e+09),
    tolerance = 1e-9
  )
})

test_that("standalone data= argument matches the mutate() path", {
  df <- make_test_panel()
  in_mutate <- dplyr::mutate(
    df,
    proj = logLinearProjection(date, val, "2015-01-01", "2019-12-01", group = grp)
  )$proj
  standalone <- logLinearProjection(
    date, val, "2015-01-01", "2019-12-01",
    group = grp, data = df
  )
  expect_identical(standalone, in_mutate)
})

test_that("a grouped mutate works without an explicit group argument", {
  df <- make_test_panel()
  explicit <- dplyr::mutate(
    df,
    proj = logLinearProjection(date, val, "2015-01-01", "2019-12-01", group = grp)
  )$proj
  grouped <- df |>
    dplyr::group_by(grp) |>
    dplyr::mutate(proj = logLinearProjection(date, val, "2015-01-01", "2019-12-01")) |>
    dplyr::ungroup()
  expect_equal(grouped$proj, explicit)
})

test_that("no deprecation warning fires inside mutate()", {
  df <- make_test_panel()
  expect_no_warning(
    dplyr::mutate(
      df,
      proj = logLinearProjection(date, val, "2015-01-01", "2019-12-01", group = grp)
    )
  )
})

test_that("the pre-0.2.0 string interface fails with an informative error", {
  df <- make_test_panel()
  expect_error(
    logLinearProjection(df, "date", "val", "2015-01-01", "2019-12-01"),
    "bare column names"
  )
})
