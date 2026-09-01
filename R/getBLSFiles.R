#' Download and Process Bureau of Labor Statistics Data
#'
#' Downloads and processes data from Bureau of Labor Statistics (BLS) flat files.
#' Supports multiple data sources including CPI, ECI, JOLTS, CPS, CES, and others.
#' The function retrieves the main data file along with associated metadata files,
#' merges them, and returns a tidy tibble ready for analysis.
#'
#' @param data_source Character string specifying the BLS data source. Call
#'   \code{\link{blsSources}()} for the full, current list with sizes and
#'   descriptions. Commonly used values:
#'   \describe{
#'     \item{\code{"cpi"}}{Consumer Price Index - current data}
#'     \item{\code{"cpi_w"}}{CPI, urban wage earners; basis for the Social Security COLA}
#'     \item{\code{"cpi_chained"}}{Chained CPI (C-CPI-U); basis for tax bracket indexing}
#'     \item{\code{"eci"}}{Employment Cost Index (quarterly)}
#'     \item{\code{"ecec"}}{Employer Costs for Employee Compensation (quarterly)}
#'     \item{\code{"cex"}}{Consumer Expenditure Survey}
#'     \item{\code{"jolts"}}{Job Openings and Labor Turnover Survey}
#'     \item{\code{"cps"}}{Current Population Survey}
#'     \item{\code{"ces"}}{Current Employment Statistics - all series}
#'     \item{\code{"ces_allemp"}}{Current Employment Statistics - all employees, seasonally adjusted}
#'     \item{\code{"ces_total"}}{Current Employment Statistics - total nonfarm employment}
#'     \item{\code{"averageprice"}}{Average price data - current}
#'     \item{\code{"food"}}{Average price data - food items}
#'     \item{\code{"ppi"}}{Producer Price Index, commodity}
#'     \item{\code{"ppi_industry"}}{Producer Price Index, industry and product}
#'     \item{\code{"import_export"}}{Import and export price indexes}
#'     \item{\code{"productivity"}}{Major sector productivity and unit labor costs}
#'     \item{\code{"laus"}}{Local Area Unemployment Statistics (was \code{"su"})}
#'     \item{\code{"sae"}}{State and Area Employment, Hours, and Earnings (was \code{"se"})}
#'   }
#'   \code{"se"} and \code{"su"} still work but are deprecated: \code{"su"} is
#'   a real BLS prefix (chained CPI), which the old alias was squatting on, so
#'   it could not be reused once chained CPI was added. They warn and redirect
#'   to \code{"sae"}/\code{"laus"}.
#' @param email Character string with your email address. Required by BLS for
#'   identifying API users. Set as the HTTP User-Agent header.
#' @param weights Logical; for \code{data_source = "cpi"} only. When \code{TRUE}
#'   (the default), also downloads \code{cu.aspect} and attaches monthly relative
#'   importance plus BLS's own published contributions. Ignored for every other
#'   data source. Set to \code{FALSE} to skip the extra ~31 MB download.
#' @param include_averages Logical, default \code{TRUE}. BLS period codes
#'   include not just monthly/quarterly observations but computed averages:
#'   \code{M13} (annual average), \code{S01}/\code{S02} (half-year average),
#'   \code{S03} (annual average), and \code{Q05} (annual average). These are
#'   flagged via the \code{is_average} column rather than dropped, because for
#'   some sources (CEX publishes only \code{A01}) they are the only rows that
#'   exist. Set \code{FALSE} to drop them, e.g. before a \code{group_by(date)}
#'   across many series where an average row would otherwise land on the same
#'   December date as that year's real December observation.
#' @param file Character, optional. Picks a non-default data file within the
#'   survey, e.g. \code{file = "data.21.Aggregates"} for PPI's FD-ID
#'   aggregates. Call \code{\link{blsFiles}(data_source, email)} to see what
#'   exists. Required for the discontinued (tier 4) surveys, which have no
#'   default file.
#' @param max_mb Numeric, default 500. Refuse to download a data file larger
#'   than this without an explicit override (e.g. \code{osh_characteristics}
#'   is 2.9 GB). Set \code{Inf} to disable.
#'
#' @return A tibble containing the merged data with columns for:
#'   \item{series_id}{Unique identifier for each data series}
#'   \item{date}{Observation date. See the "Period parsing" section below.}
#'   \item{freq}{One of \code{"monthly"}, \code{"quarterly"},
#'     \code{"semiannual"}, or \code{"annual"}, from the BLS period code.}
#'   \item{is_average}{\code{TRUE} for rows BLS computed as an average or
#'     annual aggregate (period codes \code{M13}, \code{S01}, \code{S02},
#'     \code{S03}, \code{Q05}) rather than observed in that period.}
#'   \item{value}{Numeric data value}
#'   \item{...}{Additional metadata columns vary by data source (e.g., item codes,
#'     industry codes, area codes)}
#'   For CPI with \code{weights = TRUE}, four further columns:
#'   \item{weight}{Relative importance, in percent of all items, on the base
#'     month for the 1-month change ending in this observation month. This is
#'     the weight for a 1-month contribution; do not lag it. See the dating
#'     note below.}
#'   \item{weight_12mo}{Relative importance on the base month for the 12-month
#'     change ending in this observation month; the weight for a 12-month
#'     contribution}
#'   \item{effect_1m}{BLS's own published effect on the 1-month all items
#'     change, in percentage points. Seasonally adjusted rows only.}
#'   \item{effect_12m}{BLS's own published effect on the 12-month all items
#'     change, in percentage points. Not seasonally adjusted rows only.}
#'
#' @details
#' The function constructs URLs to BLS flat files at
#' \url{https://download.bls.gov/pub/time.series/}, downloads the series
#' metadata and auxiliary lookup tables, then downloads and merges the main
#' data file.
#'
#' @section Period parsing:
#' Prior to this version, \code{date} was computed as
#' \code{substr(period, 2, 3)} for every source except ECI. That is correct
#' for monthly (\code{M01}-\code{M12}) and, via a special case, for ECI's
#' quarterly (\code{Q01}-\code{Q04}) codes, but every source can also carry
#' BLS-computed average rows on other period codes, and the old parser
#' mis-stamped them: \code{S01}/\code{S02} (half-year averages) became
#' January/February, \code{S03} became March, and \code{M13} (annual average)
#' became a silent \code{NA}. Verified on \code{cu.data.1.AllItems}
#' (2026-08-19): 26\% of rows were affected. This version uses one parser for
#' every period code (see \code{is_average} above) and gives every row a
#' correct date.
#'
#' The month is the \emph{end} of the period, matching the pre-existing ECI
#' convention (\code{Q01} is March). Annual and half-year rows land in the last
#' month they cover: \code{M13}/\code{S03}/\code{Q05}/\code{A01} in December,
#' \code{S01} in June.
#'
#' The \emph{day} separates observed values from computed averages. An observed
#' value is dated the \strong{first} of its month, matching every other date
#' this package returns (\code{\link{getFRED}}, \code{\link{getNIPAFiles}}). A
#' computed average is dated the \strong{last day} of its terminal month:
#' \code{2024-12-31} for \code{M13}, \code{2024-06-30} for \code{S01}.
#'
#' That rule exists because the month alone cannot separate them. There is no
#' month an annual average can occupy that some observed month does not already
#' own, so under a uniform first-of-month rule the 2024 annual average and the
#' real December 2024 observation are the same \code{Date}, and a
#' \code{group_by(date)} across many series double-counts silently. With the day
#' rule that is impossible rather than merely documented.
#'
#' Averages still share a date with each \emph{other}: \code{M13}, \code{S02}
#' and \code{S03} all land on December 31. They are all averages, so
#' \code{is_average} or \code{freq} separates them and no observed value is ever
#' contaminated. The full key is \code{(series_id, date, freq)}, not
#' \code{date} alone.
#'
#' @section CPI relative importance:
#' Relative importance comes from \code{cu.aspect} (aspect type \code{"I"}),
#' which BLS restamps with every CPI release. Three things about the join are
#' worth knowing:
#'
#' \itemize{
#'   \item It is keyed on \code{area_code} + \code{item_code} + \code{date}, not
#'     on \code{series_id}. BLS publishes relative importance only on the not
#'     seasonally adjusted series (\code{CUUR...}), but the weight describes the
#'     item, not the adjustment, so joining on \code{series_id} would return all
#'     \code{NA} for seasonally adjusted work. Codes rather than names, because
#'     BLS renames items and the codes are stable.
#'   \item Coverage is U.S. city average (\code{area_code == "0000"}) from March
#'     2012 forward. Outside that window \code{weight} is \code{NA} rather than
#'     back-filled: an imputed weight that looks like a real one is worse than a
#'     missing value. See the BLS relative importance archive for a pre-2012
#'     backfill.
#'   \item A row of \code{cu.aspect} stamped month \emph{t} carries the relative
#'     importance BLS labels month \emph{t-1}. This is the one thing about the
#'     file that reliably produces off-by-one errors, so it is worth stating
#'     twice: the weight you want for the change \emph{ending} in month \emph{t}
#'     is the row dated \emph{t}, not a lag of it. Verified against the June 2026
#'     release, where the "Relative importance May 2026" column of Tables 6 and 7
#'     matches the 2026-06-01 rows for all 307 items exactly and the 2026-05-01
#'     rows for only 43. The same shift is why BLS's published "Relative
#'     importance, December YYYY" table is the \strong{January YYYY+1} row.
#'   \item Accordingly \code{weight} is the row dated \emph{t} and needs no lag,
#'     and \code{weight_12mo} is the row dated \emph{t-11} -- eleven months back,
#'     because the RI labeled \emph{t-12} lives in the \emph{t-11} row.
#'   \item Both weight columns are joined on a month index, never by row
#'     position. BLS omits rows entirely for intermittently priced items rather
#'     than writing NA, so a positional lag borrows the wrong month's weight
#'     without warning.
#' }
#'
#' @section Contributions:
#' \code{effect_1m} and \code{effect_12m} are BLS's own decomposition, and they
#' equal the "effect on All Items" columns of news release Tables 6 and 7
#' exactly. Use them for anything BLS publishes.
#'
#' \code{weight} and \code{weight_12mo} are for aggregations BLS does not
#' publish. For a 12-month contribution,
#' \code{weight_12mo * (value / lag12(value) - 1)} on the NSA series is a good
#' approximation. For a 1-month contribution on the \emph{seasonally adjusted}
#' series, note that relative importance is defined on the NSA index and has to
#' be rescaled by the item's seasonal factor relative to all items before it will
#' reproduce BLS's number; see \code{\link{getCPIAspects}} for the exact formula.
#'
#' In both cases lag by calendar month, not row position.
#'
#' @examples
#' \dontrun{
#'   # Download CPI data with monthly relative importance attached
#'   cpi_data <- getBLSFiles("cpi", "your.email@example.com")
#'
#'   # Skip the weights download
#'   cpi_fast <- getBLSFiles("cpi", "your.email@example.com", weights = FALSE)
#'
#'   # Download JOLTS data
#'   jolts_data <- getBLSFiles("jolts", "your.email@example.com")
#' }
#'
#' @seealso \code{\link{getCPIAspects}} for the other CPI aspect types: BLS's own
#'   contribution decomposition, median standard errors, and seasonal factors.
#'
#' @importFrom readr read_tsv cols
#' @importFrom dplyr mutate left_join as_tibble case_when
#' @importFrom magrittr %>%
#' @export
getBLSFiles <- function(data_source, email, weights = TRUE, include_averages = TRUE,
                         file = NULL, max_mb = 500) {
  data_source <- tolower(trimws(data_source))
  spec <- bls_resolve(data_source) # errors with a fuzzy suggestion on a bad name;
  # warns and redirects for the deprecated se/su aliases.
  data_source <- spec$name
  prefix <- spec$prefix

  main_file <- if (is.null(file)) spec$file else file
  if (is.na(main_file)) {
    # Tier 4 (discontinued) sources are registered for discoverability and have
    # no default file. Without this check the NA falls through to a subset that
    # returns NA-filled rows, and the failure surfaces as "missing value where
    # TRUE/FALSE needed" after a wasted round trip.
    stop(
      "'", data_source, "' is a discontinued survey with no default data file. ",
      "Call blsFiles('", data_source, "', email, data_only = FALSE) to see what ",
      "it still publishes, then pass file = explicitly.",
      call. = FALSE
    )
  }

  # Lookup stems pinned in the registry, if any. When present the directory
  # listing becomes optional: see bls_build_series() for why that matters on a
  # release morning.
  pinned <- bls_registry_lookups(spec)

  listing <- tryCatch(bls_list_files(prefix, email), error = function(e) e)
  if (inherits(listing, "error")) {
    if (is.null(pinned)) {
      stop(
        "Could not list the files BLS publishes for '", prefix, "': ",
        conditionMessage(listing),
        call. = FALSE
      )
    }
    warning(
      "Could not read the BLS directory listing (", conditionMessage(listing),
      "). Proceeding with the lookup list pinned in the registry; the ",
      "max_mb size guard falls back to a HEAD request.",
      call. = FALSE
    )
    listing <- NULL
  }

  if (!is.null(listing)) {
    target <- listing[listing$stem %in% main_file, , drop = FALSE]
    if (!nrow(target)) {
      stop(
        "File '", prefix, ".", main_file, "' does not exist. Call blsFiles('",
        data_source, "', email) to list the ", sum(listing$is_data),
        " data file(s) in this survey.", call. = FALSE
      )
    }
    bytes <- target$bytes[1]
  } else {
    bytes <- bls_head_size(prefix, main_file, email)
  }

  mb <- bytes / 1e6
  if (!is.na(mb)) {
    if (mb > max_mb) {
      stop(
        "'", prefix, ".", main_file, "' is ", round(mb, 1), " MB, over the ",
        max_mb, " MB max_mb limit. Re-call with max_mb = ", ceiling(mb),
        " to proceed.", call. = FALSE
      )
    }
    message("Downloading ", prefix, ".", main_file, " (", round(mb, 1), " MB)...")
  } else {
    message("Downloading ", prefix, ".", main_file, " (size unknown)...")
  }

  series_df <- bls_build_series(
    prefix, email,
    files = listing, lookups = pinned
  )
  main_df <- bls_read(prefix, main_file, email, show_progress = TRUE)

  # Clean and convert the main data. Everything arrives as character (see
  # bls_read()); `value` is the one column converted here, the rest are handled
  # after the joins by bls_retype().
  main_df$series_id <- gsub(" ", "", main_df$series_id)
  raw_value <- main_df$value
  # as.numeric() already tolerates surrounding whitespace, so the trim is done
  # only on the rows that failed to parse rather than on the whole column: a
  # full trimws() pass costs ~1.6s on the 8.3M-row CES file and buys nothing.
  main_df$value <- suppressWarnings(as.numeric(raw_value))
  bad <- is.na(main_df$value) & !is.na(raw_value)
  unparsed <- if (any(bad)) sum(nzchar(trimws(raw_value[bad]))) else 0L
  if (unparsed > 0) {
    message(
      "Note: ", format(unparsed, big.mark = ","),
      " value(s) were not numeric and became NA (BLS writes '-' for suppressed ",
      "or unavailable observations)."
    )
  }

  # Shared period parser: see bls_parse_period() in R/bls-period.R for why
  # this replaced substr(period, 2, 3), and for the day-of-month convention
  # that keeps computed averages off the same date as observed values.
  per <- bls_parse_period(main_df$year, main_df$period)
  main_df$date <- per$date
  main_df$freq <- per$freq
  main_df$is_average <- per$is_average
  if (!include_averages) {
    n0 <- nrow(main_df)
    main_df <- main_df[!main_df$is_average, , drop = FALSE]
    if (nrow(main_df) == 0) {
      stop(
        "include_averages = FALSE removed every row of '", data_source,
        "': this source publishes nothing but BLS-computed averages (CEX, for ",
        "one, publishes only A01 annual rows). Re-call with ",
        "include_averages = TRUE.", call. = FALSE
      )
    }
    if (n0 > nrow(main_df)) {
      message(
        "Dropped ", format(n0 - nrow(main_df), big.mark = ","),
        " annual-average / half-year row(s) (is_average = TRUE)."
      )
    }
  }

  # Merge the main data with the series metadata.
  # First, identify columns that exist in both dataframes (except series_id).
  # Keep the main_df version of these columns (e.g., footnote_codes for the
  # observation is more relevant than footnote_codes for the series definition).
  message("Merging main data with series metadata...")

  common_cols <- setdiff(intersect(names(main_df), names(series_df)), "series_id")
  if (length(common_cols) > 0) {
    series_df <- series_df[, !names(series_df) %in% common_cols, drop = FALSE]
  }

  # series_df must be unique on series_id; error loudly if not.
  result_df <- dplyr::left_join(
    main_df, series_df,
    by = "series_id",
    relationship = "many-to-one"
  )

  # Restore real types to the few columns that are genuinely numeric or logical
  # (display_level above all; see R/bls-types.R). Done before the weight join so
  # the join keys are settled and `year` is an integer in the returned table.
  result_df <- bls_retype(result_df)

  # Attach CPI relative importance from cu.aspect. Keyed on area + item + date
  # rather than series_id: BLS publishes weights only on the NSA series, but the
  # weight belongs to the item, so a series_id join would leave every
  # seasonally adjusted row NA. See the "CPI relative importance" section above.
  #
  # Note the interaction with the period convention: relative importance is a
  # monthly concept and is published only on M01-M12, so it is dated the first
  # of the month. Computed averages are dated the last day of their period and
  # therefore match no weight, which is the correct outcome -- an annual average
  # has no single month's relative importance.
  if (isTRUE(weights) && data_source == "cpi") {
    asp <- getCPIAspects(email, survey = prefix)
    weight_df <- build_weight_bases(asp[asp$aspect_type == "I", , drop = FALSE])

    # W1 and WC are published on the seasonally adjusted and not seasonally
    # adjusted series respectively, so they join on the full series_id -- unlike
    # relative importance, which describes the item and joins on area + item.
    effect_df <- asp[asp$aspect_type %in% c("W1", "WC"), , drop = FALSE]
    effect_df <- data.frame(
      series_id = effect_df$series_id,
      date = effect_df$date,
      effect_1m = ifelse(effect_df$aspect_type == "W1", effect_df$value_num, NA_real_),
      effect_12m = ifelse(effect_df$aspect_type == "WC", effect_df$value_num, NA_real_),
      stringsAsFactors = FALSE
    )

    weight_key <- c("area_code", "item_code", "date")
    missing_key <- setdiff(weight_key, names(result_df))
    if (length(missing_key) > 0) {
      warning(
        "Cannot attach CPI weights; missing column(s): ",
        paste(missing_key, collapse = ", "),
        ". Returning index values without weights."
      )
    } else {
      n_before <- nrow(result_df)
      # many-to-one: one weight per area/item/month, applied to both the
      # seasonally adjusted and unadjusted series for that item.
      result_df <- dplyr::left_join(
        result_df, weight_df,
        by = weight_key,
        relationship = "many-to-one"
      )
      if (nrow(result_df) != n_before) {
        stop(
          "Internal error: weight join changed row count from ",
          n_before,
          " to ",
          nrow(result_df),
          ". Please report at https://github.com/mtkonczal/tidyusmacro/issues"
        )
      }
      matched <- sum(!is.na(result_df$weight))
      message(
        "Attached relative importance to ",
        format(matched, big.mark = ","),
        " of ",
        format(n_before, big.mark = ","),
        " rows (U.S. city average, March 2012 forward; NA elsewhere)."
      )

      # W1 and WC never share a series_id/date, so one row per key after
      # collapsing the two aspect types onto a single row each.
      result_df <- dplyr::left_join(
        result_df, effect_df,
        by = c("series_id", "date"),
        relationship = "many-to-one"
      )
      if (nrow(result_df) != n_before) {
        stop(
          "Internal error: effect join changed row count from ",
          n_before,
          " to ",
          nrow(result_df),
          ". Please report at https://github.com/mtkonczal/tidyusmacro/issues"
        )
      }
      message(
        "Attached BLS published effects to ",
        format(sum(!is.na(result_df$effect_1m)), big.mark = ","),
        " (1-month, SA) and ",
        format(sum(!is.na(result_df$effect_12m)), big.mark = ","),
        " (12-month, NSA) rows."
      )
    }
  }

  # Invariant: no join above should ever produce dplyr's .x/.y suffixes.
  suffixed <- grep("\\.[xy]$", names(result_df), value = TRUE)
  if (length(suffixed) > 0) {
    stop(
      "Internal error: duplicated columns after merge (",
      paste(suffixed, collapse = ", "),
      "). Please report at https://github.com/mtkonczal/tidyusmacro/issues"
    )
  }

  # Return the final result as a tibble.
  dplyr::as_tibble(result_df)
}
