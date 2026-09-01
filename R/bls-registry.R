# Registry of BLS sources reachable through getBLSFiles(), plus the
# deprecated-alias table and the blsSources()/blsFiles() discovery helpers.
#
# Two families of source live here, distinguished by `join_engine`:
#   "legacy"  the 12 sources getBLSFiles() has always supported (including
#             `se`/`su`, renamed `sae`/`laus` -- see bls_deprecated_aliases).
#             getBLSFiles() still joins their lookups with the original
#             hand-maintained per-source key list, so their output is
#             unchanged apart from the period-parsing fix.
#   "derived" sources added by this version. getBLSFiles() joins their
#             lookups with bls_build_series() (R/bls-join.R): the key is
#             derived by column-name intersection rather than hardcoded.
#             See recommendations.md section 4 for why, and what that rule
#             gets right that a naive "{file}_code" rule does not.
#
# `frequency` is advisory metadata only, read by nothing but blsSources().
# Dates come from the actual period codes in the data (bls_parse_period()),
# so a wrong value here is a documentation bug, not a data bug.
#
# `approx_mb` is the size of the default file as listed by BLS on 2026-08-19.
# It is informational; getBLSFiles() checks the live size via bls_list_files()
# before downloading a "derived" source, not this column.

bls_registry <- function() {
  r <- function(name, prefix, file, title, frequency, tier, approx_mb,
                join_engine, status = "current", notes = "") {
    data.frame(
      name = name, prefix = prefix, file = file, title = title,
      frequency = frequency, tier = tier, approx_mb = approx_mb,
      join_engine = join_engine, status = status, notes = notes,
      stringsAsFactors = FALSE
    )
  }

  out <- rbind(
    # --- Tier 1, legacy join engine: unchanged from pre-existing releases,
    # other than the period fix and (sae/laus) the name. ---------------------
    r("cpi", "cu", "data.0.Current", "Consumer Price Index, all urban consumers (CPI-U)", "monthly", 1, 48.9, "legacy"),
    r("eci", "ci", "data.1.AllData", "Employment Cost Index", "quarterly", 1, 8.6, "legacy"),
    r("cex", "cx", "data.1.AllData", "Consumer Expenditure Survey", "annual", 1, 120.8, "legacy"),
    r("jolts", "jt", "data.1.AllItems", "Job Openings and Labor Turnover Survey", "monthly", 1, 34.4, "legacy"),
    r("cps", "ln", "data.1.AllData", "Current Population Survey, labor force statistics", "monthly", 1, 389.7, "legacy"),
    r("ces", "ce", "data.0.AllCESSeries", "Current Employment Statistics, national", "monthly", 1, 350.2, "legacy"),
    r("ces_allemp", "ce", "data.01a.CurrentSeasAE", "CES all employees, seasonally adjusted", "monthly", 1, 6.0, "legacy"),
    r("ces_total", "ce", "data.00a.TotalNonfarm.Employment", "CES total nonfarm employment", "monthly", 1, 0.5, "legacy"),
    r("averageprice", "ap", "data.0.Current", "Average price data", "monthly", 1, 8.9, "legacy"),
    r("food", "ap", "data.3.Food", "Average price data, food items", "monthly", 1, 3.5, "legacy"),
    r("sae", "sm", "data.0.Current", "State and Area Employment, Hours, and Earnings", "monthly", 1, 329.5, "legacy", notes = "Was reachable as 'se', a misnomer: 'se' is not a BLS prefix."),
    r("laus", "la", "data.1.CurrentS", "Local Area Unemployment Statistics", "monthly", 1, 50.0, "legacy", notes = "Was reachable as 'su', which collides with the real BLS prefix 'su' (chained CPI)."),

    # --- Tier 1, derived join engine: new in this version. -----------------
    r("cpi_w", "cw", "data.0.Current", "Consumer Price Index, urban wage earners (CPI-W)", "monthly", 1, 46.7, "derived", notes = "Basis for the Social Security COLA."),
    r("cpi_chained", "su", "data.0.Current", "Chained CPI for all urban consumers (C-CPI-U)", "monthly", 1, 0.4, "derived", notes = "BLS prefix 'su'. Not the deprecated alias 'su', which meant LAUS."),
    r("ppi", "wp", "data.0.Current", "Producer Price Index, commodity", "monthly", 1, 71.6, "derived", notes = "wp.item is keyed on (group_code, item_code); auto-detected."),
    r("ppi_industry", "pc", "data.0.Current", "Producer Price Index, industry and product", "monthly", 1, 64.3, "derived", notes = "pc.product is keyed on (industry_code, product_code); auto-detected."),
    r("import_export", "ei", "data.0.Current", "Import and export price indexes", "monthly", 1, 11.7, "derived"),
    r("ecec", "cm", "data.1.AllData", "Employer Costs for Employee Compensation", "quarterly", 1, 26.3, "derived"),
    r("productivity", "pr", "data.1.AllData", "Major sector productivity and costs", "quarterly", 1, 3.2, "derived", notes = "Unit labor costs live here."),

    # --- Tier 2: annual and structural, registered but not all live-verified
    # this release. See BLS_COVERAGE_PLAN.md section 4. ---------------------
    r("oews", "oe", "data.1.AllData", "Occupational Employment and Wage Statistics", "annual", 2, 331.5, "derived"),
    r("bed", "bd", "data.1.AllItems", "Business Employment Dynamics", "quarterly", 2, 253.5, "derived"),
    r("cps_earnings", "le", "data.1.AllData", "CPS earnings", "quarterly", 2, 10.5, "derived"),
    r("cps_union", "lu", "data.1.AllData", "CPS union membership", "annual", 2, 1.4, "derived"),
    r("ind_productivity", "ip", "data.1.AllData", "Industry productivity", "annual", 2, 41.4, "derived"),

    # --- Tier 3: specialist, registered on request. -------------------------
    r("tfp", "mp", "data.1.AllData", "Major sector total factor productivity", "annual", 3, 7.4, "derived"),
    r("cps_family", "fm", "data.1.AllData", "CPS marital and family labor force statistics", "annual", 3, 1.6, "derived"),
    r("cps_veterans", "kv", "data.1.AllData", "CPS veterans supplement", "annual", 3, 1.2, "derived"),
    r("atus", "tu", "data.1.AllData", "American Time Use Survey", "annual", 3, 110.3, "derived"),
    r("ncs_benefits", "nb", "data.1.AllData", "National Compensation Survey, benefits", "annual", 3, 42.3, "derived"),
    r("ors", "or", "data.1.AllData", "Occupational Requirements Survey", "annual", 3, 3.4, "derived"),
    r("work_stoppages", "ws", "data.1.AllData", "Work stoppages", "annual", 3, 0.2, "derived"),
    r("emp_projections", "ep", "data.1.AllData", "Employment projections", "annual", 3, 6.2, "derived"),
    r("cfoi", "fa", "data.1.AllData", "Census of Fatal Occupational Injuries", "annual", 3, 35.1, "derived"),
    r("osh_industry", "is", "data.1.AllData", "Occupational injuries and illnesses, industry", "annual", 3, 241.2, "derived"),
    r(
      "osh_characteristics", "ca", "data.1.AllData",
      "Occupational injuries and illnesses, case characteristics", "annual", 3, 2885.9, "derived",
      notes = "2.9 GB. getBLSFiles() will refuse this without max_mb raised explicitly."
    )
  )

  # --- Tier 4: discontinued. Registered so they are discoverable, not usable
  # without a caller passing file= explicitly. Last data update per the BLS
  # listing on 2026-08-19.
  disc <- data.frame(
    prefix = c(
      "bg", "bp", "cb", "cc", "cd", "cf", "ch", "cs", "ec", "ee", "eb", "fi", "fw",
      "gg", "gp", "hc", "hs", "ii", "in", "jl", "li", "ml", "mu", "mw", "nc", "nd",
      "nw", "pd", "sa", "sh", "si", "wd", "wm"
    ),
    title = c(
      "Collective bargaining, state and local government",
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
      "PPI commodity, discontinued series", "Modeled Wage Estimates"
    ),
    last_update = c(
      "1995-09-18", "1996-02-16", "2023-12-01", "2004-02-26", "2003-04-09",
      "2004-10-28", "2012-01-09", "2023-04-06", "2006-05-10", "2003-05-16",
      "2006-09-13", "2012-04-25", "2024-01-25", "2013-03-19", "2000-02-04",
      "2004-03-26", "1996-11-26", "2014-12-18", "2013-08-21", "2003-08-08",
      "2016-07-15", "2013-06-21", "2010-02-23", "2010-02-23", "2006-08-31",
      "2026-08-13", "2011-08-04", "2005-04-19", "2003-01-28", "2002-12-19",
      "2003-12-18", "2026-08-13", "2024-08-22"
    ),
    stringsAsFactors = FALSE
  )
  disc_rows <- data.frame(
    name = disc$prefix, prefix = disc$prefix, file = NA_character_,
    title = disc$title, frequency = NA_character_, tier = 4L,
    approx_mb = NA_real_, join_engine = "derived", status = "discontinued",
    notes = paste0(
      "Last data update ", disc$last_update,
      ". No default file; pass file= explicitly (see blsFiles())."
    ),
    stringsAsFactors = FALSE
  )

  out <- rbind(out, disc_rows)
  out$url <- paste0("https://download.bls.gov/pub/time.series/", out$prefix, "/")
  out$tier <- as.integer(out$tier)
  out[order(out$tier, out$name), ]
}

