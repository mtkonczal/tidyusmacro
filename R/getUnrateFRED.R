#' Get Full Unemployment Rate from FRED
#'
#' Downloads the civilian unemployment level and labor force level from
#' FRED, and calculates the unemployment rate as
#' \eqn{\text{unemploy\_level} / \text{lf\_level}}.
#'
#' @return A tibble with columns:
#'   \item{date}{Observation date}
#'   \item{unemploy_level}{Civilian unemployment level (in thousands)}
#'   \item{lf_level}{Civilian labor force level (in thousands)}
#'   \item{full_unrate}{Unemployment rate (decimal)}
#'
#' @examples
#' \donttest{
#'   getUnrateFRED()
#' }
#' @export
getUnrateFRED <- function() {
  getFRED(
    unemploy_level = "UNEMPLOY",
    lf_level       = "CLF16OV"
  ) %>%
    dplyr::mutate(full_unrate = .data$unemploy_level / .data$lf_level)
}
