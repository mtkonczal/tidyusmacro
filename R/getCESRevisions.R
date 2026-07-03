#' Download CES Monthly Jobs Revisions
#'
#' Scrapes the Bureau of Labor Statistics table of monthly Current Employment
#' Statistics (CES) revisions from
#' \url{https://www.bls.gov/web/empsit/cesnaicsrev.htm} and returns a tidy
#' tibble of first, second, and third prints of the over-the-month change in
#' total nonfarm employment (1979-present), seasonally adjusted and not
#' seasonally adjusted, along with the revision deltas between prints.
#'
#' @details
#' The BLS revisions page sits behind Akamai bot detection that rejects
#' requests from R's HTTP stack (\code{httr}/\code{curl}) based on their TLS
#' fingerprint, regardless of the User-Agent header. This function therefore
#' fetches the page through a headless Chrome browser via the
#' \pkg{chromote} package, which requires a local installation of Google
#' Chrome (or another Chromium-based browser). Both \pkg{chromote} and
#' \pkg{rvest} must be installed to use this function.
#'
#' Each calendar year on the page is published as its own table with a
#' three-row header (adjustment status, measure, print). Tables are parsed
#' with \code{rvest::html_table()}, headers are flattened, and target columns
#' are located by pattern so that reordering or added columns on the BLS page
#' do not silently misalign values. If the same year-month appears in more
#' than one table, the most complete row is kept.
#'
#' All values are over-the-month changes in thousands of jobs. Recent months
#' will have \code{NA} second or third prints until those estimates are
#' published; revision columns are \code{NA} until both prints exist.
#'
#' @param source_url Character string with the BLS revisions page URL.
#'   Defaults to the CES NAICS revisions page; override only if BLS moves
#'   the page.
#' @param timeout Numeric. Maximum seconds to wait for the page to load in
#'   headless Chrome before failing. Default 60.
#'
#' @return A tibble with one row per month and columns:
#'   \item{date}{Observation month (first of month).}
#'   \item{year}{Calendar year (integer).}
#'   \item{month}{Three-letter month abbreviation.}
#'   \item{month_num}{Month number 1-12 (integer).}
#'   \item{sa_1st, sa_2nd, sa_3rd}{Seasonally adjusted first, second, and
#'     third prints of the over-the-month employment change (thousands).}
#'   \item{sa_rev_2nd_minus_1st, sa_rev_3rd_minus_2nd, sa_rev_3rd_minus_1st}{
#'     Seasonally adjusted revisions between prints (thousands).}
#'   \item{nsa_1st, nsa_2nd, nsa_3rd}{Not seasonally adjusted prints
#'     (thousands).}
#'   \item{nsa_rev_2nd_minus_1st, nsa_rev_3rd_minus_2nd,
#'     nsa_rev_3rd_minus_1st}{Not seasonally adjusted revisions (thousands).}
#'   \item{source_url}{URL the data was scraped from.}
#'   \item{scraped_at}{UTC timestamp of the download (vintage).}
#'
#' @examples
#' \dontrun{
#'   revisions <- getCESRevisions()
#'
#'   # Average absolute seasonally adjusted revision, first to third print:
#'   mean(abs(revisions$sa_rev_3rd_minus_1st), na.rm = TRUE)
#' }
#'
#' @importFrom dplyr arrange as_tibble filter group_by mutate select slice_max ungroup
#' @importFrom rlang .data
#' @export
getCESRevisions <- function(
  source_url = "https://www.bls.gov/web/empsit/cesnaicsrev.htm",
  timeout = 60
) {
  for (pkg in c("chromote", "rvest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(
        "Package '", pkg, "' is required for getCESRevisions(). ",
        "Install it with install.packages(\"", pkg, "\"). ",
        "chromote also requires a local Google Chrome installation."
      )
    }
  }

  scraped_at <- as.POSIXct(Sys.time(), tz = "UTC")
  html_text <- ces_revisions_download_html(source_url, timeout)

  doc <- rvest::read_html(html_text)
  tables <- rvest::html_elements(doc, "table")
  if (length(tables) == 0) {
    stop("No tables found at ", source_url, ". The page structure may have changed.")
  }

  pieces <- lapply(tables, ces_revisions_parse_year_table)
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  if (length(pieces) == 0) {
    stop(
      "No monthly year tables found at ", source_url,
      ". The page structure may have changed."
    )
  }
  message("Parsed ", length(pieces), " year tables from BLS revisions page.")

  value_cols <- c(
    "sa_1st", "sa_2nd", "sa_3rd",
    "sa_rev_2nd_minus_1st", "sa_rev_3rd_minus_2nd", "sa_rev_3rd_minus_1st",
    "nsa_1st", "nsa_2nd", "nsa_3rd",
    "nsa_rev_2nd_minus_1st", "nsa_rev_3rd_minus_2nd", "nsa_rev_3rd_minus_1st"
  )

  out <- do.call(rbind, pieces) %>%
    dplyr::filter(!is.na(.data$year), !is.na(.data$month_num)) %>%
    # If a year-month appears in more than one table (e.g., a recent-months
    # table overlapping a calendar-year table), keep the most complete row.
    dplyr::mutate(
      non_na_count = rowSums(!is.na(as.matrix(dplyr::pick(dplyr::all_of(value_cols)))))
    ) %>%
    dplyr::group_by(.data$year, .data$month_num) %>%
    dplyr::slice_max(.data$non_na_count, n = 1, with_ties = FALSE) %>%
    dplyr::ungroup() %>%
    # Drop months with no published values yet (empty future months).
    dplyr::filter(.data$non_na_count > 0) %>%
    dplyr::select(-"non_na_count") %>%
    dplyr::mutate(
      date = as.Date(paste(.data$year, .data$month_num, "01", sep = "-")),
      source_url = source_url,
      scraped_at = scraped_at
    ) %>%
    dplyr::arrange(.data$date) %>%
    dplyr::select(
      "date", "year", "month", "month_num",
      dplyr::all_of(value_cols), "source_url", "scraped_at"
    )

  # Sanity checks: fail loudly if the page changed shape underneath us.
  if (nrow(out) < 12 * 40) {
    warning(
      "Only ", nrow(out), " monthly rows parsed; expected 550+ (1979-present). ",
      "The BLS page structure may have changed."
    )
  }
  if (anyDuplicated(out$date) > 0) {
    stop("Internal error: duplicate months after deduplication. ",
         "Please report at https://github.com/mtkonczal/tidyusmacro/issues")
  }

  dplyr::as_tibble(out)
}

