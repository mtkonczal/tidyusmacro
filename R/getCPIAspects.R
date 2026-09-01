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
#'   \item{year, period, date}{Observation month. Dates come from the shared
#'     parser in \code{bls_parse_period()}, the same one \code{getBLSFiles()}
#'     uses.}
#'   \item{freq, is_average}{Frequency implied by the BLS period code, and
#'     whether the row is a BLS-computed average. Every aspect type BLS
#'     currently publishes is monthly (verified live 2026-08-31), so
#'     \code{is_average} is presently \code{FALSE} throughout.}
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
#' @section Dating convention:
#' A row stamped month \emph{t} carries the relative importance BLS labels month
#' \emph{t-1}. That is the weight base for the \emph{t-1} to \emph{t} change, so
#' the row you want for a change ending in month \emph{t} is the row dated
#' \emph{t} -- not a lag of it.
#'
#' Verified against the June 2026 news release: the "Relative importance May
#' 2026" column in Tables 6 and 7 matches the rows dated 2026-06-01 for all 307
#' items exactly, and matches the rows dated 2026-05-01 for only 43 of them.
#' The same shift explains why BLS's published "Relative importance, December
#' YYYY" table is the \strong{January YYYY+1} row of this file.
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
#'   \item{\code{V1}, \code{VC}}{The percent change \emph{at the reference month
#'     named by \code{H1}/\code{HC}}, not the current month's change. Read them
#'     together with \code{H1}/\code{HC}: they are the two right-hand columns of
#'     news release Tables 6 and 7 ("Largest (L) or Smallest (S) change since:
#'     Date / Percent change"). The current month's percent change is not in
#'     this file; compute it from the index.}
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
#' @section Reproducing the published effect columns:
#' \code{W1} and \code{WC} are BLS's own contribution decomposition, and they
#' equal the "effect on All Items" columns of Tables 6 and 7 exactly (verified
#' for June 2026: 269 of 269 and 306 of 306 items, zero deviation). Prefer them
#' to rolling your own.
#'
#' If you do need to roll your own -- for a custom aggregation BLS does not
#' publish -- the 1-month effect is \emph{not} relative importance times the
#' seasonally adjusted percent change. Relative importance is defined on the NSA
#' index, so it has to be put on an SA footing first:
#'
#' \deqn{W1_{i,t} = I_{i,t} \times
#'   \frac{SA_{i,t-1} / NSA_{i,t-1}}{SA_{all,t-1} / NSA_{all,t-1}} \times
#'   \frac{SA_{i,t} / SA_{i,t-1} - 1}{1} \times 100}
#'
#' That reproduces \code{W1} exactly (270 of 270 items in June 2026). Dropping
#' the seasonal-factor ratio costs 0.018 percentage points on gasoline and
#' 0.008 on energy -- small, but large enough to change a rounded headline
#' contribution. There is no equally clean reconstruction of \code{WC}: chaining
#' twelve monthly NSA effects lands within 0.027 percentage points, which is why
#' the recommendation is to use BLS's value.
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

  url <- paste0(bls_base_url, survey, "/", survey, ".aspect")

  message("Downloading aspect (weights/metadata) file: ", survey, ".aspect")
  # Fetched through bls_get() for the same retries, HTTP/1.1 fallback and
  # explicit user agent as the rest of the BLS layer: this is a ~31 MB download
  # on the critical path of every getBLSFiles("cpi") call, and BLS returns 403
  # to any request without a contact email in the User-Agent.
  tmp <- tempfile(fileext = ".tsv")
  on.exit(unlink(tmp), add = TRUE)
  bls_get(url, email, dest = tmp)

  # Read every column as character: value holds text for aspect types H1/HC
  # ("S-Jan. 2012"), so a numeric read would coerce those to NA with a warning.
  asp <- readr::read_tsv(tmp, col_types = readr::cols(.default = readr::col_character()))

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
    item_code = substr(series_id, 9, nchar(series_id))
  )

  # Same shared parser getBLSFiles() uses (R/bls-period.R). This file used to
  # compute the date as substr(period, 2, 3), the same bug fixed there. Every
  # aspect type BLS currently publishes is M01-M12 (verified live 2026-08-31),
  # so this changes no value today; it removes the trap that an M13 row would
  # have been dated January of the following year.
  per <- bls_parse_period(asp$year, asp$period)
  asp$date <- per$date
  asp$freq <- per$freq
  asp$is_average <- per$is_average

  dplyr::as_tibble(asp[, c(
    "series_id", "area_code", "item_code", "seasonal", "periodicity_code",
    "year", "period", "date", "freq", "is_average", "aspect_type", "value",
    "value_num", intersect("footnote_codes", names(asp))
  )])
}

