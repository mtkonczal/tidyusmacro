#' tidyusmacro: Downloading and Cleaning U.S. Macroeconomic Data
#'
#' Utilities to retrieve and tidy U.S. macroeconomic data from public
#' government data providers, returning consistent tibbles ready for
#' modeling and graphics.
#'
#' @section Data download functions:
#' \describe{
#'   \item{\code{\link{getFRED}}}{One or more series from FRED, merged by date.}
#'   \item{\code{\link{getBLSFiles}}}{BLS flat files (CPI, CES, CPS, JOLTS, ECI,
#'     CEX, and others), merged with their lookup tables.}
#'   \item{\code{\link{getNIPAFiles}}}{BEA NIPA flat files, expanded to one row
#'     per table line.}
#'   \item{\code{\link{getPCEInflation}}}{PCE price indices with nominal-share
#'     weights and growth rates.}
#'   \item{\code{\link{getDallasTrimPCE}}}{Component panel underlying the Dallas
#'     Fed trimmed-mean PCE inflation rate.}
#'   \item{\code{\link{getUnrateFRED}}}{Unemployment rate built from FRED levels.}
#' }
#'
#' @section Analysis and plotting helpers:
#' \describe{
#'   \item{\code{\link{logLinearProjection}}}{Log-linear trend projection for use
#'     inside \code{dplyr::mutate()}.}
#'   \item{\code{\link{date_breaks_gg}}, \code{\link{date_breaks_n}}}{Date axis
#'     breaks anchored to the data.}
#'   \item{\code{\link{theme_esp}}}{Economic Security Project ggplot2 theme and
#'     color scales.}
#' }
#'
#' @section Included datasets:
#' \code{\link{cesDiffusionIndex}}, \code{\link{dallasTrimPCEcomponents}}.
#'
#' @keywords internal
"_PACKAGE"