#' Fetch the BLS revisions page through headless Chrome
#'
#' The page is behind Akamai bot detection that blocks R's TLS fingerprint,
#' so a real Chrome instance (via chromote) is the only reliable R-native
#' path. The default headless User-Agent advertises "HeadlessChrome", which
#' Akamai also blocks, so it is overridden with a standard Chrome UA.
#'
#' @param url Page URL.
#' @param timeout Seconds to wait for the tables to render.
#' @return The page HTML as a single string.
#' @noRd
ces_revisions_download_html <- function(url, timeout) {
  message("Fetching BLS revisions page via headless Chrome...")
  session <- chromote::ChromoteSession$new()
  on.exit(try(session$close(), silent = TRUE), add = TRUE)

  session$Network$setUserAgentOverride(
    userAgent = paste0(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ",
      "AppleWebKit/537.36 (KHTML, like Gecko) ",
      "Chrome/127.0.0.0 Safari/537.36"
    )
  )
  session$Page$navigate(url)

  # Poll until the revision tables are in the DOM. The Akamai "Access
  # Denied" page renders zero tables, so table count doubles as a block
  # detector.
  n_tables <- 0
  deadline <- Sys.time() + timeout
  while (Sys.time() < deadline) {
    Sys.sleep(0.5)
    n_tables <- tryCatch(
      session$Runtime$evaluate(
        "document.querySelectorAll('table').length"
      )$result$value,
      error = function(e) 0
    )
    if (n_tables >= 5) break
  }
  if (n_tables < 5) {
    title <- tryCatch(
      session$Runtime$evaluate("document.title")$result$value,
      error = function(e) ""
    )
    stop(
      "Failed to load BLS revisions tables from ", url,
      " within ", timeout, " seconds (page title: '", title, "'). ",
      if (grepl("denied", title, ignore.case = TRUE)) {
        "BLS blocked the request. Try again in a few minutes."
      } else {
        "Check the URL or increase `timeout`."
      }
    )
  }

  session$Runtime$evaluate("document.documentElement.outerHTML")$result$value
}

