#' Download and Process BEA NIPA Files with Fast Row Expansion
#'
#' This function downloads and processes National Income and Product Accounts (NIPA)
#' data files from the BEA website. It reads the necessary register files, formats the
#' date column, and then uses the fast stringi functions together with tidyr's unnest()
#' to split the combined `TableId:LineNo` field into separate rows and columns. Finally,
#' it merges the datasets.
#'
#' @param location The URL or path where the BEA files are located.
#'   Default: "https://apps.bea.gov/national/Release/TXT/".
#' @param type A character string indicating the type of data to load.
#'   For example, "Q" for quarterly or "M" for monthly data. Default is "Q".
#'
#' @return A data frame containing the merged and formatted NIPA data.
#' @examples
#' \donttest{
#'   nipadata <- getNIPAFiles(type = "Q")
#' }
#'
#' @export
getNIPAFiles <- function(location = "https://apps.bea.gov/national/Release/TXT/",
                         type = "Q") {

  # Helper function to format BEA period strings as dates.
  # For a quarterly identifier (e.g., "Q"), it converts the quarter into a month.
  BEA_format_date <- function(x) {
    year <- substr(x, 1, 4)
    identifier <- substr(x[1], 5, 5)

    if (identifier == "Q") {
      quarter <- substr(x, 6, 6)
      month <- ifelse(quarter == "1", "03",
                      ifelse(quarter == "2", "06",
                             ifelse(quarter == "3", "09", "12")))
    } else if (identifier == "M") {
      month <- substr(x, 6, 7)
    } else {
      stop("Unknown period identifier: ", identifier)
    }

    as.Date(paste(year, month, "01", sep = "-"), format = "%Y-%m-%d")
  }

  message("Start time: ", Sys.time())

  # Build the full URLs for the required files.
  series_url <- file.path(location, "SeriesRegister.txt")
  tables_url <- file.path(location, "TablesRegister.txt")
  data_url   <- file.path(location, paste0("nipadata", type, ".txt"))

  # Read the series and tables register files.
  series <- readr::read_csv(series_url, show_col_types = FALSE) %>%
    dplyr::rename(SeriesCode = `%SeriesCode`)

  tables <- readr::read_csv(tables_url, show_col_types = FALSE)

  message("Loading ", type, " data from ", data_url)
  data <- readr::read_csv(data_url, show_col_types = FALSE) %>%
    dplyr::rename(SeriesCode = `%SeriesCode`)

  # Format the date column.
  message("Formatting date column...")
  data <- data %>%
    dplyr::mutate(date = BEA_format_date(Period))

  # Process the TableId:LineNo column.
  # Instead of using separate_rows(), we use stringi to split the column and unnest the results.
  message("Splitting TableId:LineNo using stringi and unnesting...")
  final_data <- data %>%
    dplyr::left_join(series, by = "SeriesCode") %>%
    # Create a list-column by splitting on the pipe ("|")
    dplyr::mutate(TableIdList = stringi::stri_split_fixed(`TableId:LineNo`, pattern = "|", omit_empty = TRUE)) %>%
    tidyr::unnest(cols = c(TableIdList)) %>%
    # Extract the TableId (portion before ":") and LineNo (portion after ":")
    dplyr::mutate(
      TableId = stringi::stri_extract_first_regex(TableIdList, "^[^:]+"),
      LineNo  = stringi::stri_extract_last_regex(TableIdList, "[^:]+")
    ) %>%
    dplyr::left_join(tables, by = "TableId") %>%
    mutate(LineNo = as.numeric(LineNo))

  message("End time: ", Sys.time())
  return(final_data)
}