# 'su' is a real BLS prefix (chained CPI); the old 'su' alias was squatting on
# it. 'se' was never a BLS prefix at all. See recommendations.md.
bls_deprecated_aliases <- c(se = "sae", su = "laus")

#' List available BLS sources
#'
#' @param tier Optional integer vector; 1 = release-calendar workhorses,
#'   2 = annual/structural, 3 = specialist, 4 = discontinued.
#' @param status \code{"current"}, \code{"discontinued"}, or \code{NULL} for
#'   both. Default \code{"current"}.
#' @param pattern Optional regex matched against \code{name} and \code{title}.
#' @return A tibble: one row per source, with \code{name}, \code{prefix},
#'   \code{file} (default data file), \code{title}, \code{frequency},
#'   \code{tier}, \code{approx_mb}, \code{status}, \code{notes}, \code{url}.
#' @examples
#' \dontrun{
#'   blsSources()
#'   blsSources(tier = 1)
#'   blsSources(pattern = "price")
#' }
#' @export
blsSources <- function(tier = NULL, status = "current", pattern = NULL) {
  x <- bls_registry()
  if (!is.null(tier)) x <- x[x$tier %in% tier, , drop = FALSE]
  if (!is.null(status)) x <- x[x$status %in% status, , drop = FALSE]
  if (!is.null(pattern)) {
    hit <- grepl(pattern, x$name, ignore.case = TRUE) |
      grepl(pattern, x$title, ignore.case = TRUE)
    x <- x[hit, , drop = FALSE]
  }
  rownames(x) <- NULL
  dplyr::as_tibble(x[, c("name", "prefix", "file", "title", "frequency", "tier", "approx_mb", "status", "notes", "url")])
}

