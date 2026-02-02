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

  # Download and merge the remaining auxiliary files with series_df.
  for (file in aux_files) {
    message("Downloading file: ", file)
    tmp_df <- readr::read_tsv(paste0(base_url, file), col_types = readr::cols())

    join_key <- if (file == "datatype") {
      "data_type_code"
    } else if (data_source == "cex" && file == "characteristics") {
      c("demographics_code", "characteristics_code")
    } else {
      paste0(file, "_code")
    }

    # --- FIX: handle join_key being length 1 OR length > 1 ---
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
  message("Merging main data with series metadata...")
  result_df <- dplyr::left_join(main_df, series_df, by = "series_id")

  # Return the final result as a tibble.
  dplyr::as_tibble(result_df)
}
