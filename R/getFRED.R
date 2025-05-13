#' Download and Merge FRED Series
#'
#' A flexible wrapper that downloads one or more data series from the St. Louis
#' Fed (FRED) API, optionally computes one‑period percentage changes, and merges
#' them into a tidy tibble keyed by `date`.
#'
#' You may supply the series in two ways:
#' \itemize{
#'   \item \strong{Natural “\code{...}” style}:
#'     \code{getFRED(unrate = "UNRATE", payroll = "PAYEMS")}.
#'     Named arguments give friendly column names; unnamed arguments keep the
#'     (lower‑case) ticker as the column name.
#'   \item \strong{Legacy style}: pass a single (optionally named) character
#'     vector—e.g.\ \code{c(unrate = "UNRATE", payroll = "PAYEMS")}—and/or use
#'     the \code{rename_variables=} argument.  This remains supported for
#'     backward compatibility.
#' }
#'
#' If you provide names in \code{...} \emph{and} a non‑\code{NULL}
#' \code{rename_variables} vector, the function stops and prompts you to choose
#' a single naming method.
#'
#' @param ... One or more FRED series IDs.  Each element may be either
#'   \describe{
#'     \item{Unnamed character string}{The raw FRED ticker; column keeps the
#'       lowercase ticker name, e.g.\ \code{"UNRATE"}.}
#'     \item{Named character string}{The value is the FRED ticker and the name
#'       becomes the column label, e.g.\ \code{payroll = "PAYEMS"}.}
#'   }
#'   You may also pass a single character vector (named or unnamed) for
#'   compatibility with older code.
#' @param keep_all Logical.  \code{TRUE} (default) performs a full join that
#'   keeps all dates across series; \code{FALSE} performs an inner join.
#' @param rename_variables Optional character vector of new column names (one
#'   per series), retained for backward compatibility.  Supply \emph{either}
#'   this argument \emph{or} names in \code{...}, not both.
#' @param lagged Logical scalar or logical vector.  If \code{TRUE} (or the
#'   corresponding element is \code{TRUE}), the series is replaced by its
#'   one‑period percentage change \eqn{(x_t / x_{t-1}) - 1}.  Recycled to match
#'   the number of series if length 1.
#'
#' @return A tibble with a \code{date} column and one column per requested
#'   series.
#' @examples
#' \dontrun{
#'   # New interface
#'   getFRED(unrate = "UNRATE", payroll = "PAYEMS")
#'
#'   # Multiple unnamed series (columns become 'unrate' and 'payems')
#'   getFRED("UNRATE", "PAYEMS")
#'
#'   # Back‑compatibility: legacy call still works
#'   getFRED(c(unrate = "UNRATE", payroll = "PAYEMS"),
#'           lagged = c(TRUE, FALSE))
#' }
#' @importFrom readr read_csv cols
#' @importFrom dplyr full_join inner_join as_tibble
#' @importFrom purrr pmap reduce compact
#' @export
getFRED <- function(...,
                    keep_all = TRUE,
                    rename_variables = NULL,
                    lagged = NULL) {

  ## ---------------------------------------------------------------
  ## 1.  Parse the dots --------------------------------------------
  ## ---------------------------------------------------------------
  dots <- list(...)
  if (length(dots) == 0)
    stop("Provide at least one FRED series ID via the `...` arguments.")

  flat <- unlist(dots, use.names = TRUE)      # keeps slot names
  variables_raw <- unname(flat)               # the series IDs
  n <- length(variables_raw)

  names_in_dots <- names(flat)                # could be "" or NULL
  if (is.null(names_in_dots) || length(names_in_dots) == 0)
    names_in_dots <- rep(NA_character_, n)
  names_in_dots[names_in_dots == ""] <- NA_character_

  ## ---------------------------------------------------------------
  ## 2.  Resolve column names --------------------------------------
  ## ---------------------------------------------------------------
  if (!is.null(rename_variables)) {
    if (length(rename_variables) != n)
      stop("`rename_variables` must have the same length as the series list.")

    # Detect conflicting sources of names
    if (any(!is.na(names_in_dots)))
      stop(
        "You supplied names via both the `...` arguments *and* ",
        "`rename_variables=`.  Please choose only one way to name columns."
      )

    rename_vars <- rename_variables
  } else {
    rename_vars <- names_in_dots
  }

  ## ---------------------------------------------------------------
  ## 3.  Validate / recycle `lagged` -------------------------------
  ## ---------------------------------------------------------------
  if (is.null(lagged)) {
    lagged <- rep(FALSE, n)
  } else if (length(lagged) == 1 && n > 1) {
    lagged <- rep(lagged, n)
  } else if (length(lagged) != n) {
    stop("`lagged` must be length 1 or the same length as the series list.")
  }

  variables <- toupper(variables_raw)

  ## ---------------------------------------------------------------
  ## 4.  Helper: fetch one series ----------------------------------
  ## ---------------------------------------------------------------
  get_one <- function(var, col_name, do_lag) {
    url <- sprintf(
      "https://fred.stlouisfed.org/series/%s/downloaddata/%s.csv",
      var, var
    )
    message("Downloading ", var)

    df <- tryCatch(
      readr::read_csv(url, col_types = readr::cols()),
      error = function(e) {
        warning("Error downloading ", var, ": ", e$message)
        return(NULL)
      }
    )
    if (is.null(df) || ncol(df) < 2) return(NULL)

    names(df)[1:2] <- c("date", tolower(var))
    if (!inherits(df$date, "Date")) df$date <- as.Date(df$date)

    if (do_lag) {
      x <- df[[2]]
      df[[2]] <- c(NA, x[-1] / head(x, -1) - 1)
    }

    if (!is.na(col_name) && nzchar(col_name))
      names(df)[2] <- col_name

    df
  }

  ## ---------------------------------------------------------------
  ## 5.  Download & merge ------------------------------------------
  ## ---------------------------------------------------------------
  dfs <- purrr::pmap(
    list(var = variables,
         col_name = rename_vars,
         do_lag   = lagged),
    get_one
  ) |>
    purrr::compact()

  if (length(dfs) == 0)
    stop("No data downloaded successfully.")

  joiner <- if (keep_all)
    function(x, y) dplyr::full_join(x, y, by = "date")
  else
    function(x, y) dplyr::inner_join(x, y, by = "date")

  purrr::reduce(dfs, joiner) |>
    dplyr::as_tibble()
}
