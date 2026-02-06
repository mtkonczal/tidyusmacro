# CLAUDE.md

This file contains context and guidance for Claude Code when working on this project.

## Project Overview

**tidyusmacro** is an R package for downloading and tidying U.S. macroeconomic data from:
- FRED (Federal Reserve Economic Data)
- BLS (Bureau of Labor Statistics) flat files
- BEA NIPA (Bureau of Economic Analysis National Income and Product Accounts)

## Key Architecture Decisions

### getBLSFiles Structure
- BLS flat files have auxiliary lookup tables with compound keys in some cases:
  - CEX `characteristics`: join on `(demographics_code, characteristics_code)`
  - CEX `item`: join on `(subcategory_code, item_code)`
- Metadata columns (`display_level`, `selectable`, `sort_sequence`) are renamed with file prefixes to avoid collisions
- `display_level` is important for hierarchy filtering (keep it, don't drop)

### Pipe Operators
- Currently mixed usage of `%>%` (magrittr) and `|>` (base R)
- Package imports magrittr for `%>%`

## Potential Improvements

### High Priority

- [ ] **Add testthat tests** - No test suite currently exists. Priority tests:
  - `getFRED`: mock API responses, test column naming, test lagged calculation
  - `getBLSFiles`: test join logic, verify no `.x/.y` columns for each data source
  - `logLinearProjection`: test projection accuracy, edge cases

- [ ] **Add vignettes** - Create practical workflow examples:
  - Inflation analysis with PCE data
  - Labor market dashboard with JOLTS/CES
  - Combining multiple data sources

### Medium Priority

- [ ] **Add caching for downloads** - Avoid repeated API calls:
  - Consider `memoise` package or simple file-based cache
  - Add `cache = TRUE/FALSE` parameter to data functions
  - Respect cache expiration (e.g., daily for current data)

- [ ] **FRED API key support** - Current implementation uses CSV endpoint:
  - Add `api_key` parameter to `getFRED()`
  - Higher rate limits with registered key
  - Access to more series metadata

- [ ] **Add more BLS data sources** - Extend `getBLSFiles()`:
  - PPI (Producer Price Index) - prefix `wp`
  - Productivity - prefix `pr`
  - Import/Export prices - prefix `ei`
  - Check file structure for compound keys before adding

### Low Priority

- [ ] **Standardize pipe usage** - Pick `%>%` or `|>` and use consistently

- [ ] **Add progress bars** - For large downloads (CES full data is slow):
  - Consider `cli` package for progress indication
  - Show download progress for each file in `getBLSFiles()`

- [ ] **Consolidate date break functions** - `date_breaks_gg` and `date_breaks_n` overlap:
  - Consider merging or clarifying distinct use cases
  - `date_breaks_gg` returns a function for ggplot
  - `date_breaks_n` returns a vector directly

- [ ] **Document return columns** - Add explicit column documentation:
  - List expected columns in roxygen `@return` for each data source
  - Consider adding a `columns` vignette

## Testing Commands

```r
# Load package for development
devtools::load_all()

# Run documentation
devtools::document()

# Check package
devtools::check()

# Build pkgdown site locally (requires Pandoc)
pkgdown::build_site()
```

## Data Source Reference

### BLS File Mappings
| Source | Prefix | Data File | Key Auxiliary Files |
|--------|--------|-----------|---------------------|
| cpi | cu | data.0.Current | series, item, area |
| eci | ci | data.1.AllData | series, industry, owner, occupation |
| jolts | jt | data.1.AllItems | series, industry, state, dataelement, sizeclass |
| cps | ln | data.1.AllData | series, ages, occupation, race, education |
| ces | ce | data.0.AllCESSeries | series, datatype, supersector, industry |
| cex | cx | data.1.AllData | series, category, characteristics, demographics, item |

### BLS Flat File URL Pattern
```
https://download.bls.gov/pub/time.series/{prefix}/{prefix}.{file}
```
