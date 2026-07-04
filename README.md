# tidyusmacro

Utilities to retrieve and tidy U.S. macroeconomic data series from public government data providers. Functions streamline access to series from the the Bureau of Labor Statistics (BLS) full data flat files for popular releases like employment and inflation, the Bureau of Economic Analysis National Income and Product Accounts (NIPA) tables that give GDP and related accounts, and Federal Reserve Bank of St. Louis Federal Reserve Economic Data (FRED). It then return consistent, tidy data frames ready for modeling and graphics.

These tools pull the entire flat files of the corresponding set, which makes them useful for exploring data, doing in-depth research, and also real-time analysis following the releases. For BLS and BEA these pulls are updated right as they go live. (FRED is usually updated 40 minutes later.) Though note for jobs numbers it can take 5-10 minutes right at launch time; API calls might work better.

The package also includes helpers for date alignment, log-linear projections, and common macro diagnostics, along with convenience plot builders for quick publication-quality charts in R tidyverse's ggplot2 format.

## Installation

```r
# Install from CRAN
install.packages("tidyusmacro")

# Or the development version from GitHub
devtools::install_github("mtkonczal/tidyusmacro")
```

## Functions

### Data Retrieval

#### `getBLSFiles`

Downloads and processes data from Bureau of Labor Statistics flat files. Supports CPI, ECI, JOLTS, CPS, CES, and CEX (Consumer Expenditure Survey).

```r
cpi_data <- getBLSFiles(data_source = "cpi", email = "user@example.com")
jolts_data <- getBLSFiles(data_source = "jolts", email = "user@example.com")
```

#### `getCESRevisions`

Downloads the revisions table of the Current Employment Survey (CES) total jobs numbers straight from their website.

```r
revisions_df <- getCESRevisions()
```

#### `getNIPAFiles`

Downloads and formats BEA NIPA data flat files, either monthly or quarterly values.

```r
nipa_quarterly <- getNIPAFiles(type = "Q")
nipa_monthly <- getNIPAFiles(type = "M")
```

#### `getPCEInflation`

Loads and processes Personal Consumption Expenditures (PCE) inflation data with weights and growth measures.

```r
pce_monthly <- getPCEInflation("M")
pce_quarterly <- getPCEInflation("Q")
```

#### `getFRED`

Downloads and merges economic data series from the Federal Reserve Economic Data (FRED) API.

```r
# Named arguments give friendly column names
fred_data <- getFRED(prime_epop = "LNS12300060", cpi = "CPIAUCSL")

# Unnamed arguments use lowercase ticker as column name
fred_data <- getFRED("UNRATE", "PAYEMS")
```

#### `getUnrateFRED`

Convenience function to download unemployment level and labor force from FRED and calculate the unemployment rate.

```r
unrate_data <- getUnrateFRED()
```

#### `getDallasTrimPCE`

Builds the component-level panel underlying the Dallas Fed Trimmed Mean PCE inflation rate: monthly price changes, Fisher expenditure-share weights, and flags for which components are trimmed each month. Useful for replicating the trimmed-mean rate or analyzing what gets trimmed.

```r
# Default 24/31 Dallas Fed trim
panel <- getDallasTrimPCE()

# Replicate the monthly trimmed-mean rate
panel |>
  dplyr::filter(!is_trimmed) |>
  dplyr::group_by(date) |>
  dplyr::summarize(trim_pce = weighted.mean(price_change, weight))
```

### Statistical Functions

#### `logLinearProjection`

Performs log-linear projections on historical data. Designed for use within dplyr verbs.

```r
library(dplyr)

data %>%
  mutate(projection = logLinearProjection(
    date = date,
    value = gdp,
    start_date = "2015-01-01",
    end_date = "2019-12-01"
  ))
```

### Visualization

#### `theme_esp`

Custom ggplot2 theme for Economic Security Project graphics with cream background and clean styling.

```r
library(ggplot2)

ggplot(data, aes(date, value)) +
  geom_line(color = esp_navy) +
  theme_esp()
```

#### `scale_color_esp` / `scale_fill_esp`

ESP-branded color scales for ggplot2.

```r
ggplot(data, aes(date, value, color = category)) +
  geom_line() +
  scale_color_esp() +
  theme_esp()
```

#### `date_breaks_gg`

Creates intelligent date breaks for ggplot2 that always include the last data point.

```r
ggplot(data, aes(date, value)) +
  geom_line() +
  scale_x_date(breaks = date_breaks_gg(n = 6, last = max(data$date)))
```

#### `date_breaks_n`

Generates evenly spaced date breaks by selecting every nth unique date.

```r
ggplot(data, aes(date, value)) +
  geom_line() +
  scale_x_date(breaks = date_breaks_n(data$date, n = 6))
```

## Included Data

#### `cesDiffusionIndex`

A tibble with 250 rows mapping CES industry codes to industry titles.

```r
data(cesDiffusionIndex)
```

#### `dallasTrimPCEcomponents`

The 177-component dictionary used by `getDallasTrimPCE`, mapping Dallas Fed trimmed-mean PCE components to BEA NIPA series codes and line numbers (Table 2.4.4U).

```r
data(dallasTrimPCEcomponents)
```

## Dependencies

-   dplyr
-   ggplot2
-   httr
-   tidyr
-   readr
-   purrr
-   rlang
-   stringi
-   magrittr

## License

This library is distributed under the MIT License.