# Resolve a user-facing name to a registry row, with fuzzy suggestions on a
# miss and a deprecation warning for se/su.
bls_resolve <- function(source) {
  source <- tolower(trimws(source))
  reg <- bls_registry()

  if (source %in% names(bls_deprecated_aliases)) {
    new <- bls_deprecated_aliases[[source]]
    warning(
      "Source '", source, "' is deprecated and will be removed in a future ",
      "release. Use '", new, "'. ('", source, "' also happens to be a real ",
      "BLS prefix for a different survey; see getBLSFiles() docs.)",
      call. = FALSE
    )
    source <- new
  }

  hit <- reg[reg$name == source, , drop = FALSE]
  if (nrow(hit) == 1L) {
    return(as.list(hit))
  }

  d <- utils::adist(source, reg$name, ignore.case = TRUE)[1, ]
  near <- reg$name[order(d)][seq_len(min(5L, nrow(reg)))]
  near <- near[d[order(d)][seq_len(length(near))] <= 6]
  stop(
    "Unknown BLS source '", source, "'.",
    if (length(near)) paste0(" Did you mean: ", paste(near, collapse = ", "), "?") else "",
    " Call blsSources() for the full list.",
    call. = FALSE
  )
}

#' List every file BLS publishes for a source
#'
#' @param source A registry name (see \code{\link{blsSources}}) or a bare
#'   two-letter BLS prefix (e.g. \code{"wp"}).
#' @param email Contact email, required by BLS in the user agent.
#' @param data_only Logical, default \code{TRUE}: return only \code{.data.*}
#'   files, not lookup tables.
#' @return A tibble: \code{stem} (pass to \code{getBLSFiles(..., file = )}),
#'   \code{mb}, \code{modified} (remote mtime), \code{file} (full BLS name).
#' @examples
#' \dontrun{
#'   blsFiles("ppi", "your.email@example.com")
#' }
#' @export
blsFiles <- function(source, email, data_only = TRUE) {
  prefix <- tryCatch(
    bls_resolve(source)$prefix,
    error = function(e) if (nchar(source) == 2L) source else stop(e)
  )
  x <- bls_list_files(prefix, email)
  if (data_only) x <- x[x$is_data, , drop = FALSE]
  x$mb <- round(x$bytes / 1e6, 2)
  rownames(x) <- NULL
  dplyr::as_tibble(x[, c("stem", "mb", "modified", "file")])
}
