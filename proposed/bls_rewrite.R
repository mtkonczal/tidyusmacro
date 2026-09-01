# ---------------------------------------------------------------------------
# tidyusmacro: proposed rewrite of the BLS flat-file layer
#
# STATUS: staged proposal. Nothing here is wired into the package. Sourcing
# this file defines new functions alongside the existing `getBLSFiles()`; it
# does not overwrite or mask it.
#
#   source("proposed/bls_rewrite.R")
#   blsSources()
#   blsSources(tier = 1)
#   blsFiles("ppi")
#   ppi <- getBLS("ppi", "you@example.com")
#
# See recommendations.md for why this is one staged file rather than a set of
# edits to R/getBLSFiles.R, and for the sequencing that has to happen first
# (fixture capture -> period fix -> refactor). `bls_capture_fixtures()` at the
# bottom of this file is step 0 of that sequence.
#
# Requires: readr, dplyr, tibble. Same dependency set the package already has.
# ---------------------------------------------------------------------------

# ===========================================================================
# 1. REGISTRY
# ===========================================================================

# One row per named source. `file` is the sensible default data file; every
# other data file in the directory is reachable via getBLS(..., file = ).
#
# `frequency` is ADVISORY METADATA ONLY. Nothing in the parser reads it. Dates
# are derived from the actual BLS period codes in the data, so a wrong value
# here is a documentation bug, not a data bug.
#
# `approx_mb` is the size of the default file as listed by BLS on 2026-08-19.
# It drives the pre-download size warning, nothing else.

