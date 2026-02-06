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
#' @param frequency Character string indicating the frequency of the data.
#'                  Defaults to \code{"M"} (monthly).
#' @param NIPA_data Optional data frame. If provided, it will be used as the raw NIPA dataset
#'                  instead of loading fresh data with \code{getNIPAFiles()}.'
#'
#' @return A \code{tbl_df} (data frame) containing the PCE data with calculated variables.
#'
#' @importFrom dplyr select distinct lag mutate left_join group_by filter ungroup
#' @importFrom rlang .data
#' @examples
#' \donttest{
#'   # Load monthly PCE data
#'   pce_data <- getPCEInflation("M")
#' }
#'
#' @export
getPCEInflation <- function(frequency = "M", NIPA_data = NULL) {

    # Load the full dataset using the specified frequency.
  if(is.null(NIPA_data)){
    full_data <- getNIPAFiles(type = frequency)
  } else{
    full_data <- NIPA_data
  }

  # ---------------------------------------------------------------------------
  # Step 1: Extract Total GDP data
  # ---------------------------------------------------------------------------
  # Filter for table "U20405" with SeriesCode "DPCERC" to get total GDP,
  # then rename the value column to TotalGDP.
  total_gdp <- full_data %>%
    filter(TableId == "U20405", SeriesCode == "DPCERC") %>%
    dplyr::select(date, TotalGDP = Value)

  # ---------------------------------------------------------------------------
  # Step 2: Calculate PCE weights
  # ---------------------------------------------------------------------------
  # For each date, join with the total GDP data to compute the PCE weight as:
  # weight = (value from U20405) / TotalGDP.
  # This approximates the nominal consumption share.
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
    # Annualize the weighted 1-period change.
    mutate(WDataValue_P1a = (1 + WDataValue_P1)^4 - 1) %>%
    ungroup()

  # Return the processed PCE data frame.
  return(pce_df)
}
