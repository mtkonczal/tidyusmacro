#' cesDiffusionIndex Dataset
#'
#' A tibble with 250 rows and 2 columns representing industry codes and corresponding industry titles.
#'
#' This dataset contains information on different industries, where each row corresponds to an industry
#' defined by its unique code and a descriptive title. It is useful for analyses that require linking industry
#' classifications to descriptive labels.
#'
#' @format A tibble with 250 rows and 2 variables:
#' \describe{
#'   \item{ces_industry_code}{A character vector containing the industry codes (e.g., "10-11330000").}
#'   \item{ces_industry_title}{A character vector containing the titles of the industries (e.g., "Logging").}
#' }
#'
#' @source U.S. Bureau of Labor Statistics (BLS)
#'
#' @examples
#' # Load the dataset
#' data(cesDiffusionIndex)
#'
"cesDiffusionIndex"