bls_registry <- function() {
  r <- function(name, prefix, file, title, frequency, tier, approx_mb,
                status = "current", notes = "") {
    data.frame(
      name = name, prefix = prefix, file = file, title = title,
      frequency = frequency, tier = tier, approx_mb = approx_mb,
      status = status, notes = notes, stringsAsFactors = FALSE
    )
  }

  out <- rbind(
    # --- Tier 1: release-calendar workhorses ------------------------------
    r("cpi",           "cu", "data.0.Current",                  "Consumer Price Index, all urban consumers (CPI-U)", "monthly",   1,  48.9),
    r("cpi_w",         "cw", "data.0.Current",                  "Consumer Price Index, urban wage earners (CPI-W)",   "monthly",   1,  46.7, notes = "Basis for the Social Security COLA."),
    r("cpi_chained",   "su", "data.0.Current",                  "Chained CPI for all urban consumers (C-CPI-U)",      "monthly",   1,   0.4, notes = "BLS prefix 'su'. Do NOT confuse with the deprecated 'su' alias, which meant LAUS."),
    r("ppi",           "wp", "data.0.Current",                  "Producer Price Index, commodity",                    "monthly",   1,  71.6, notes = "wp.item is keyed on (group_code, item_code)."),
    r("ppi_industry",  "pc", "data.0.Current",                  "Producer Price Index, industry and product",         "monthly",   1,  64.3, notes = "pc.product is keyed on (industry_code, product_code)."),
    r("import_export", "ei", "data.0.Current",                  "Import and export price indexes",                    "monthly",   1,  11.7),
    r("avgprice",      "ap", "data.0.Current",                  "Average price data",                                 "monthly",   1,   8.9),
    r("food",          "ap", "data.3.Food",                     "Average price data, food items",                     "monthly",   1,   3.5),
    r("ces",           "ce", "data.0.AllCESSeries",             "Current Employment Statistics, national",            "monthly",   1, 350.2),
    r("ces_allemp",    "ce", "data.01a.CurrentSeasAE",          "CES all employees, seasonally adjusted",             "monthly",   1,   6.0),
    r("ces_total",     "ce", "data.00a.TotalNonfarm.Employment","CES total nonfarm employment",                       "monthly",   1,   0.5),
    r("cps",           "ln", "data.1.AllData",                  "Current Population Survey, labor force statistics",  "monthly",   1, 389.7),
    r("jolts",         "jt", "data.1.AllItems",                 "Job Openings and Labor Turnover Survey",             "monthly",   1,  34.4),
    r("eci",           "ci", "data.1.AllData",                  "Employment Cost Index",                              "quarterly", 1,   8.6),
    r("ecec",          "cm", "data.1.AllData",                  "Employer Costs for Employee Compensation",           "quarterly", 1,  26.3),
    r("productivity",  "pr", "data.1.AllData",                  "Major sector productivity and costs",                "quarterly", 1,   3.2, notes = "Unit labor costs live here."),
    r("laus",          "la", "data.1.CurrentS",                 "Local Area Unemployment Statistics",                 "monthly",   1,  50.0, notes = "Was reachable as 'su', which was a misnomer."),
    r("sae",           "sm", "data.0.Current",                  "State and Area Employment, Hours, and Earnings",     "monthly",   1, 329.5, notes = "Was reachable as 'se'."),

    # --- Tier 2: annual and structural ------------------------------------
    r("oews",             "oe", "data.1.AllData", "Occupational Employment and Wage Statistics", "annual",    2, 331.5),
    r("bed",              "bd", "data.1.AllItems","Business Employment Dynamics",                "quarterly", 2, 253.5),
    r("cex",              "cx", "data.1.AllData", "Consumer Expenditure Survey",                 "annual",    2, 120.8),
    r("cps_earnings",     "le", "data.1.AllData", "CPS earnings",                                "quarterly", 2,  10.5),
    r("cps_union",        "lu", "data.1.AllData", "CPS union membership",                        "annual",    2,   1.4),
    r("ind_productivity", "ip", "data.1.AllData", "Industry productivity",                       "annual",    2,  41.4),

    # --- Tier 3: specialist -----------------------------------------------
    r("tfp",                 "mp", "data.1.AllData", "Major sector total factor productivity",       "annual", 3,    7.4),
    r("cps_family",          "fm", "data.1.AllData", "CPS marital and family labor force statistics","annual", 3,    1.6),
    r("cps_veterans",        "kv", "data.1.AllData", "CPS veterans supplement",                      "annual", 3,    1.2),
    r("atus",                "tu", "data.1.AllData", "American Time Use Survey",                     "annual", 3,  110.3),
    r("ncs_benefits",        "nb", "data.1.AllData", "National Compensation Survey, benefits",       "annual", 3,   42.3),
    r("ors",                 "or", "data.1.AllData", "Occupational Requirements Survey",             "annual", 3,    3.4),
    r("work_stoppages",      "ws", "data.1.AllData", "Work stoppages",                               "annual", 3,    0.2),
    r("emp_projections",     "ep", "data.1.AllData", "Employment projections",                       "annual", 3,    6.2),
    r("cfoi",                "fa", "data.1.AllData", "Census of Fatal Occupational Injuries",        "annual", 3,   35.1),
    r("osh_industry",        "is", "data.1.AllData", "Occupational injuries and illnesses, industry","annual", 3,  241.2),
    r("osh_characteristics", "ca", "data.1.AllData", "Occupational injuries and illnesses, case characteristics", "annual", 3, 2885.9,
      notes = "2.9 GB. Confirm before downloading.")
  )

  # --- Tier 4: discontinued. Registered so they are discoverable, not usable
  # without opting in. Last data update per the BLS listing on 2026-08-19.
  disc <- data.frame(
    prefix = c("bg","bp","cb","cc","cd","cf","ch","cs","ec","ee","eb","fi","fw",
               "gg","gp","hc","hs","ii","in","jl","li","ml","mu","mw","nc","nd",
               "nw","pd","sa","sh","si","wd","wm"),
    title = c("Collective bargaining, state and local government",
              "Collective bargaining, private sector",
              "Occupational injuries and illnesses, characteristics",
              "Employer costs for employee compensation (superseded by ecec)",
              "Occupational injuries and illnesses, characteristics",
              "Census of fatal occupational injuries, 1992-2002",
              "Occupational injuries and illnesses, characteristics",
              "Occupational injuries and illnesses, characteristics",
              "Employment Cost Index, historical (superseded by eci)",
              "CES national, historical files (superseded by ces)",
              "Employee Benefits Survey",
              "Census of fatal occupational injuries",
              "Census of fatal occupational injuries",
              "Green Goods and Services", "Geographic Profile",
              "Occupational injuries and illnesses, characteristics",
              "Occupational injuries and illnesses, incidence rates",
              "Occupational injuries and illnesses, industry",
              "International labor statistics",
              "JOLTS, historical (superseded by jolts)",
              "Department Store Inventory Price Index",
              "Mass Layoff Statistics",
              "CPI-U, discontinued areas", "CPI-W, discontinued areas",
              "National Compensation Survey",
              "PPI industry, discontinued series",
              "National Compensation Survey, wages",
              "PPI industry, SIC basis", "State and area employment, historical",
              "Occupational injuries and illnesses, incidence rates",
              "Occupational injuries and illnesses, incidence rates",
              "PPI commodity, discontinued series", "Modeled Wage Estimates"),
    last_update = c("1995-09-18","1996-02-16","2023-12-01","2004-02-26","2003-04-09",
                    "2004-10-28","2012-01-09","2023-04-06","2006-05-10","2003-05-16",
                    "2006-09-13","2012-04-25","2024-01-25","2013-03-19","2000-02-04",
                    "2004-03-26","1996-11-26","2014-12-18","2013-08-21","2003-08-08",
                    "2016-07-15","2013-06-21","2010-02-23","2010-02-23","2006-08-31",
                    "2026-08-13","2011-08-04","2005-04-19","2003-01-28","2002-12-19",
                    "2003-12-18","2026-08-13","2024-08-22"),
    stringsAsFactors = FALSE
  )
  disc_rows <- data.frame(
    name = disc$prefix, prefix = disc$prefix, file = NA_character_,
    title = disc$title, frequency = NA_character_, tier = 4L,
    approx_mb = NA_real_, status = "discontinued",
    notes = paste0("Last data update ", disc$last_update,
                   ". No lookup handling; pass file= explicitly to fetch raw."),
    stringsAsFactors = FALSE
  )

  out <- rbind(out, disc_rows)
  out$url <- paste0("https://download.bls.gov/pub/time.series/", out$prefix, "/")
  out$tier <- as.integer(out$tier)
  out[order(out$tier, out$name), ]
}

