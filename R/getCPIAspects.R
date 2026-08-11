#' Download CPI Metadata (Aspect) Files from BLS
#'
#' Downloads the BLS CPI "aspect" flat file, which carries the monthly metadata
#' that accompanies each published CPI series: relative importance (weights),
#' BLS's own contribution-to-the-all-items-change decomposition, median standard
#' errors, seasonal factors, and published percent changes.
#'
#' @param email Character string with your email address. Required by BLS for
#'   identifying users; set as the HTTP User-Agent header.
#' @param survey Character string, either \code{"cu"} (CPI-U, the default) or
#'   \code{"cw"} (CPI-W).
#' @param aspect_type Optional character vector of aspect codes to keep (e.g.
#'   \code{"I"} for relative importance). \code{NULL} (the default) returns
#'   every aspect type.
#'
#' @return A tibble with one row per series/month/aspect_type and columns:
#'   \item{series_id}{Full BLS series identifier}
#'   \item{area_code, item_code, seasonal, periodicity_code}{Components parsed
#'     out of \code{series_id}}
#'   \item{year, period, date}{Observation month}
#'   \item{aspect_type}{Aspect code (see Details)}
#'   \item{value}{Published value as a character string, exactly as distributed}
#'   \item{value_num}{Numeric version of \code{value}; \code{NA} for the text
#'     aspect types \code{H1} and \code{HC}}
#'   \item{footnote_codes}{BLS footnote codes, if any}
#'
#' @details
#' The aspect file lives at
#' \code{https://download.bls.gov/pub/time.series/cu/cu.aspect} and is restamped
#' with every CPI release. It is not described in \code{cu.txt} (that file was
#' last revised in February 2018; the aspect files were added in November 2024);
#' the documentation is on a separate BLS fact sheet.
#'
#' Aspect types, and the seasonal-adjustment domain each one is published on:
#' \describe{
#'   \item{\code{I}}{Relative importance, monthly. NSA series only
#'     (\code{CUUR}/\code{CWUR}), March 2012 forward.}
#'   \item{\code{I1}}{End-of-year relative importance. NSA only, Dec 2020 forward.}
#'   \item{\code{F}}{Seasonal factor. SA series (\code{CUSR}).}
#'   \item{\code{W1}}{Effect on the 1-month all items change, in percentage
#'     points. Published on the \emph{seasonally adjusted} series.}
#'   \item{\code{WC}}{Effect on the 12-month all items change, in percentage
#'     points. Published on the \emph{not seasonally adjusted} series.}
#'   \item{\code{V1}, \code{VC}}{Published 1-month (SA) and 12-month (NSA)
#'     percent changes.}
#'   \item{\code{M1}, \code{MC}}{Median standard error of the 1-month (SA) and
#'     12-month (NSA) percent change.}
#'   \item{\code{H1}, \code{HC}}{Text notes flagging largest/smallest change
#'     since a reference date. Character, not numeric.}
#' }
#'
#' Note that \code{W1}/\code{V1}/\code{M1} attach to the SA series and
#' \code{WC}/\code{VC}/\code{MC} to the NSA series, matching BLS's convention of
#' reporting 1-month changes seasonally adjusted and 12-month changes not
#' seasonally adjusted. Join those on the full \code{series_id}. Relative
#' importance (\code{I}) is the exception: it is defined only on the NSA series
#' but describes the item, so it applies to the SA series too and should be
#' joined on \code{area_code} + \code{item_code} + \code{date}. This is what
#' \code{\link{getBLSFiles}("cpi", ...)} does.
#'
#' @seealso \code{\link{getBLSFiles}}, which attaches relative importance to CPI
#'   index values directly.
#'
#' @examples
#' \dontrun{
#'   # Everything
#'   aspects <- getCPIAspects("your.email@example.com")
#'
#'   # BLS's own contribution decomposition, to check your own against
#'   effects <- getCPIAspects("your.email@example.com", aspect_type = c("W1", "WC"))
#' }
#'
#' @importFrom readr read_tsv cols col_character
#' @importFrom dplyr mutate filter as_tibble
#' @export
getCPIAspects <- function(email, survey = c("cu", "cw"), aspect_type = NULL) {
  survey <- match.arg(survey)

  # BLS requires a contact email in the user agent; restore on exit per CRAN policy
  old_opts <- options(HTTPUserAgent = email)
  on.exit(options(old_opts), add = TRUE)

  url <- paste0(
    "https://download.bls.gov/pub/time.series/",
    survey,
    "/",
    survey,
    ".aspect"
  )

  message("Downloading aspect (weights/metadata) file: ", survey, ".aspect")
  # Read every column as character: value holds text for aspect types H1/HC
  # ("S-Jan. 2012"), so a numeric read would coerce those to NA with a warning.
  asp <- readr::read_tsv(url, col_types = readr::cols(.default = readr::col_character()))

  asp <- dplyr::mutate(
    asp,
    series_id = gsub(" ", "", series_id),
    aspect_type = gsub(" ", "", aspect_type),
    value = trimws(value),
    value_num = suppressWarnings(as.numeric(value))
  )

  if (!is.null(aspect_type)) {
    # Base subsetting, not dplyr::filter: the argument and the column share a
    # name, which data masking would resolve in favor of the column.
    asp <- asp[asp$aspect_type %in% aspect_type, , drop = FALSE]
    if (nrow(asp) == 0) {
      warning(
        "No rows returned for aspect_type: ",
        paste(aspect_type, collapse = ", ")
      )
    }
  }

  # Series id layout is fixed width: CU | seasonal | periodicity | area(4) | item
  asp <- dplyr::mutate(
    asp,
    seasonal = substr(series_id, 3, 3),
    periodicity_code = substr(series_id, 4, 4),
    area_code = substr(series_id, 5, 8),
    item_code = substr(series_id, 9, nchar(series_id)),
    date = as.Date(
      paste(substr(period, 2, 3), "01", year, sep = "/"),
      "%m/%d/%Y"
    )
  )

  dplyr::as_tibble(asp[, c(
    "series_id", "area_code", "item_code", "seasonal", "periodicity_code",
    "year", "period", "date", "aspect_type", "value", "value_num",
    intersect("footnote_codes", names(asp))
  )])
}

