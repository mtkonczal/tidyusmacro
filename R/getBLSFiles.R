#' Download and Process Bureau of Labor Statistics Data
#'
#' Downloads and processes data from Bureau of Labor Statistics (BLS) flat files.
#' Supports multiple data sources including CPI, ECI, JOLTS, CPS, CES, and others.
#' The function retrieves the main data file along with associated metadata files,
#' merges them, and returns a tidy tibble ready for analysis.
#'
#' @param data_source Character string specifying the BLS data source. Available options:
#'   \describe{
#'     \item{\code{"cpi"}}{Consumer Price Index - current data}
#'     \item{\code{"eci"}}{Employment Cost Index (quarterly)}
#'     \item{\code{"cex"}}{Consumer Expenditure Survey}
#'     \item{\code{"jolts"}}{Job Openings and Labor Turnover Survey}
#'     \item{\code{"cps"}}{Current Population Survey}
#'     \item{\code{"ces"}}{Current Employment Statistics - all series}
#'     \item{\code{"ces_allemp"}}{Current Employment Statistics - all employees, seasonally adjusted}
#'     \item{\code{"ces_total"}}{Current Employment Statistics - total nonfarm employment}
#'     \item{\code{"averageprice"}}{Average price data - current}
#'     \item{\code{"food"}}{Average price data - food items}
#'     \item{\code{"se"}}{State and metro area employment}
#'     \item{\code{"su"}}{State and local area unemployment}
#'   }
#' @param email Character string with your email address. Required by BLS for
#'   identifying API users. Set as the HTTP User-Agent header.
#'
#' @return A tibble containing the merged data with columns for:
#'   \item{series_id}{Unique identifier for each data series}
#'   \item{date}{Observation date}
#'   \item{value}{Numeric data value}
#'   \item{...}{Additional metadata columns vary by data source (e.g., item codes,
#'     industry codes, area codes)}
#'
#' @details
#' The function constructs URLs to BLS flat files at
#' \url{https://download.bls.gov/pub/time.series/}, downloads the series
#' metadata and auxiliary lookup tables, then downloads and merges the main
#' data file. Date parsing handles both monthly (most sources) and quarterly
#' (ECI) data frequencies.
#'
#' @examples
#' \donttest{
#'   # Download CPI data
#'   cpi_data <- getBLSFiles("cpi", "your.email@example.com")
#'
#'   # Download JOLTS data
#'   jolts_data <- getBLSFiles("jolts", "your.email@example.com")
#' }
#'
#' @importFrom readr read_tsv cols
#' @importFrom dplyr mutate left_join as_tibble case_when
#' @importFrom magrittr %>%
#' @export
getBLSFiles <- function(data_source, email) {
  # Validate the data source input
  available_sources <- c(
    "cpi",
    "eci",
    "jolts",
    "cps",
    "ces",
    "cex",
    "averageprice",
    "food",
    "ces_allemp",
    "ces_total",
    "se",
    "su"
  )
  if (!tolower(data_source) %in% available_sources) {
    stop(
      "Invalid data source. Choose one of: ",
      paste(available_sources, collapse = ", ")
    )
  }

  # fmt: skip
  file_mappings <- list(
    cpi          = c("cu", "data.0.Current", "series", "item", "area"),
    eci          = c("ci", "data.1.AllData", "series", "industry", "owner", "subcell", "occupation", "periodicity", "estimate"),
    cex          = c("cx", "data.1.AllData", "series", "category", "characteristics", "demographics", "item", "process"),
    jolts        = c("jt", "data.1.AllItems", "series", "industry", "state", "dataelement", "sizeclass"),
    cps          = c("ln", "data.1.AllData", "series", "ages", "occupation", "race", "sexs", "born", "lfst", "education"),
    ces          = c("ce", "data.0.AllCESSeries", "series", "datatype", "supersector", "industry"),
    ces_allemp   = c("ce", "data.01a.CurrentSeasAE", "series", "datatype", "supersector", "industry"),
    ces_total    = c("ce", "data.00a.TotalNonfarm.Employment", "series", "datatype", "supersector", "industry"),
    averageprice = c("ap", "data.0.Current", "series", "area", "item"),
    food         = c("ap", "data.3.Food", "series", "area", "item"),
    se           = c("sm", "data.0.Current", "series", "industry", "data_type", "supersector", "state", "area"),
    su           = c("la", "data.1.CurrentS", "series", "state_region_divison", "measure", "area", "area_type")
  )

  # 2. Extract the files based on the data_source variable
  files <- file_mappings[[data_source]]

  # Optional: error handling if the source doesn't exist
  if (is.null(files)) {
    stop("Unknown data source specified.")
  }

  # Construct the base URL: files are stored at
  # "https://download.bls.gov/pub/time.series/{folder}/{folder}.{file}"
  base_url <- paste0(
    "https://download.bls.gov/pub/time.series/",
    files[1],
    "/",
    files[1],
    "."
  )

  # Set HTTP user agent using the supplied email
  options(HTTPUserAgent = email)

  # Define auxiliary files: the first two elements are reserved for URL construction
  # and the main data file, so auxiliary files start with the third element.
  aux_files <- files[-c(1, 2)]

  # Download and process the "series" file first.
  if ("series" %in% aux_files) {
    message("Downloading series file...")
    series_df <- readr::read_tsv(
      paste0(base_url, "series"),
      col_types = readr::cols()
    )
    # Clean series_id by removing spaces
    series_df <- dplyr::mutate(series_df, series_id = gsub(" ", "", series_id))
    # Remove "series" from the auxiliary file list as it is already processed.
    aux_files <- setdiff(aux_files, "series")
  } else {
    stop(
      "The 'series' file is required but was not found in the auxiliary file list."
    )
  }

  # BLS metadata columns that appear in most lookup files. These are useful for

  # understanding hierarchy (display_level) but have identical names across files.
  # We rename them with the file prefix to avoid .x/.y suffix collisions.
  # - display_level: hierarchy depth (0 = top level, higher = more detailed)
  # - selectable: whether item can be selected in BLS Data Finder UI
  # - sort_sequence: display order in BLS tools
  metadata_cols_to_rename <- c("display_level", "selectable", "sort_sequence")

  # Download and merge the remaining auxiliary files with series_df.
  for (file in aux_files) {
    message("Downloading file: ", file)
    tmp_df <- readr::read_tsv(paste0(base_url, file), col_types = readr::cols())

    # Rename metadata columns with file prefix to avoid collisions
    # e.g., "display_level" becomes "item_display_level" for the item file
    cols_to_rename <- intersect(names(tmp_df), metadata_cols_to_rename)
    if (length(cols_to_rename) > 0) {
      new_names <- paste0(file, "_", cols_to_rename)
      names(tmp_df)[match(cols_to_rename, names(tmp_df))] <- new_names
    }

    # Determine the join key(s) for this auxiliary file.
    # Most files use a simple "{file}_code" pattern, but some have compound keys
    # or non-standard naming conventions.
    join_key <- if (file == "datatype") {
      # CES datatype file uses "data_type_code" not "datatype_code"
      "data_type_code"
    } else if (data_source == "cex" && file == "characteristics") {
      # CEX characteristics: same characteristic code can mean different things

      # under different demographics (e.g., "01" = "All" for multiple groupings)
      c("demographics_code", "characteristics_code")
    } else if (data_source == "cex" && file == "item") {
      # CEX item: item_code is nested within subcategory_code
      c("subcategory_code", "item_code")
    } else {
      paste0(file, "_code")
    }

    # Handle join_key being length 1 OR length > 1
    missing_in_series <- setdiff(join_key, names(series_df))
    missing_in_tmp <- setdiff(join_key, names(tmp_df))

    if (length(missing_in_series) > 0 || length(missing_in_tmp) > 0) {
      warning(
        "Join key(s) missing. ",
        if (length(missing_in_series) > 0) {
          paste0(
            "Missing in series_df: ",
            paste(missing_in_series, collapse = ", "),
            ". "
          )
        } else {
          ""
        },
        if (length(missing_in_tmp) > 0) {
          paste0(
            "Missing in ",
            file,
            ": ",
            paste(missing_in_tmp, collapse = ", "),
            ". "
          )
        } else {
          ""
        },
        "Skipping file: ",
        file
      )
    } else {
      series_df <- dplyr::left_join(series_df, tmp_df, by = join_key)
    }
  }

  # Download the main data file.
  message("Downloading main data file: ", files[2])
  main_df <- readr::read_tsv(
    paste0(base_url, files[2]),
    col_types = readr::cols()
  )

  # Clean and convert the main data.
  main_df <- main_df %>%
    dplyr::mutate(
      series_id = gsub(" ", "", series_id),
      value = as.numeric(value)
    )

  # ECI is the only value that is base quarterly.
  if (data_source != "eci") {
    main_df$date <- as.Date(
      paste(substr(main_df$period, 2, 3), "01", main_df$year, sep = "/"),
      "%m/%d/%Y"
    )
  } else {
    quarterly_month <- dplyr::case_when(
      main_df$period == "Q01" ~ 3,
      main_df$period == "Q02" ~ 6,
      main_df$period == "Q03" ~ 9,
      main_df$period == "Q04" ~ 12,
      TRUE ~ NA_real_
    )
    main_df$date <- as.Date(
      paste(quarterly_month, "01", main_df$year, sep = "/"),
      "%m/%d/%Y"
    )
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

  result_df <- dplyr::left_join(main_df, series_df, by = "series_id")

  # Return the final result as a tibble.
  dplyr::as_tibble(result_df)
}