# Deprecated aliases. See recommendations.md section on the name collision:
# 'su' is a real BLS prefix (chained CPI) that the old alias was squatting on.
bls_deprecated_aliases <- c(se = "sae", su = "laus")

#' List available BLS sources
#' @param tier Optional integer vector; 1 = release workhorses, 4 = discontinued.
#' @param status "current", "discontinued", or NULL for both.
#' @param pattern Optional regex matched against name and title.
blsSources <- function(tier = NULL, status = "current", pattern = NULL) {
  x <- bls_registry()
  if (!is.null(tier))    x <- x[x$tier %in% tier, , drop = FALSE]
  if (!is.null(status))  x <- x[x$status %in% status, , drop = FALSE]
  if (!is.null(pattern)) {
    hit <- grepl(pattern, x$name, ignore.case = TRUE) |
           grepl(pattern, x$title, ignore.case = TRUE)
    x <- x[hit, , drop = FALSE]
  }
  rownames(x) <- NULL
  tibble::as_tibble(x)
}

# ===========================================================================
# 2. FETCH LAYER
# ===========================================================================

bls_base_url <- "https://download.bls.gov/pub/time.series/"

# Resolve a user-facing name to a registry row, with fuzzy suggestions on miss.
bls_resolve <- function(source) {
  source <- tolower(trimws(source))
  reg <- bls_registry()

  if (source %in% names(bls_deprecated_aliases)) {
    new <- bls_deprecated_aliases[[source]]
    warning("Source '", source, "' is deprecated and will be removed. Use '",
            new, "'. Note that 'su' is a real BLS prefix for the chained CPI, ",
            "reachable as 'cpi_chained'.", call. = FALSE)
    source <- new
  }

  hit <- reg[reg$name == source, , drop = FALSE]
  if (nrow(hit) == 1L) return(as.list(hit))

  d <- utils::adist(source, reg$name, ignore.case = TRUE)[1, ]
  near <- reg$name[order(d)][seq_len(min(5L, nrow(reg)))]
  near <- near[d[order(d)][seq_len(length(near))] <= 6]
  stop("Unknown BLS source '", source, "'.",
       if (length(near)) paste0(" Did you mean: ", paste(near, collapse = ", "), "?") else "",
       " Call blsSources() for the full list.", call. = FALSE)
}

