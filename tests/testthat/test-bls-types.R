# Offline tests for bls_retype(), which restores real types after the
# all-character read. The failure this guards against is silent: as character,
# display_level compares lexically, so "10" < "2" is TRUE and a hierarchy
# filter keeps the wrong rows while looking like it worked.

test_that("display_level comes back as an integer, so hierarchy filters sort numerically", {
  df <- data.frame(
    item_display_level = c("0", "2", "10"),
    stringsAsFactors = FALSE
  )
  out <- bls_retype(df, verbose = FALSE)
  expect_type(out$item_display_level, "integer")
  expect_equal(out$item_display_level, c(0L, 2L, 10L))
  # The bug being regression-tested.
  expect_false(all(sort(out$item_display_level) == c(0L, 10L, 2L)))
})

test_that("year, begin_year and end_year become integers", {
  df <- data.frame(
    year = c("2024", "2025"),
    begin_year = c("1947", "1947"),
    end_year = c("2026", "2026"),
    stringsAsFactors = FALSE
  )
  out <- bls_retype(df, verbose = FALSE)
  expect_type(out$year, "integer")
  expect_type(out$begin_year, "integer")
  expect_type(out$end_year, "integer")
})

test_that("selectable becomes logical from BLS's T/F", {
  df <- data.frame(item_selectable = c("T", "F", "T"), stringsAsFactors = FALSE)
  out <- bls_retype(df, verbose = FALSE)
  expect_type(out$item_selectable, "logical")
  expect_equal(out$item_selectable, c(TRUE, FALSE, TRUE))
})

test_that("code columns are never touched, so leading zeros survive", {
  df <- data.frame(
    area_code = c("0000", "0100"),
    item_code = c("SA0", "1E3"),
    series_id = c("CUSR0000SA0", "CUUR0000SA0"),
    stringsAsFactors = FALSE
  )
  out <- bls_retype(df, verbose = FALSE)
  expect_identical(out$area_code, c("0000", "0100"))
  expect_identical(out$item_code, c("SA0", "1E3"))
  expect_identical(out$series_id, df$series_id)
})

test_that("a column that would lose information stays character", {
  # BLS occasionally writes a non-numeric marker. Coercing would turn it into
  # NA, which is worse than leaving the column as text.
  df <- data.frame(
    item_sort_sequence = c("1", "2", "n/a"),
    stringsAsFactors = FALSE
  )
  out <- bls_retype(df, verbose = FALSE)
  expect_type(out$item_sort_sequence, "character")
  expect_identical(out$item_sort_sequence, df$item_sort_sequence)
})

test_that("pre-existing NAs do not block coercion", {
  df <- data.frame(
    area_display_level = c("0", NA, "3"),
    stringsAsFactors = FALSE
  )
  out <- bls_retype(df, verbose = FALSE)
  expect_type(out$area_display_level, "integer")
  expect_equal(out$area_display_level, c(0L, NA, 3L))
})

test_that("non-character columns pass through untouched", {
  df <- data.frame(value = c(1.5, 2.5), date = as.Date(c("2024-01-01", "2024-02-01")))
  out <- bls_retype(df, verbose = FALSE)
  expect_identical(out, df)
})
