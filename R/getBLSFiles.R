#' Download and Process BLS Time Series Files with Vectorized Date Assignment
#'
#' This function downloads and processes data from the Bureau of Labor Statistics (BLS)
#' for a given data source. It downloads several auxiliary files, merges them to enrich
#' series metadata, downloads the main data file, and assigns dates based on the period
#' code. For monthly data (codes "M01"–"M12") the date is set to the first day of the month;
#' if the period is "M13", the date is set to December 31; and for quarterly data (codes
#' "Q1"–"Q4") the date is assigned as the last day of the quarter's final month.
#'
#' @param data_source A character string specifying the data source. One of \code{"cpi"},
#'   \code{"eci"}, \code{"jolts"}, \code{"cps"}, \code{"ces"}, \code{"averageprice"}, or \code{"food"}.
#' @param email A character string containing your email address. This is used as the HTTP
#'   user agent when downloading files.
#'
#' @return A tibble containing the merged BLS data with an assigned date column.
#'
#' @examples
#' \dontrun{
#'   # Download CPI data using your email address
#'   bls_data <- getBLSFiles("cpi", "user@example.com")
#' }
#'
#' @importFrom dplyr mutate left_join as_tibble case_when
#' @importFrom readr read_tsv
#' @importFrom magrittr %>%
#' @export
getBLSFiles <- function(data_source, email) {
  # Validate the data source input
  available_sources <- c("cpi", "eci", "jolts", "cps", "ces", "averageprice", "food", "ces_allemp", "ces_total")
  if (!tolower(data_source) %in% available_sources) {
    stop("Invalid data source. Choose one of: ", paste(available_sources, collapse = ", "))
  }

  # Define file mappings for each data source.
  if (data_source == "cpi") {
    files <- c("cu", "data.0.Current", "series", "item", "area")
  } else if (data_source == "eci") {
    files <- c("ci", "data.1.AllData", "series", "industry", "owner", "subcell", "occupation", "periodicity", "estimate")
  } else if (data_source == "jolts") {
    files <- c("jt", "data.1.AllItems", "series", "industry", "state")
  } else if (data_source == "cps") {
    files <- c("ln", "data.1.AllData", "series", "ages", "occupation", "race", "sexs", "born")
  } else if (data_source == "ces") {
    files <- c("ce", "data.0.AllCESSeries", "series", "datatype", "supersector", "industry")
  } else if (data_source == "ces_allemp") {
    files <- c("ce", "data.01a.CurrentSeasAE", "series", "datatype", "supersector", "industry")
  } else if (data_source == "ces_total") {
    files <- c("ce", "data.00a.TotalNonfarm.Employment", "series", "datatype", "supersector", "industry")
  } else if (data_source == "averageprice") {
    files <- c("ap", "data.0.Current", "series", "area", "item")
  } else if (data_source == "food") {
    files <- c("ap", "data.3.Food", "series", "area", "item")
  }

  # Construct the base URL: files are stored at
  # "https://download.bls.gov/pub/time.series/{folder}/{folder}.{file}"
  base_url <- paste0("https://download.bls.gov/pub/time.series/", files[1], "/", files[1], ".")

  # Set HTTP user agent using the supplied email
  options(HTTPUserAgent = email)

  # Define auxiliary files: the first two elements are reserved for URL construction
  # and the main data file, so auxiliary files start with the third element.
  aux_files <- files[-c(1, 2)]

  # Download and process the "series" file first.
  if ("series" %in% aux_files) {
    message("Downloading series file...")
    series_df <- readr::read_tsv(paste0(base_url, "series"), col_types = readr::cols())
    # Clean series_id by removing spaces
    series_df <- dplyr::mutate(series_df, series_id = gsub(" ", "", series_id))
    # Remove "series" from the auxiliary file list as it is already processed.
    aux_files <- setdiff(aux_files, "series")
  } else {
    stop("The 'series' file is required but was not found in the auxiliary file list.")
  }

  # Download and merge the remaining auxiliary files with series_df.
  for (file in aux_files) {
    message("Downloading file: ", file)
    tmp_df <- readr::read_tsv(paste0(base_url, file), col_types = readr::cols())

    join_key <- if (file == "datatype") "data_type_code" else paste0(file, "_code")

    if (!join_key %in% colnames(series_df)) {
      warning("Join key '", join_key, "' not found in the series data. Skipping file: ", file)
    } else {
      series_df <- dplyr::left_join(series_df, tmp_df, by = join_key)
    }
  }

  # Download the main data file.
  message("Downloading main data file: ", files[2])
  main_df <- readr::read_tsv(paste0(base_url, files[2]), col_types = readr::cols())


  # Clean and convert the main data.
  main_df <- main_df %>%
    dplyr::mutate(
      series_id = gsub(" ", "", series_id),
      value = as.numeric(value)
    )

  # ECI is the only value that is base quarterly.
  if(data_source != "eci"){
    main_df$date = as.Date(paste(substr(main_df$period, 2,3), "01", main_df$year, sep="/"), "%m/%d/%Y")
  }
  else{
    quarterly_month <-case_when(
      main_df$period == "Q01" ~ 3,
      main_df$period == "Q02" ~ 6,
      main_df$period == "Q03" ~ 9,
      main_df$period == "Q04" ~ 12)
    main_df$date <- as.Date(paste(quarterly_month, "01", main_df$year, sep="/"), "%m/%d/%Y")
  }

  # Merge the main data with the series metadata.
  message("Merging main data with series metadata...")
  result_df <- dplyr::left_join(main_df, series_df, by = "series_id")

  # Return the final result as a tibble.
  dplyr::as_tibble(result_df)
}