bls_with_agent <- function(email, expr) {
  old <- options(HTTPUserAgent = email)
  on.exit(options(old), add = TRUE)
  force(expr)
}

# Read one BLS tab-delimited file. All columns come back character; typing is
# the caller's job, so a stray code like "0000" never loses its leading zeros.
bls_read <- function(prefix, file, email, show_progress = FALSE) {
  url <- paste0(bls_base_url, prefix, "/", prefix, ".", file)
  bls_with_agent(email, {
    readr::read_tsv(url,
                    col_types = readr::cols(.default = readr::col_character()),
                    progress = show_progress)
  })
}

# Parse the BLS directory listing. Returns file name, byte size, and the
# remote mtime, which is the exact cache key recommended in the plan.
bls_list_files <- function(prefix, email) {
  url <- paste0(bls_base_url, prefix, "/")
  txt <- bls_with_agent(email, paste(readLines(url, warn = FALSE), collapse = "\n"))
  txt <- gsub("<br>", "\n", txt, fixed = TRUE)

  rx <- "(\\d+)/(\\d+)/(\\d{4})\\s+(\\d+):(\\d+)\\s+(AM|PM)\\s+(\\d+) <A HREF=\"[^\"]*\">([^<]+)</A>"
  m <- regmatches(txt, gregexpr(rx, txt, perl = TRUE))[[1]]
  if (!length(m)) stop("Could not parse the BLS directory listing for '", prefix, "'.", call. = FALSE)
  g <- regmatches(m, regexec(rx, m, perl = TRUE))

  # regexec puts the whole match at [[1]], so capture group n is at [[n + 1]].
  pick <- function(i) vapply(g, function(x) x[[i + 1L]], character(1))
  hour <- as.integer(pick(4)); ampm <- pick(6)
  hour <- ifelse(ampm == "PM" & hour < 12, hour + 12, ifelse(ampm == "AM" & hour == 12, 0, hour))

  out <- data.frame(
    file     = pick(8),
    bytes    = as.numeric(pick(7)),
    modified = as.POSIXct(sprintf("%04d-%02d-%02d %02d:%02d:00",
                                  as.integer(pick(3)), as.integer(pick(1)),
                                  as.integer(pick(2)), hour, as.integer(pick(5))),
                          tz = "UTC"),
    stringsAsFactors = FALSE
  )
  out$is_data <- grepl("\\.data\\.", out$file, ignore.case = TRUE)
  # Strip the "{prefix}." stem so it can be passed straight to file=.
  out$stem <- sub(paste0("^", prefix, "\\."), "", out$file, ignore.case = TRUE)
  out[order(!out$is_data, out$file), ]
}

#' List every file BLS publishes for a source
#' @param source A registry name or a bare two-letter BLS prefix.
blsFiles <- function(source, email, data_only = TRUE) {
  prefix <- tryCatch(bls_resolve(source)$prefix, error = function(e) {
    if (nchar(source) == 2L) source else stop(e)
  })
  x <- bls_list_files(prefix, email)
  if (data_only) x <- x[x$is_data, , drop = FALSE]
  x$mb <- round(x$bytes / 1e6, 2)
  rownames(x) <- NULL
  tibble::as_tibble(x[, c("stem", "mb", "modified", "file")])
}

# ===========================================================================
# 3. PERIOD PARSER
# ===========================================================================
#
# The bug this replaces: the old code did substr(period, 2, 3) for every
# source except ECI, so S01 became January, S02 became February, and M13/S03
# became a silent NA. In cu.data.1.AllItems that mis-stamps 16,535 of 63,945
# rows and collides half-year rows with real January and February rows.
#
# Convention: END of period, matching the existing ECI behavior where Q01
# maps to March. Annual and annual-average rows land on December of their
# year and are flagged, so they can be filtered rather than silently dropped.
#
#   M01-M12  monthly
#   M13      annual average        -> Dec, is_average
#   Q01-Q04  quarterly             -> Mar/Jun/Sep/Dec
#   Q05      annual average        -> Dec, is_average
#   S01-S02  semiannual averages   -> Jun/Dec, is_average
#   S03      annual average        -> Dec, is_average
#   A01      annual                -> Dec, is_average
#
# S01/S02 are flagged as averages because that is what they are: BLS labels
# them HALF1 and HALF2, six-month averages, not distinct observations.

