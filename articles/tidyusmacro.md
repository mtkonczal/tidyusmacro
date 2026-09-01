# Get started with tidyusmacro

``` r

library(tidyusmacro)
```

tidyusmacro downloads full flat files from BLS, BEA, and FRED and
returns them as tidy data frames, with the lookup tables already joined.
One call gets you the entire release, which is what you want for
exploratory work, in-depth research, and real-time analysis on data
days. BLS and BEA files update right as releases go live; FRED usually
follows about 40 minutes later.

## Data retrieval

### BLS flat files

[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
downloads and processes data from Bureau of Labor Statistics flat files:
CPI, CPI-W, chained CPI, PPI (commodity and industry), import/export
prices, ECI, ECEC, productivity, JOLTS, CPS, CES, CEX, average prices,
state/area employment (SAE), and local area unemployment (LAUS). Call
[`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md)
for the full, current list with sizes and descriptions. BLS asks for an
email address in the user agent for flat-file downloads.

``` r

cpi_data <- getBLSFiles(data_source = "cpi", email = "user@example.com")
jolts_data <- getBLSFiles(data_source = "jolts", email = "user@example.com")

# Newer sources use the same call; blsFiles() lists what's available within one
blsFiles("ppi", "user@example.com")
ppi_data <- getBLSFiles("ppi", "user@example.com")
```

Every source carries `freq` (`"monthly"`, `"quarterly"`, `"semiannual"`,
or `"annual"`) and `is_average` (`TRUE` for BLS-computed rows like the
`M13` annual average or the `S01` half-year average).

Observed values are dated the first of their month. Computed averages
are dated the *last* day of the period they cover: `M13` for 2024 is
`2024-12-31`, `S01` is `2024-06-30`. That keeps an annual average off
the same date as the real December observation, so grouping by date
across many series cannot silently double-count. Averages do share a
date with each other, so use `is_average` or `freq` when you need to
separate them, and pass `include_averages = FALSE` to drop them
outright.

CPI arrives with monthly relative importance already attached, from
BLS’s `cu.aspect` file: `weight`, the base for the observation month’s
1-month change, and `weight_12mo`, the base for its 12-month change –
the weights a 1-month and 12-month contribution calculation actually
need, already shifted to the right month (see
[`?getBLSFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
for the dating convention; do not lag either column yourself). Coverage
is U.S. city average from March 2012 forward; weights are `NA` outside
that rather than back-filled. They are keyed on item code and month, not
series ID, so seasonally adjusted series carry them too. Pass
`weights = FALSE` to skip the extra download.

``` r

library(dplyr)

# Contribution of each item to the 12-month change in the all items index,
# in percentage points.
contributions <- cpi_data |>
  filter(area_code == "0000", seasonal == "U", periodicity_code == "R") |>
  arrange(series_id, date) |>
  group_by(series_id) |>
  mutate(contribution_12m = weight_12mo * (value / lag(value, 12) - 1)) |>
  ungroup()
```

[`getCPIAspects()`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md)
returns the rest of the metadata in that file: BLS’s own contribution
decomposition (`W1`, `WC`), median standard errors on the published
percent changes (`M1`, `MC`), and seasonal factors (`F`).

``` r

effects <- getCPIAspects("user@example.com", aspect_type = c("W1", "WC"))
```

[`getCESRevisions()`](https://www.mikekonczal.com/tidyusmacro/reference/getCESRevisions.md)
downloads the revisions table of the Current Employment Survey (CES)
total jobs numbers straight from the BLS website.

``` r

revisions_df <- getCESRevisions()
```

### BEA NIPA tables

[`getNIPAFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md)
downloads and formats BEA NIPA data flat files, either monthly or
quarterly values.

``` r

nipa_quarterly <- getNIPAFiles(type = "Q")
nipa_monthly <- getNIPAFiles(type = "M")
```

[`getPCEInflation()`](https://www.mikekonczal.com/tidyusmacro/reference/getPCEInflation.md)
loads and processes Personal Consumption Expenditures (PCE) inflation
data with weights and growth measures.

``` r

pce_monthly <- getPCEInflation("M")
pce_quarterly <- getPCEInflation("Q")
```

[`getDallasTrimPCE()`](https://www.mikekonczal.com/tidyusmacro/reference/getDallasTrimPCE.md)
builds the component-level panel underlying the Dallas Fed Trimmed Mean
PCE inflation rate: monthly price changes, Fisher expenditure-share
weights, and flags for which components are trimmed each month. Useful
for replicating the trimmed-mean rate or analyzing what gets trimmed.

``` r

# Default 24/31 Dallas Fed trim
panel <- getDallasTrimPCE()

# Replicate the monthly trimmed-mean rate
panel |>
  dplyr::filter(!is_trimmed) |>
  dplyr::group_by(date) |>
  dplyr::summarize(trim_pce = weighted.mean(price_change, weight))
```

### FRED

[`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
downloads and merges economic data series from the Federal Reserve
Economic Data (FRED) API.

``` r

# Named arguments give friendly column names
fred_data <- getFRED(prime_epop = "LNS12300060", cpi = "CPIAUCSL")

# Unnamed arguments use lowercase ticker as column name
fred_data <- getFRED("UNRATE", "PAYEMS")
```

[`getUnrateFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getUnrateFRED.md)
is a convenience function to download unemployment level and labor force
from FRED and calculate the unemployment rate.

``` r

unrate_data <- getUnrateFRED()
```

## Statistical functions

[`logLinearProjection()`](https://www.mikekonczal.com/tidyusmacro/reference/logLinearProjection.md)
performs log-linear projections on historical data. Designed for use
within dplyr verbs.

``` r

library(dplyr)

# Stands in for a real series; in practice this comes from getFRED() or
# getNIPAFiles(). Real GDP, billions of chained 2017 dollars, SAAR.
gdp_data <- data.frame(
  date = seq(as.Date("2015-01-01"), by = "quarter", length.out = 40),
  gdp  = 18000 * 1.005^(0:39)
)

# Fit the trend on 2015-2019 and project it through the end of the series.
gdp_data %>%
  mutate(projection = logLinearProjection(
    date = date,
    value = gdp,
    start_date = "2015-01-01",
    end_date = "2019-12-01"
  ))
```

## Visualization

The examples below use a small stand-in series rather than a download.

``` r

library(ggplot2)

# `set.seed()` keeps the example reproducible.
set.seed(1)
plot_data <- data.frame(
  date  = seq(as.Date("2019-01-01"), by = "month", length.out = 60),
  value = 3.5 + cumsum(rnorm(60, sd = 0.1))
)

sector_data <- rbind(
  transform(plot_data, category = "Goods"),
  transform(plot_data, value = value + 1.2, category = "Services")
)
```

[`theme_esp()`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md)
is a custom ggplot2 theme for Economic Security Project graphics with
cream background and clean styling.

``` r

ggplot(plot_data, aes(date, value)) +
  geom_line(color = esp_navy) +
  theme_esp()
```

[`scale_color_esp()`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md)
and
[`scale_fill_esp()`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md)
provide ESP-branded color scales for ggplot2.

``` r

ggplot(sector_data, aes(date, value, color = category)) +
  geom_line() +
  scale_color_esp() +
  theme_esp()
```

[`date_breaks_gg()`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_gg.md)
creates intelligent date breaks for ggplot2 that always include the last
data point.

``` r

ggplot(plot_data, aes(date, value)) +
  geom_line() +
  scale_x_date(breaks = date_breaks_gg(n = 6, last = max(plot_data$date)))
```

[`date_breaks_n()`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_n.md)
generates evenly spaced date breaks by selecting every nth unique date.

``` r

ggplot(plot_data, aes(date, value)) +
  geom_line() +
  scale_x_date(breaks = date_breaks_n(plot_data$date, n = 6))
```

## Included data

`cesDiffusionIndex` is a tibble with 250 rows mapping CES industry codes
to industry titles.

``` r

data(cesDiffusionIndex)
```

`dallasTrimPCEcomponents` is the 177-component dictionary used by
[`getDallasTrimPCE()`](https://www.mikekonczal.com/tidyusmacro/reference/getDallasTrimPCE.md),
mapping Dallas Fed trimmed-mean PCE components to BEA NIPA series codes
and line numbers (Table 2.4.4U).

``` r

data(dallasTrimPCEcomponents)
```
