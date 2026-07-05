# tidyusmacro

Utilities to retrieve and tidy U.S. macroeconomic data series from
public government data providers. Functions streamline access to series
from the Bureau of Labor Statistics (BLS) full data flat files for
popular releases like employment and inflation, the Bureau of Economic
Analysis National Income and Product Accounts (NIPA) tables that give
GDP and related accounts, and Federal Reserve Bank of St. Louis Federal
Reserve Economic Data (FRED). They return consistent, tidy data frames
ready for modeling and graphics.

These tools pull the entire flat files of the corresponding set, which
makes them useful for exploring data, doing in-depth research, and also
real-time analysis following the releases. For BLS and BEA these pulls
are updated right as they go live. (FRED is usually updated 40 minutes
later.) Though note for jobs numbers it can take 5-10 minutes right at
launch time; API calls might work better.

The package also includes helpers for date alignment, log-linear
projections, and common macro diagnostics, along with convenience plot
builders for quick publication-quality charts in R tidyverse’s ggplot2
format.

## Installation

``` r

# Install from CRAN
install.packages("tidyusmacro")

# Or the development version from GitHub
devtools::install_github("mtkonczal/tidyusmacro")
```

## Usage

``` r

library(tidyusmacro)

# The full CPI flat file, tidied, with lookup tables joined
cpi <- getBLSFiles(data_source = "cpi", email = "user@example.com")

# FRED series with friendly column names
fred_data <- getFRED(prime_epop = "LNS12300060", cpi = "CPIAUCSL")
```

To see what the package can do, read the [Get
started](https://www.mikekonczal.com/tidyusmacro/articles/tidyusmacro.html)
guide
([`vignette("tidyusmacro")`](https://www.mikekonczal.com/tidyusmacro/articles/tidyusmacro.md)).
Every function is documented in the [reference
index](https://www.mikekonczal.com/tidyusmacro/reference/index.html).

## License

This library is distributed under the MIT License.