bls_parse_period <- function(year, period) {
  period <- toupper(trimws(as.character(period)))
  year   <- suppressWarnings(as.integer(year))

  kind <- substr(period, 1, 1)
  num  <- suppressWarnings(as.integer(substr(period, 2, 3)))

  n     <- length(period)
  month <- rep(NA_integer_, n)
  freq  <- rep(NA_character_, n)
  avg   <- rep(FALSE, n)

  set <- function(sel, m, f, is_avg) {
    sel[is.na(sel)] <- FALSE
    month[sel] <<- m; freq[sel] <<- f; avg[sel] <<- is_avg
  }

  ok <- !is.na(num)
  set(kind == "M" & ok & num >= 1 & num <= 12, num[kind == "M" & ok & num >= 1 & num <= 12], "monthly", FALSE)
  set(kind == "M" & ok & num == 13, 12L, "annual", TRUE)
  qtr <- kind == "Q" & ok & num >= 1 & num <= 4
  set(qtr, num[qtr] * 3L, "quarterly", FALSE)
  set(kind == "Q" & ok & num == 5, 12L, "annual", TRUE)
  half <- kind == "S" & ok & num >= 1 & num <= 2
  set(half, num[half] * 6L, "semiannual", TRUE)
  set(kind == "S" & ok & num == 3, 12L, "annual", TRUE)
  set(kind == "A" & ok, 12L, "annual", TRUE)

  date <- as.Date(ifelse(is.na(month) | is.na(year), NA_character_,
                         sprintf("%04d-%02d-01", year, month)))

  data.frame(date = date, freq = freq, is_average = avg, stringsAsFactors = FALSE)
}

# ===========================================================================
# 4. JOIN ENGINE
# ===========================================================================
#
# The rule, validated on 2026-08-19 against every lookup file in all 65 BLS
# survey directories: the join key is every column ending in "_code" present
# in BOTH the lookup file and the .series file. That produced a valid key for
# 474 lookup joins and auto-detected 30 compound keys, including
# wp.item = (group_code, item_code) and pc.product = (industry_code,
# product_code), which a "{file}_code" rule gets wrong.

# Lookups that must never be auto-joined to series.
#   aspect   separate data file, and cu.aspect alone is 31 MB
#   footnote keys to the data file, and footnote_codes is multi-valued
#   period   superseded by bls_parse_period()
#   the rest are documentation or map artifacts, not lookups
bls_lookup_blocklist <- c("aspect", "footnote", "period", "contacts",
                          "areamaps", "map_info", "maperrors", "release",
                          "dates", "baseline", "factor_item", "laytitle")

bls_metadata_cols <- c("display_level", "selectable", "sort_sequence")

