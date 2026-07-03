#' Load and Process Personal Consumption Expenditures (PCE) Inflation Data
#'
#' Downloads and processes BEA NIPA data to compute Personal Consumption Expenditures
#' (PCE) price indices with weights and growth measures. This is the Federal Reserve's
#' preferred inflation measure.
#'
#' The function performs the following steps:
#' \enumerate{
#'   \item Loads NIPA data using \code{\link{getNIPAFiles}} (or uses pre-loaded data).
#'   \item Extracts total PCE from table \code{"U20405"} (series code \code{"DPCERC"}).
#'   \item Computes PCE component weights as the nominal consumption share
#'         (component value divided by total PCE).
#'   \item Extracts quantity indices from table \code{"U20403"}.
#'   \item Loads price indices from table \code{"U20404"}, joins weights and quantities,
#'         and calculates period-over-period growth measures.
#' }
#'
#' @param frequency Character string indicating the frequency of the data:
#'                  \code{"M"} (monthly, the default) or \code{"Q"} (quarterly).
#'                  Also sets the compounding used to annualize
#'                  \code{WDataValue_P1a} (12 for monthly, 4 for quarterly).
#' @param NIPA_data Optional data frame. If provided, it will be used as the raw NIPA dataset
#'                  instead of loading fresh data with \code{getNIPAFiles()}. Make sure
#'                  \code{frequency} matches the frequency of the supplied data, since it
#'                  determines the annualization exponent.
#'
#' @return A tibble with one row per (date, PCE component), containing the
#'   columns from \code{\link{getNIPAFiles}} for price-index table
#'   \code{"U20404"} (including \code{date}, \code{SeriesLabel}, and the price
#'   index in \code{Value}), plus:
#'   \item{PCEweight}{Nominal consumption share: component spending divided by
#'     total PCE (both from table \code{"U20405"}).}
#'   \item{quantity}{Real quantity index from table \code{"U20403"}.}
#'   \item{DataValue_P1}{1-period percent change in the price index (decimal).}
#'   \item{DataValue_P3}{3-period percent change (decimal).}
#'   \item{DataValue_P6}{6-period percent change (decimal).}
#'   \item{WDataValue_P1}{Contribution to 1-period PCE inflation:
#'     \code{DataValue_P1} times the lagged \code{PCEweight}.}
#'   \item{WDataValue_P1a}{\code{WDataValue_P1} annualized by compounding over
#'     the periods per year implied by \code{frequency}:
#'     \code{(1 + x)^12 - 1} for monthly, \code{(1 + x)^4 - 1} for quarterly.}
#'
#' @importFrom dplyr select distinct lag mutate left_join group_by filter ungroup
#' @importFrom rlang .data
#' @examples
#' \dontrun{
#'   # Load monthly PCE data
#'   pce_data <- getPCEInflation("M")
#' }
#'
#' @export
getPCEInflation <- function(frequency = "M", NIPA_data = NULL) {

  # Periods per year for annualization. This was previously hardcoded to 4
  # (quarterly), which understated annualized monthly contributions.
  periods_per_year <- switch(toupper(frequency),
    M = 12,
    Q = 4,
    A = 1,
    stop("Unknown frequency: ", frequency, ". Use \"M\", \"Q\", or \"A\".")
  )

    # Load the full dataset using the specified frequency.
  if(is.null(NIPA_data)){
    full_data <- getNIPAFiles(type = frequency)
  } else{
    full_data <- NIPA_data
  }

  # ---------------------------------------------------------------------------
  # Step 1: Extract total PCE
  # ---------------------------------------------------------------------------
  # Filter table "U20405" for SeriesCode "DPCERC" (total personal consumption
  # expenditures, nominal). Note: the column is named TotalGDP for historical
  # reasons; it is total PCE, not GDP.
  total_gdp <- full_data %>%
    filter(TableId == "U20405", SeriesCode == "DPCERC") %>%
    dplyr::select(date, TotalGDP = Value)

  # ---------------------------------------------------------------------------
  # Step 2: Calculate PCE weights
  # ---------------------------------------------------------------------------
  # For each date, join with total PCE to compute each component's weight as:
  # weight = (nominal component spending from U20405) / (total PCE).
  # This is the nominal consumption share.
  pce_weight <- full_data %>%
    filter(TableId == "U20405") %>%
    left_join(total_gdp, by = "date") %>%
    mutate(PCEweight = Value / TotalGDP) %>%
    select(date, SeriesLabel, PCEweight) %>%
    distinct(date, SeriesLabel, .keep_all = TRUE)

  # ---------------------------------------------------------------------------
  # Step 3: Extract quantity data
  # ---------------------------------------------------------------------------
  # From table "U20403", extract the quantity data and rename the value column.
  PCE_Q <- full_data %>%
    filter(TableId == "U20403") %>%
    select(SeriesLabel, date, quantity = Value) %>%
    distinct(date, SeriesLabel, .keep_all = TRUE)

  # ---------------------------------------------------------------------------
  # Step 4: Process PCE Data
  # ---------------------------------------------------------------------------
  # From table "U20404", load the PCE data, join it with the computed PCE weights
  # and quantity data, then compute various growth measures.
  pce_df <- full_data %>%
    filter(TableId == "U20404") %>%
    left_join(pce_weight, by = c("date", "SeriesLabel")) %>%
    left_join(PCE_Q, by = c("date", "SeriesLabel")) %>%
    group_by(SeriesLabel) %>%
    # Calculate period-over-period changes:
    # DataValue_P1: 1-period (lag 1) percentage change
    mutate(DataValue_P1 = (Value - lag(Value, 1)) / lag(Value, 1)) %>%
    # DataValue_P3: 3-period change
    mutate(DataValue_P3 = Value / lag(Value, 3) - 1) %>%
    # DataValue_P6: 6-period change
    mutate(DataValue_P6 = Value / lag(Value, 6) - 1) %>%
    # Compute weighted 1-period change using the lagged weight.
    mutate(WDataValue_P1 = DataValue_P1 * lag(PCEweight, 1)) %>%
    # Annualize the weighted 1-period change by compounding over the number
    # of periods in a year (12 for monthly, 4 for quarterly).
    mutate(WDataValue_P1a = (1 + WDataValue_P1)^periods_per_year - 1) %>%
    ungroup()

  # Return the processed PCE data frame.
  return(pce_df)
}
