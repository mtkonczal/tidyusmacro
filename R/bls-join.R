# Derived-key join engine for BLS lookup tables, used by getBLSFiles() for
# every source added via the registry (see R/bls-registry.R). The 12 sources
# that predate this file keep their original hand-maintained join list in
# getBLSFiles() unchanged, so their output is byte-identical apart from the
# period fix; this engine is what makes adding new sources not require a new
# hardcoded join list per source.
#
# The rule, validated 2026-08-19 against every lookup file in all 65 BLS
# survey directories (see recommendations.md section 4): the join key is
# every column ending in "_code" present in BOTH the lookup file and the
# .series file. That produced a valid key for 474 lookup joins and
# auto-detected 30 compound keys a "{file}_code" rule gets wrong, e.g.
# wp.item = (group_code, item_code) and pc.product = (industry_code,
# product_code).

# Lookups that must never be auto-joined to series:
#   aspect    a separate data file (cu.aspect alone is 31 MB), not a lookup
#   footnote  keys to the data file, and footnote_codes is multi-valued
#   period    superseded by bls_parse_period()
#   the rest are documentation or map artifacts, not lookups
bls_lookup_blocklist <- c(
  "aspect", "footnote", "period", "contacts",
  "areamaps", "map_info", "maperrors", "release",
  "dates", "baseline", "factor_item", "laytitle"
)

# BLS metadata columns that repeat, unchanged, across most lookup files.
# Always prefixed with the lookup's stem so their names are stable across
# sources regardless of which files collide.
bls_metadata_cols <- c("display_level", "selectable", "sort_sequence")

bls_lookup_candidates <- function(files, max_mb = 10) {
  x <- files[!files$is_data, , drop = FALSE]
  stem <- tolower(x$stem)
  keep <- !stem %in% c("series", "txt", bls_lookup_blocklist) &
    !grepl("^(readme|\\.message)$", stem) &
    !grepl("\\.(txt|gif|tar)$", stem) &
    x$bytes <= max_mb * 1e6
  x[keep, , drop = FALSE]
}

# Build the fully-labeled series table: series + every derivable lookup.
bls_build_series <- function(prefix, email, files = NULL, verbose = TRUE) {
  if (is.null(files)) files <- bls_list_files(prefix, email)

  if (verbose) message("Downloading series file...")
  series <- bls_read(prefix, "series", email)
  names(series) <- trimws(names(series))
  series$series_id <- gsub(" ", "", series$series_id)
  for (nm in names(series)) {
    if (is.character(series[[nm]])) series[[nm]] <- trimws(series[[nm]])
  }

  cand <- bls_lookup_candidates(files)

  for (i in seq_len(nrow(cand))) {
    stem <- cand$stem[i]
    tmp <- tryCatch(bls_read(prefix, stem, email), error = function(e) NULL)
    if (is.null(tmp) || !nrow(tmp)) {
      if (verbose) message("  skip ", stem, ": unreadable")
      next
    }
    names(tmp) <- trimws(names(tmp))
    for (nm in names(tmp)) if (is.character(tmp[[nm]])) tmp[[nm]] <- trimws(tmp[[nm]])

    key <- intersect(names(tmp), names(series))
    key <- key[grepl("_code$", key)]

    # Special case, ~39 surveys: the lookup calls it seasonal_code, the
    # series file calls it seasonal. This turns "S"/"U" into readable text.
    if (!length(key) && tolower(stem) == "seasonal") {
      # pr.seasonal capitalizes its columns (Seasonal_code/Seasonal_text)
      # while the other surveys do not; normalize so the output column is
      # always seasonal_text, not Seasonal_text for one survey.
      names(tmp) <- tolower(names(tmp))
      if ("seasonal_code" %in% names(tmp) && "seasonal" %in% names(series)) {
        names(tmp)[names(tmp) == "seasonal_code"] <- "seasonal"
        key <- "seasonal"
      }
    }

    if (!length(key)) {
      if (verbose) message("  skip ", stem, ": no shared key")
      next
    }

    dup <- anyDuplicated(tmp[, key, drop = FALSE])
    if (dup > 0L) {
      warning(
        "Lookup '", prefix, ".", stem, "' is not unique on (",
        paste(key, collapse = ", "), "); skipping to avoid a row fan-out.",
        call. = FALSE
      )
      next
    }

    # Prefix colliding non-key columns so no join ever yields .x/.y.
    collide <- setdiff(intersect(names(tmp), names(series)), key)
    rename <- union(intersect(names(tmp), bls_metadata_cols), collide)
    if (length(rename)) {
      names(tmp)[match(rename, names(tmp))] <- paste0(stem, "_", rename)
    }

    if (verbose) message("  join ", stem, " on (", paste(key, collapse = ", "), ")")
    series <- dplyr::left_join(series, tmp, by = key, relationship = "many-to-one")
  }

  series
}