bls_lookup_candidates <- function(files, prefix, max_mb = 10) {
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
  # Lookup code columns carry leading zeros and stray whitespace in both files.
  for (nm in names(series)) if (is.character(series[[nm]])) series[[nm]] <- trimws(series[[nm]])

  cand <- bls_lookup_candidates(files, prefix)

  for (i in seq_len(nrow(cand))) {
    stem <- cand$stem[i]
    tmp <- tryCatch(bls_read(prefix, stem, email), error = function(e) NULL)
    if (is.null(tmp) || !nrow(tmp)) { if (verbose) message("  skip ", stem, ": unreadable"); next }
    names(tmp) <- trimws(names(tmp))
    for (nm in names(tmp)) if (is.character(tmp[[nm]])) tmp[[nm]] <- trimws(tmp[[nm]])

    key <- intersect(names(tmp), names(series))
    key <- key[grepl("_code$", key)]

    # Special case, 39 surveys: the lookup calls it seasonal_code, the series
    # file calls it seasonal. This is the join that turns "S"/"U" into text.
    if (!length(key) && tolower(stem) == "seasonal") {
      # pr.seasonal capitalizes its columns (Seasonal_code / Seasonal_text)
      # while the other 39 surveys do not. Normalize so the output column is
      # seasonal_text everywhere, not Seasonal_text for one survey.
      names(tmp) <- tolower(names(tmp))
      if ("seasonal_code" %in% names(tmp) && "seasonal" %in% names(series)) {
        names(tmp)[names(tmp) == "seasonal_code"] <- "seasonal"
        key <- "seasonal"
      }
    }

    if (!length(key)) { if (verbose) message("  skip ", stem, ": no shared key"); next }

    dup <- anyDuplicated(tmp[, key, drop = FALSE])
    if (dup > 0L) {
      warning("Lookup '", prefix, ".", stem, "' is not unique on (",
              paste(key, collapse = ", "), "); skipping to avoid a row fan-out.",
              call. = FALSE)
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

# ===========================================================================
# 5. TOP-LEVEL
# ===========================================================================

#' Download and tidy a BLS flat-file data source
#'
#' @param source Registry name, see blsSources().
#' @param email Contact email, required by BLS in the user agent.
#' @param file Optional data file stem, e.g. "data.21.Aggregates". Defaults to
#'   the registry's choice. See blsFiles(source, email) for what exists.
#' @param include_averages Keep annual-average and half-year rows. FALSE by
#'   default because those rows share a date with December and would double
#'   count in any group_by(date).
#' @param lookups Join the auxiliary label tables. FALSE returns series
#'   metadata only, which is much faster.
#' @param max_mb Refuse to download a data file larger than this without an
#'   explicit override. Set Inf to disable.
getBLS <- function(source, email, file = NULL, include_averages = FALSE,
                   lookups = TRUE, max_mb = 500, verbose = TRUE) {
  spec <- bls_resolve(source)
  prefix <- spec$prefix

  if (spec$status == "discontinued" && is.null(file)) {
    stop("Source '", spec$name, "' is discontinued (", spec$notes,
         ") and has no default file. Pass file= explicitly, or call blsFiles('",
         prefix, "', email) to see what is there.", call. = FALSE)
  }
  if (is.null(file)) file <- spec$file

  listing <- bls_list_files(prefix, email)
  target <- listing[listing$stem == file, , drop = FALSE]
  if (!nrow(target)) {
    stop("File '", prefix, ".", file, "' does not exist. Call blsFiles('",
         spec$name, "', email) to list the ", sum(listing$is_data),
         " data files in this survey.", call. = FALSE)
  }
  mb <- target$bytes[1] / 1e6
  if (mb > max_mb) {
    stop("'", prefix, ".", file, "' is ", round(mb, 1), " MB, over the ", max_mb,
         " MB limit. Re-call with max_mb = ", ceiling(mb), " to proceed.", call. = FALSE)
  }
  if (verbose) message("Downloading ", prefix, ".", file, " (", round(mb, 1), " MB)...")

  main <- bls_read(prefix, file, email, show_progress = verbose)
  names(main) <- trimws(names(main))
  main$series_id <- gsub(" ", "", main$series_id)
  main$value <- suppressWarnings(as.numeric(main$value))

  per <- bls_parse_period(main$year, main$period)
  main$date <- per$date
  main$freq <- per$freq
  main$is_average <- per$is_average

  bad <- is.na(main$date)
  if (any(bad)) {
    warning(sum(bad), " row(s) have an unrecognized period code (",
            paste(unique(main$period[bad])[1:min(5, sum(bad))], collapse = ", "),
            ") and were given NA dates.", call. = FALSE)
  }
  if (!include_averages) {
    n0 <- nrow(main)
    main <- main[!main$is_average, , drop = FALSE]
    if (verbose && n0 > nrow(main)) {
      message("Dropped ", format(n0 - nrow(main), big.mark = ","),
              " annual-average / half-year row(s). Pass include_averages = TRUE to keep them.")
    }
  }

  if (isTRUE(lookups)) {
    series <- bls_build_series(prefix, email, files = listing, verbose = verbose)
    # Keep the observation-level version of any shared column: a footnote on
    # the observation beats a footnote on the series definition.
    shared <- setdiff(intersect(names(main), names(series)), "series_id")
    if (length(shared)) series <- series[, !names(series) %in% shared, drop = FALSE]
    if (verbose) message("Merging main data with series metadata...")
    main <- dplyr::left_join(main, series, by = "series_id", relationship = "many-to-one")
  }

  suffixed <- grep("\\.[xy]$", names(main), value = TRUE)
  if (length(suffixed)) {
    stop("Internal error: duplicated columns after merge (",
         paste(suffixed, collapse = ", "), ").", call. = FALSE)
  }

  tibble::as_tibble(main)
}

# ===========================================================================
# 6. STEP 0: FIXTURE CAPTURE
# ===========================================================================
#
# Run this BEFORE changing anything in R/getBLSFiles.R. It snapshots the
# current output of every source the released function supports, which is the
# regression net that does not exist today (test-cpi-weights.R has 8 tests, 7
# of which cover build_weight_bases(); exactly 1 touches getBLSFiles(), and it
# only asserts that a bad string errors).
#
# Sequence, per recommendations.md:
#   1. bls_capture_fixtures(email, "fixtures/before")     <- current behavior
#   2. apply the period fix ONLY, commit, re-capture to fixtures/period-fixed
#      and eyeball that diff: it should be entirely S01/S02/M13/S03 rows
#   3. refactor onto this file, capture to fixtures/after, diff against
#      fixtures/period-fixed. That diff should be empty.
#
# Storing summaries rather than full data: the raw files are gigabytes, and
# what a refactor breaks is shape, not bytes.

bls_capture_fixtures <- function(email, dir = "fixtures/before",
                                 sources = c("cpi","eci","jolts","cps","ces",
                                             "cex","averageprice","food",
                                             "ces_allemp","ces_total","se","su"),
                                 fn = getBLSFiles) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  for (s in sources) {
    message("=== ", s, " ===")
    out <- tryCatch(fn(s, email), error = function(e) e)
    if (inherits(out, "error")) {
      saveRDS(list(source = s, error = conditionMessage(out)),
              file.path(dir, paste0(s, ".rds")))
      next
    }
    snap <- list(
      source     = s,
      captured   = Sys.time(),
      n_row      = nrow(out),
      n_col      = ncol(out),
      cols       = names(out),
      col_types  = vapply(out, function(x) class(x)[1], character(1)),
      n_na_date  = if ("date" %in% names(out)) sum(is.na(out$date)) else NA_integer_,
      date_range = if ("date" %in% names(out)) range(out$date, na.rm = TRUE) else NULL,
      period_tab = if ("period" %in% names(out)) table(out$period) else NULL,
      # Duplicate series_id/date pairs are exactly what the S01 bug creates.
      n_dup_key  = if (all(c("series_id","date") %in% names(out)))
                     sum(duplicated(out[, c("series_id","date")])) else NA_integer_,
      value_sum  = if ("value" %in% names(out)) sum(out$value, na.rm = TRUE) else NA_real_,
      head_50    = utils::head(out, 50)
    )
    saveRDS(snap, file.path(dir, paste0(s, ".rds")))
    message("  ", snap$n_row, " rows x ", snap$n_col, " cols; ",
            snap$n_dup_key, " duplicate series_id/date pairs")
  }
  invisible(dir)
}

# Compare two fixture directories. Returns one row per source.
bls_diff_fixtures <- function(before = "fixtures/before", after = "fixtures/after") {
  fs <- intersect(list.files(before, "\\.rds$"), list.files(after, "\\.rds$"))
  do.call(rbind, lapply(fs, function(f) {
    a <- readRDS(file.path(before, f)); b <- readRDS(file.path(after, f))
    data.frame(
      source      = sub("\\.rds$", "", f),
      rows_before = a$n_row %||% NA, rows_after = b$n_row %||% NA,
      cols_gained = paste(setdiff(b$cols, a$cols), collapse = ", "),
      cols_lost   = paste(setdiff(a$cols, b$cols), collapse = ", "),
      dup_before  = a$n_dup_key %||% NA, dup_after = b$n_dup_key %||% NA,
      na_date_before = a$n_na_date %||% NA, na_date_after = b$n_na_date %||% NA,
      stringsAsFactors = FALSE
    )
  }))
}

`%||%` <- function(x, y) if (is.null(x)) y else x