#' Build the monthly CPI relative-importance panel
#'
#' Internal. Pulls aspect type "I" and returns one row per area/item/month with
#' the weight bases for a 1-month and a 12-month contribution ending in that
#' month.
#'
#' @param email Email for the BLS user agent.
#' @param survey "cu" or "cw".
#' @return A tibble: area_code, item_code, date, weight, weight_12mo.
#' @noRd
cpi_weights_monthly <- function(email, survey = "cu") {
  asp <- getCPIAspects(email, survey = survey, aspect_type = "I")
  build_weight_bases(asp)
}

#' Attach the 12-month weight base to a relative-importance table
#'
#' Internal, and separated from the download so it can be tested offline.
#'
#' A row of \code{cu.aspect} stamped month \emph{t} holds the relative importance
#' BLS labels month \emph{t-1} -- already the base for the \emph{t-1} to \emph{t}
#' change. So:
#'
#' \itemize{
#'   \item \code{weight}, the base for the 1-month change ending at \emph{t}, is
#'     the row dated \emph{t}. No lag. Lagging it by one month, which the natural
#'     reading of "use the prior month's weight" suggests, weights month
#'     \emph{t}'s change with the RI for month \emph{t-2}.
#'   \item \code{weight_12mo}, the base for the 12-month change ending at
#'     \emph{t}, is the RI labeled \emph{t-12}, which is the row dated
#'     \emph{t-11}. Eleven months back, not twelve.
#' }
#'
#' The shift is joined on a month index rather than applied by row position, so a
#' gap in an item's history (October 2025, or any intermittently priced item)
#' yields NA instead of silently borrowing a neighboring month's weight.
#'
#' @param asp Tibble as returned by \code{getCPIAspects(aspect_type = "I")}.
#' @return A tibble: area_code, item_code, date, weight, weight_12mo.
#' @noRd
#' @importFrom dplyr left_join as_tibble
build_weight_bases <- function(asp) {
  # Relative importance is a monthly concept, and the 11-month shift below is
  # only meaningful on a monthly index. Keep observed monthly rows only. This
  # filter used to be implicit and wrong: month_index was
  # year * 12 + substr(period, 2, 3), so an M13 row would have become month 13,
  # i.e. January of the following year, and the uniqueness check below would
  # not have caught it because 13 collides with no real month.
  per <- bls_parse_period(asp$year, asp$period)
  keep <- !is.na(per$freq) & per$freq == "monthly" & !per$is_average
  if (any(!keep)) {
    message(
      "Dropped ", format(sum(!keep), big.mark = ","),
      " non-monthly relative-importance row(s) before building the weight panel."
    )
    asp <- asp[keep, , drop = FALSE]
    per <- per[keep, , drop = FALSE]
  }

  ri <- data.frame(
    area_code = asp$area_code,
    item_code = asp$item_code,
    date = per$date,
    month_index = as.integer(format(per$date, "%Y")) * 12L +
      as.integer(format(per$date, "%m")),
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

  # The RI labeled month t-12 sits in the row dated t-11, so shift by 11.
  base_12mo <- ri[, c("area_code", "item_code", "month_index", "weight")]
  base_12mo$month_index <- base_12mo$month_index + 11L
  names(base_12mo)[names(base_12mo) == "weight"] <- "weight_12mo"

  out <- dplyr::left_join(
    ri, base_12mo,
    by = c("area_code", "item_code", "month_index"),
    relationship = "one-to-one"
  )

  dplyr::as_tibble(out[, c(
    "area_code", "item_code", "date", "weight", "weight_12mo"
  )])
}