#' Build the monthly CPI relative-importance panel
#'
#' Internal. Pulls aspect type "I" and returns one row per area/item/month with
#' the contemporaneous weight plus the 1- and 12-month lags used for
#' contribution arithmetic.
#'
#' Lags are built by joining on a month index rather than by row position, so a
#' gap in an item's history yields NA instead of silently borrowing the wrong
#' month's weight.
#'
#' @param email Email for the BLS user agent.
#' @param survey "cu" or "cw".
#' @return A tibble: area_code, item_code, date, weight, weight_lag1, weight_lag12.
#' @noRd
cpi_weights_monthly <- function(email, survey = "cu") {
  asp <- getCPIAspects(email, survey = survey, aspect_type = "I")
  build_weight_lags(asp)
}

#' Add 1- and 12-month lags to a relative-importance table
#'
#' Internal, and separated from the download so it can be tested offline.
#'
#' @param asp Tibble as returned by \code{getCPIAspects(aspect_type = "I")}.
#' @return A tibble: area_code, item_code, date, weight, weight_lag1, weight_lag12.
#' @noRd
#' @importFrom dplyr left_join as_tibble
build_weight_lags <- function(asp) {
  # month_index is a robust lag key: it does not assume the panel is complete
  # or sorted, so a gap in an item's history produces NA rather than a
  # neighboring month's weight.
  ri <- data.frame(
    area_code = asp$area_code,
    item_code = asp$item_code,
    date = asp$date,
    month_index = as.integer(asp$year) * 12L +
      as.integer(substr(asp$period, 2, 3)),
    weight = asp$value_num,
    stringsAsFactors = FALSE
  )

  dup <- sum(duplicated(ri[, c("area_code", "item_code", "month_index")]))
  if (dup > 0) {
    stop(
      "Relative importance is not unique on area_code + item_code + month (",
      dup,
      " duplicate rows). Please report at ",
      "https://github.com/mtkonczal/tidyusmacro/issues"
    )
  }

  make_lag <- function(k, nm) {
    out <- ri[, c("area_code", "item_code", "month_index", "weight")]
    out$month_index <- out$month_index + k
    names(out)[names(out) == "weight"] <- nm
    out
  }

  out <- dplyr::left_join(
    ri, make_lag(1L, "weight_lag1"),
    by = c("area_code", "item_code", "month_index"),
    relationship = "one-to-one"
  )
  out <- dplyr::left_join(
    out, make_lag(12L, "weight_lag12"),
    by = c("area_code", "item_code", "month_index"),
    relationship = "one-to-one"
  )

  dplyr::as_tibble(out[, c(
    "area_code", "item_code", "date",
    "weight", "weight_lag1", "weight_lag12"
  )])
}