#' Parse one per-year BLS revisions table into a tidy data frame
#'
#' Returns NULL for tables that are not monthly year tables (the page also
#' contains summary tables keyed by "Time Period" rather than Month/Year).
#'
#' @param table_node An rvest table node.
#' @return A data.frame with year, month, month_num, and the 12 SA/NSA value
#'   columns, or NULL if the table is not a monthly year table.
#' @noRd
ces_revisions_parse_year_table <- function(table_node) {
  tb <- tryCatch(
    rvest::html_table(table_node, header = FALSE, convert = FALSE),
    error = function(e) NULL
  )
  if (is.null(tb) || nrow(tb) < 2 || ncol(tb) < 4) {
    return(NULL)
  }
  mat <- as.matrix(tb)
  mat[is.na(mat)] <- ""

  # Data rows start where the first column holds a month name (possibly with
  # a trailing footnote like "(P)"); everything above is header. rvest fills
  # rowspan/colspan cells, so multi-row headers repeat their group labels.
  months <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  first_col <- gsub("\\s*\\([A-Za-z]\\)\\s*$", "", trimws(mat[, 1]))
  first_col <- sub("\\.$", "", first_col)
  is_data_row <- first_col %in% months
  if (!any(is_data_row) || which(is_data_row)[1] < 2) {
    return(NULL)
  }
  header_rows <- mat[seq_len(which(is_data_row)[1] - 1), , drop = FALSE]

  # Flatten the multi-row header: unique non-empty labels per column, joined
  # top-down, e.g. "Seasonally adjusted Over-the-month change 1st".
  col_labels <- apply(header_rows, 2, function(x) {
    x <- trimws(x)
    gsub("\\s+", " ", paste(unique(x[x != ""]), collapse = " "))
  })

  is_nsa <- grepl("Not seasonally adjusted", col_labels, ignore.case = TRUE)
  is_sa <- grepl("Seasonally adjusted", col_labels, ignore.case = TRUE) & !is_nsa
  if (!any(grepl("^Month", col_labels, ignore.case = TRUE)) ||
      !any(grepl("^Year", col_labels, ignore.case = TRUE)) ||
      !any(is_sa) || !any(is_nsa)) {
    return(NULL)
  }

  # Locate each target column by pattern. Print-level columns must NOT be
  # revision columns: "\\b1st\\b" alone would also match the "2nd - 1st"
  # revision header, so revision status is matched explicitly rather than
  # relying on column order.
  is_revision <- grepl("Revision", col_labels, ignore.case = TRUE)
  find_col <- function(adjusted, pattern, revision) {
    pool <- (if (adjusted) is_sa else is_nsa) &
      (if (revision) is_revision else !is_revision) &
      grepl(pattern, col_labels, ignore.case = TRUE)
    which(pool)[1]
  }
  # fmt: skip
  target_cols <- c(
    sa_1st                = find_col(TRUE,  "\\b1st\\b",           FALSE),
    sa_2nd                = find_col(TRUE,  "\\b2nd\\b",           FALSE),
    sa_3rd                = find_col(TRUE,  "\\b3rd\\b",           FALSE),
    sa_rev_2nd_minus_1st  = find_col(TRUE,  "2nd\\s*-\\s*1st",     TRUE),
    sa_rev_3rd_minus_2nd  = find_col(TRUE,  "3rd\\s*-\\s*2nd",     TRUE),
    sa_rev_3rd_minus_1st  = find_col(TRUE,  "3rd\\s*-\\s*1st",     TRUE),
    nsa_1st               = find_col(FALSE, "\\b1st\\b",           FALSE),
    nsa_2nd               = find_col(FALSE, "\\b2nd\\b",           FALSE),
    nsa_3rd               = find_col(FALSE, "\\b3rd\\b",           FALSE),
    nsa_rev_2nd_minus_1st = find_col(FALSE, "2nd\\s*-\\s*1st",     TRUE),
    nsa_rev_3rd_minus_2nd = find_col(FALSE, "3rd\\s*-\\s*2nd",     TRUE),
    nsa_rev_3rd_minus_1st = find_col(FALSE, "3rd\\s*-\\s*1st",     TRUE)
  )

  year_col <- which(grepl("^Year", col_labels, ignore.case = TRUE))[1]
  data_mat <- mat[is_data_row, , drop = FALSE]

  # Numeric cleaning: strip commas and footnote markers like "(P)"; em/en
  # dashes mark unpublished cells and become NA.
  to_num <- function(x) {
    x <- trimws(x)
    x <- gsub("\u2014|\u2013", "", x)
    x <- gsub("\\s*\\([A-Za-z]\\)\\s*$", "", x)
    x <- gsub(",", "", x)
    suppressWarnings(as.numeric(x))
  }

  year_raw <- data_mat[, year_col]
  year_str <- ifelse(
    grepl("\\b\\d{4}\\b", year_raw),
    sub(".*?\\b(\\d{4})\\b.*", "\\1", year_raw),
    NA_character_
  )

  out <- data.frame(
    year = as.integer(year_str),
    month = first_col[is_data_row],
    stringsAsFactors = FALSE
  )
  out$month_num <- match(out$month, months)
  for (nm in names(target_cols)) {
    idx <- target_cols[[nm]]
    out[[nm]] <- if (is.na(idx)) NA_real_ else to_num(data_mat[, idx])
  }
  out
}
