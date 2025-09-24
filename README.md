# Economic Data Processing R Library

Utilities to retrieve and tidy U.S. macroeconomic data series
    from public government data providers. Functions streamline access to series
    from the Federal Reserve Bank of St. Louis Federal Reserve Economic Data (FRED),
    the Bureau of Labor Statistics (BLS) flat files, and the Bureau of Economic
    Analysis (BEA) National Income and Product Accounts (NIPA) tables, then return
    consistent, tidy data frames ready for modeling and graphics. The package includes
    helpers for date alignment, log-linear projections, and common macro diagnostics,
    along with convenience plot builders for quick publication-quality charts.
    
## Functions and Examples

### 1. `getBLSFiles`
- **Purpose**: Downloads and processes data from the Bureau of Labor Statistics (BLS).
- **Example**:
```r
bls_data <- getBLSFiles(data_source = "cpi", email = "user@example.com")
```

### 2. `getFRED`
- **Purpose**: Downloads and merges economic data series from the Federal Reserve Economic Data (FRED).
- **Example**:
```r
fred_data <- getFRED(variables = prime_epop = "LNS12300060", cpi = "CPIAUCSL"))
```

### 3. `getPCEInflation`
- **Purpose**: Loads and processes Personal Consumption Expenditures (PCE) data.
- **Example**:
```r
pce_data <- getPCEInflation("M")
```
- The parameter `"M"` specifies monthly data frequency. Use `"Q"` for quarterly data.

### 4. `getNIPAFiles`
- **Purpose**: Downloads and formats BEA NIPA data flate files, either monthly or quarterly values.
- **Example**:
```r
nipa_data <- getNIPAFiles(type = "Q")
```

### 4. `logLinearProjection`
- **Purpose**: Performs log-linear projections on historical data. Must be called within dplyr verbs.
- **Example**:
```r
projected_values <- logLinearProjection(date_col = date, value_col = gdp, start_date = "2020-01-01", end_date = "2021-01-01")
```

## Dependencies

- dplyr
- tidyr
- readr
- purrr
- rlang
- stringi

## License

This library is distributed under the MIT License. The MIT license permits reuse of software under permissive conditions, provided that all copies include the license terms and the copyright notice.

