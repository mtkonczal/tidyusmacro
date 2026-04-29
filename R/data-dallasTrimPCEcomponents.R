#' Dallas Fed Trimmed-Mean PCE component dictionary
#'
#' A tibble mapping each of the 177 components used in the Federal Reserve
#' Bank of Dallas's trimmed-mean PCE inflation rate to its corresponding
#' series in BEA NIPA Table 2.4.4U (Fisher price index for personal
#' consumption expenditures by type of product, monthly).
#'
#' Components are organized as durables (1-41), nondurables (42-91),
#' services (92-177), and one NPISH aggregate (178). The 2009 tech notes
#' (Dolmas, "Trimmed Mean PCE Inflation," updated 2022-12-23) list 178
#' components; BEA combined two of them - Tenant-Occupied Stationary
#' Homes and Tenant Landlord Durables - into a single line of Table
#' 2.4.4U (`IA000629`) when the disaggregated series stopped in December
#' 2001. The mapping reflects that combination, yielding 177 rows;
#' `dallas_idx` runs 1..178 with 94 omitted (93 holds the merged item).
#'
#' @format A tibble with 177 rows and 5 variables:
#' \describe{
#'   \item{dallas_idx}{Integer. Ordinal position in the Dallas Fed tech-notes list.}
#'   \item{name}{Character. Component name as published by the Dallas Fed.}
#'   \item{series_code}{Character. BEA NIPA series code in Table 2.4.4U.}
#'   \item{line_no}{Integer. Line number in BEA Table 2.4.4U.}
#'   \item{bea_label}{Character. Label BEA publishes alongside `series_code`.}
#' }
#'
#' @source
#' Dolmas, J. (2009, updated 2022-12-23). "PCE Inflation: Technical
#' Note." Federal Reserve Bank of Dallas. BEA NIPA Table 2.4.4U.
#'
#' @references
#' Atkinson, T., Dolmas, J., & Zarutskie, R. (2026). "Skewness warrants
#' caution as Trimmed Mean PCE inflation eases." Federal Reserve Bank of
#' Dallas, April 16, 2026.
#'
#' @examples
#' data(dallasTrimPCEcomponents)
#' head(dallasTrimPCEcomponents)
#'
"dallasTrimPCEcomponents"
