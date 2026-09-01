# Capture a comparable snapshot of getBLSFiles() output for the ten sources
# that ran on the legacy join engine, so a before/after diff can confirm the
# engine unification changes only what we predicted it would.
#
# Usage:
#   Rscript verification/capture.R <pkg_path> <label>
#
# <pkg_path> is the package root to devtools::load_all() -- a pristine HEAD
# worktree for the baseline, the working tree for the after. <label> names the
# output directory under verification/.
#
# Deliberately NOT storing the full joined table: ces and sae are hundreds of
# millions of cells. What is stored is chosen to make a broken join impossible
# to miss: per-column NA counts and distinct counts catch a lookup that stopped
# joining or a code column that got mangled, and a fixed series_id sample
# carries actual cell values for eyeball-level comparison.

args <- commandArgs(trailingOnly = TRUE)
pkg_path <- args[[1]]
label <- args[[2]]
email <- "mike@economicsecurityproject.org"

out_dir <- file.path("verification", label)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

suppressMessages(devtools::load_all(pkg_path, quiet = TRUE))

# The ten legacy-engine sources. cex and cps already moved to the derived
# engine in 4dbe766, so they are not part of this comparison.
sources <- c(
  "cpi", "eci", "jolts", "ces", "ces_allemp", "ces_total",
  "averageprice", "food", "sae", "laus"
)

col_profile <- function(df) {
  data.frame(
    column = names(df),
    class = vapply(df, function(x) class(x)[[1]], character(1)),
    n_na = vapply(df, function(x) sum(is.na(x)), integer(1)),
    n_distinct = vapply(df, function(x) length(unique(x)), integer(1)),
    first_vals = vapply(df, function(x) {
      u <- sort(unique(as.character(x[!is.na(x)])))
      paste(utils::head(u, 5), collapse = " | ")
    }, character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

capture_one <- function(src) {
  message("\n========== ", label, ": ", src, " ==========")
  t0 <- Sys.time()
  df <- getBLSFiles(src, email)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  # Fixed, deterministic sample: the first 25 series_ids in sorted order. The
  # ids are stored alongside so a shift in BLS's series list is visible rather
  # than silently changing what is being compared.
  ids <- utils::head(sort(unique(df$series_id)), 25)
  sample_rows <- df[df$series_id %in% ids, , drop = FALSE]
  sample_rows <- sample_rows[order(sample_rows$series_id, sample_rows$date), , drop = FALSE]

  snap <- list(
    source = src,
    label = label,
    n_row = nrow(df),
    n_col = ncol(df),
    cols = names(df),
    profile = col_profile(df),
    value_sum = sum(df$value, na.rm = TRUE),
    value_n_na = sum(is.na(df$value)),
    n_series = length(unique(df$series_id)),
    series_id_sample = ids,
    date_range = range(df$date, na.rm = TRUE),
    n_na_date = sum(is.na(df$date)),
    # Day-of-month distribution: the whole point of the period change. Under
    # the old convention every date is day 01.
    day_tab = table(format(df$date, "%d"), useNA = "ifany"),
    period_tab = if ("period" %in% names(df)) table(df$period, useNA = "ifany") else NULL,
    freq_tab = if ("freq" %in% names(df)) table(df$freq, useNA = "ifany") else NULL,
    n_average = if ("is_average" %in% names(df)) sum(df$is_average) else NA_integer_,
    # Duplicate observed-row key. Averages are excluded because they are
    # expected to collide with each other by design.
    n_dup_key_observed = {
      obs <- if ("is_average" %in% names(df)) df[!df$is_average, , drop = FALSE] else df
      sum(duplicated(obs[, c("series_id", "date")]))
    },
    sample_rows = sample_rows,
    elapsed_sec = elapsed
  )

  saveRDS(snap, file.path(out_dir, paste0(src, ".rds")))
  message(
    "  rows=", format(nrow(df), big.mark = ","),
    " cols=", ncol(df),
    " series=", format(length(unique(df$series_id)), big.mark = ","),
    " value_sum=", format(snap$value_sum, digits = 12),
    " (", round(elapsed), "s)"
  )
  invisible(NULL)
}

for (src in sources) {
  res <- tryCatch(capture_one(src), error = function(e) {
    message("  FAILED: ", conditionMessage(e))
    saveRDS(
      list(source = src, label = label, error = conditionMessage(e)),
      file.path(out_dir, paste0(src, ".rds"))
    )
    NULL
  })
  gc(verbose = FALSE)
}

message("\nDone: ", label)
