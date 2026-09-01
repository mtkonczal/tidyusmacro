# Offline tests for the source registry and its resolver. No network.

test_that("every registry row is complete enough to act on", {
  reg <- bls_registry()
  expect_true(nrow(reg) > 0)
  expect_false(any(duplicated(reg$name)))
  expect_false(any(is.na(reg$prefix)))
  # Current sources must have a default data file; discontinued ones must not,
  # which is what getBLSFiles() keys its "pass file= explicitly" error on.
  cur <- reg[reg$status == "current", ]
  expect_false(any(is.na(cur$file)))
  expect_true(all(is.na(reg$file[reg$status == "discontinued"])))
})

test_that("pinned lookups round-trip through the splitter", {
  spec <- bls_resolve("cpi")
  lk <- bls_registry_lookups(spec)
  expect_type(lk, "character")
  expect_true(all(c("item", "area", "seasonal") %in% lk))
  expect_false(any(grepl("^\\s|\\s$", lk)))
})

test_that("an unpinned source returns NULL, so lookups get discovered live", {
  spec <- bls_resolve("atus")
  expect_null(bls_registry_lookups(spec))
})

test_that("every tier 1 source is pinned, so release day never needs the listing", {
  reg <- bls_registry()
  t1 <- reg[reg$tier == 1 & reg$status == "current", ]
  expect_false(any(is.na(t1$lookups)))
})

test_that("deprecated aliases warn and redirect", {
  expect_warning(spec <- bls_resolve("se"), "deprecated")
  expect_equal(spec$name, "sae")
  expect_warning(spec <- bls_resolve("su"), "deprecated")
  expect_equal(spec$name, "laus")
})

test_that("'su' as a registry name still resolves to chained CPI, not the alias", {
  # The alias table is consulted first, so the real BLS prefix is reached by
  # its registry name rather than by the two-letter prefix.
  spec <- bls_resolve("cpi_chained")
  expect_equal(spec$prefix, "su")
})

test_that("an unknown source suggests near matches instead of dumping the list", {
  expect_error(bls_resolve("ppi_indsutry"), "Did you mean")
  expect_error(bls_resolve("ppi_indsutry"), "ppi_industry")
})

test_that("a source name with different case or padding still resolves", {
  expect_equal(bls_resolve("  CPI ")$name, "cpi")
})

test_that("blsSources filters by tier, status and pattern", {
  expect_true(all(blsSources(tier = 1)$tier == 1))
  expect_true(all(blsSources(status = "discontinued")$status == "discontinued"))
  hits <- blsSources(pattern = "price")
  expect_true(nrow(hits) > 0)
  expect_true(any(grepl("ppi|averageprice|import_export", hits$name)))
})
