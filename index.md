# tidyusmacro

Utilities to retrieve and tidy U.S. macroeconomic data series from
public government data providers. Functions streamline access to series
from the Federal Reserve Bank of St. Louis Federal Reserve Economic Data
(FRED), the Bureau of Labor Statistics (BLS) flat files, and the Bureau
of Economic Analysis (BEA) National Income and Product Accounts (NIPA)
tables, then return consistent, tidy data frames ready for modeling and
graphics.

The package includes helpers for date alignment, log-linear projections,
and common macro diagnostics, along with convenience plot builders for
quick publication-quality charts.

## Installation

``` r
# Install from GitHub
devtools::install_github("mtkonczal/tidyusmacro")
```

## Functions

### Data Retrieval

#### `getFRED`

Downloads and merges economic data series from the Federal Reserve
Economic Data (FRED) API.

``` r
# Named arguments give friendly column names
fred_data <- getFRED(prime_epop = "LNS12300060", cpi = "CPIAUCSL")

# Unnamed arguments use lowercase ticker as column name
fred_data <- getFRED("UNRATE", "PAYEMS")
```

#### `getBLSFiles`

Downloads and processes data from Bureau of Labor Statistics flat files.
Supports CPI, ECI, JOLTS, CPS, CES, and more.

``` r
cpi_data <- getBLSFiles(data_source = "cpi", email = "user@example.com")
jolts_data <- getBLSFiles(data_source = "jolts", email = "user@example.com")
```

#### `getNIPAFiles`

Downloads and formats BEA NIPA data flat files, either monthly or
quarterly values.

``` r
nipa_quarterly <- getNIPAFiles(type = "Q")
nipa_monthly <- getNIPAFiles(type = "M")
```

#### `getPCEInflation`

Loads and processes Personal Consumption Expenditures (PCE) inflation
data with weights and growth measures.

``` r
pce_monthly <- getPCEInflation("M")
pce_quarterly <- getPCEInflation("Q")
```

#### `getUnrateFRED`

Convenience function to download unemployment level and labor force from
FRED and calculate the unemployment rate.

``` r
unrate_data <- getUnrateFRED()
```

### Statistical Functions

#### `logLinearProjection`

Performs log-linear projections on historical data. Designed for use
within dplyr verbs.

``` r
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

Custom ggplot2 theme for Economic Security Project graphics with cream
background and clean styling.

``` r
library(ggplot2)

ggplot(data, aes(date, value)) +
  geom_line(color = esp_navy) +
  theme_esp()
```

#### `scale_color_esp` / `scale_fill_esp`

ESP-branded color scales for ggplot2.

``` r
ggplot(data, aes(date, value, color = category)) +
  geom_line() +
  scale_color_esp() +
  theme_esp()
```

#### `date_breaks_gg`

Creates intelligent date breaks for ggplot2 that always include the last
data point.

``` r
ggplot(data, aes(date, value)) +
  geom_line() +
  scale_x_date(breaks = date_breaks_gg(n = 6, last = max(data$date)))
```

#### `date_breaks_n`

Generates evenly spaced date breaks by selecting every nth unique date.

``` r
ggplot(data, aes(date, value)) +
  geom_line() +
  scale_x_date(breaks = date_breaks_n(data$date, n = 6))
```

## Included Data

#### `cesDiffusionIndex`

A tibble with 250 rows mapping CES industry codes to industry titles.

``` r
data(cesDiffusionIndex)
```

## Dependencies

- dplyr
- ggplot2
- tidyr
- readr
- purrr
- rlang
- stringi
- magrittr

## License

This library is distributed under the MIT License.
