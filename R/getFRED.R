#' Download and Merge FRED Data Series with Modern Tools
#'
#' Downloads one or more FRED series from the St. Louis Fed website, optionally computes
#' lagged percentage changes, renames the variable columns, and merges all series by date.
#'
#' @param variables A character vector of FRED series IDs.
#' @param keep_all Logical. If TRUE, performs a full (outer) merge (keeping all dates);
#'   if FALSE, uses an inner merge.
#' @param rename_variables A character vector of new names for the series. If not provided,
#'   the series names (in lowercase) will be used.
#' @param lagged A logical vector (or single logical) indicating whether to compute lagged
#'   returns for each series. The lagged return is computed as:
#'   \deqn{(current\ value / previous\ value) - 1.}
#'
#' @return A data frame containing the merged FRED series.
#' @examples
#' \dontrun{
#'   # Download GDP (without lagging) and Unemployment Rate (with lagging)
#'   df <- getFRED(variables = c("GDP", "UNRATE"),
#'                 rename_variables = c("gdp", "unrate"),
#'                 lagged = c(FALSE, TRUE))
#' }
#' @importFrom readr read_csv cols
#' @importFrom dplyr full_join inner_join as_tibble
#' @importFrom purrr pmap reduce compact
#' @export
getFRED <- function(variables, keep_all = TRUE, rename_variables = NULL, lagged = NULL) {

  # Ensure FRED series IDs are in uppercase.
  variables <- toupper(variables)
  n <- length(variables)

  # Validate and set defaults for rename_variables and lagged.
  if (is.null(rename_variables)) {
    rename_variables <- rep(NA_character_, n)
  } else if (length(rename_variables) != n) {
    stop("Length of 'rename_variables' must equal the length of 'variables'.")
  }

  if (is.null(lagged)) {
    lagged <- rep(FALSE, n)
  } else if (length(lagged) == 1 && n > 1) {
    lagged <- rep(lagged, n)
  } else if (length(lagged) != n) {
    stop("Length of 'lagged' must be either 1 or equal to the length of 'variables'.")
  }

  # Helper function to download and process a single FRED series.
  get_single_series <- function(var, new_name, do_lag) {
    # Construct the URL for downloading the CSV.
    url <- sprintf("https://fred.stlouisfed.org/series/%s/downloaddata/%s.csv", var, var)
    message("Downloading ", var, " from: ", url)

    # Attempt to read the CSV using readr for efficiency.
    df <- tryCatch({
      readr::read_csv(url, col_types = readr::cols())
    }, error = function(e) {
      warning("Error downloading data for ", var, ": ", e$message)
      return(NULL)
    })
    if (is.null(df)) return(NULL)

    # Ensure that the data has at least two columns: date and value.
    if (ncol(df) < 2) {
      warning("Data for ", var, " does not have at least 2 columns. Skipping.")
      return(NULL)
    }

    # Rename the first two columns: "date" and the series name in lowercase.
    names(df)[1:2] <- c("date", tolower(var))

    # Convert the date column to Date objects (if not already).
    if (!inherits(df$date, "Date")) {
      df$date <- as.Date(df$date)
    }

    # Optionally, compute lagged percentage changes.
    if (do_lag) {
      original <- df[[tolower(var)]]
      # The first observation is set to NA as no previous value exists.
      df[[tolower(var)]] <- c(NA, original[-1] / head(original, -1) - 1)
    }

    # Rename the value column if a new name is provided.
    if (!is.na(new_name) && nzchar(new_name)) {
      names(df)[2] <- new_name
    }

    return(df)
  }

  # Use purrr::pmap to iterate over variables, rename_variables, and lagged.
  df_list <- purrr::pmap(
    list(var = variables, new_name = rename_variables, do_lag = lagged),
    get_single_series
  )

  # Remove any NULL elements (e.g., where downloads failed).
  df_list <- purrr::compact(df_list)
  if (length(df_list) == 0) {
    stop("No data downloaded successfully.")
  }

  # Define the join function based on the 'keep_all' flag.
  join_fn <- if (keep_all) {
    function(x, y) dplyr::full_join(x, y, by = "date")
  } else {
    function(x, y) dplyr::inner_join(x, y, by = "date")
  }

  # Merge the list of data frames by 'date' using purrr::reduce.
  df_merged <- purrr::reduce(df_list, join_fn)
  df_merged <- dplyr::as_tibble(df_merged)

  return(df_merged)
}



