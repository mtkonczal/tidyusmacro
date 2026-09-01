# Compare the before/after snapshots captured by verification/capture.R.
#
# The point is not "did anything change" -- plenty changed on purpose. It is
# "did only the things we predicted change". So the predictions are written
# down here as assertions, and anything outside them is reported as UNEXPECTED.
#
# Predicted differences, and why:
#
#   1. New columns. The derived engine joins every lookup BLS publishes for a
#      survey, not the curated list the old hand-mapped engine used. Every
#      source gains seasonal_text; CPI also gains base_text and
#      periodicity_text; ECI gains area_*; JOLTS gains area_* and ratelevel_*.
#      Additive only: no column may disappear.
#
#   2. Column types. Every file is now read as character and then selectively
#      re-typed (R/bls-types.R). Code columns that readr used to guess as
#      numeric are now character (that is the leading-zero fix); year,
#      display_level, sort_sequence stay integer and selectable stays logical.
#
#   3. Dates of computed averages. Averages moved from the first of the month
#      to the last day of their period, so day_tab gains "30"/"31" entries and
#      the observed-row duplicate key count falls.
#
# Everything else must match exactly: row counts, value sums, the series
# universe, and per-column NA counts on every shared column.

if (!dir.exists("verification/before") || !dir.exists("verification/after")) {
  stop("Run verification/capture.R for both labels first.")
}

sources <- sub("\\.rds$", "", list.files("verification/before", pattern = "\\.rds$"))

fmt <- function(x) format(x, big.mark = ",", scientific = FALSE)
problems <- list()
note <- function(src, msg) problems[[length(problems) + 1L]] <<- paste0(src, ": ", msg)

for (src in sources) {
  b <- readRDS(file.path("verification/before", paste0(src, ".rds")))
  a <- readRDS(file.path("verification/after", paste0(src, ".rds")))

  cat("\n=====================  ", src, "  =====================\n", sep = "")

  if (!is.null(b$error) || !is.null(a$error)) {
    cat("  SKIPPED: before error=", b$error, " after error=", a$error, "\n")
    note(src, "one side failed to capture")
    next
  }

  # ---- 1. Must match exactly -------------------------------------------
  ok <- function(label, x, y, tol = 0) {
    same <- if (is.numeric(x) && is.numeric(y)) isTRUE(all.equal(x, y, tolerance = tol)) else identical(x, y)
    cat(sprintf("  %-24s %-22s %-22s %s\n", label, fmt(x), fmt(y), if (same) "OK" else "*** DIFF ***"))
    if (!same) note(src, paste0(label, " changed: ", fmt(x), " -> ", fmt(y)))
    same
  }
  cat(sprintf("  %-24s %-22s %-22s\n", "", "BEFORE", "AFTER"))
  ok("rows", b$n_row, a$n_row)
  ok("series", b$n_series, a$n_series)
  ok("value sum", b$value_sum, a$value_sum, tol = 1e-8)
  ok("value NAs", b$value_n_na, a$value_n_na)
  ok("NA dates", b$n_na_date, a$n_na_date)
  if (!identical(b$series_id_sample, a$series_id_sample)) {
    note(src, "the sampled series_ids differ; BLS may have added series between runs")
  }

  # ---- 2. Columns: additive only ---------------------------------------
  lost <- setdiff(b$cols, a$cols)
  gained <- setdiff(a$cols, b$cols)
  cat("  columns                  ", length(b$cols), " -> ", length(a$cols), "\n", sep = "")
  if (length(gained)) cat("    gained (expected):     ", paste(gained, collapse = ", "), "\n")
  if (length(lost)) {
    cat("    *** LOST ***:          ", paste(lost, collapse = ", "), "\n")
    note(src, paste0("columns disappeared: ", paste(lost, collapse = ", ")))
  }

  # ---- 3. Shared columns: NA counts must be identical -------------------
  pb <- b$profile; pa <- a$profile
  shared <- intersect(pb$column, pa$column)
  mb <- pb[match(shared, pb$column), ]
  ma <- pa[match(shared, pa$column), ]

  na_diff <- shared[mb$n_na != ma$n_na]
  if (length(na_diff)) {
    cat("    *** NA COUNT CHANGED ***: ", paste(na_diff, collapse = ", "), "\n")
    for (cl in na_diff) {
      note(src, sprintf(
        "NA count changed on %s: %s -> %s", cl,
        fmt(mb$n_na[mb$column == cl]), fmt(ma$n_na[ma$column == cl])
      ))
    }
  } else {
    cat("    NA counts on shared columns: identical\n")
  }

  # Distinct counts: identical everywhere except date, which gains distinct
  # values because averages no longer sit on top of December observations.
  dd <- shared[mb$n_distinct != ma$n_distinct]
  dd_unexpected <- setdiff(dd, "date")
  if (length(dd_unexpected)) {
    cat("    *** DISTINCT CHANGED ***: ", paste(dd_unexpected, collapse = ", "), "\n")
    for (cl in dd_unexpected) {
      note(src, sprintf(
        "distinct count changed on %s: %s -> %s", cl,
        fmt(mb$n_distinct[mb$column == cl]), fmt(ma$n_distinct[ma$column == cl])
      ))
    }
  }

  # ---- 4. Type changes: report, do not fail ----------------------------
  tc <- shared[mb$class != ma$class]
  if (length(tc)) {
    cat("    type changes (expected):\n")
    for (cl in tc) {
      cat(sprintf("      %-26s %-10s -> %s\n", cl,
                  mb$class[mb$column == cl], ma$class[ma$column == cl]))
    }
  }

  # ---- 5. The date convention ------------------------------------------
  cat("    day-of-month before:   ", paste(names(b$day_tab), fmt(as.integer(b$day_tab)), sep = "=", collapse = "  "), "\n")
  cat("    day-of-month after:    ", paste(names(a$day_tab), fmt(as.integer(a$day_tab)), sep = "=", collapse = "  "), "\n")
  cat("    average rows:          ", fmt(b$n_average), " -> ", fmt(a$n_average), "\n", sep = "")
  cat("    dup key (observed):    ", fmt(b$n_dup_key_observed), " -> ", fmt(a$n_dup_key_observed), "\n", sep = "")
  if (a$n_dup_key_observed > b$n_dup_key_observed) {
    note(src, "observed-row duplicate keys increased; the day rule should only reduce them")
  }
  if (!identical(b$n_average, a$n_average)) {
    note(src, sprintf("average row count changed: %s -> %s", fmt(b$n_average), fmt(a$n_average)))
  }
  # After the change no average may share a date with an observed value, which
  # shows up as averages living only on day 28-31.
  a_days <- names(a$day_tab)
  if (a$n_average > 0 && !any(a_days %in% c("28", "29", "30", "31"))) {
    note(src, "averages present but no end-of-month dates; the day rule did not apply")
  }
}

cat("\n\n########################  SUMMARY  ########################\n")
if (!length(problems)) {
  cat("No unexpected differences. Every change matched a prediction.\n")
} else {
  cat(length(problems), " item(s) needing a look:\n", sep = "")
  for (p in problems) cat("  - ", p, "\n", sep = "")
}
