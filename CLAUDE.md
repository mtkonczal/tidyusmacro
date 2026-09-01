# CLAUDE.md

This file contains context and guidance for Claude Code when working on this project.

## Project Overview

**tidyusmacro** is an R package for downloading and tidying U.S. macroeconomic data from:
- FRED (Federal Reserve Economic Data)
- BLS (Bureau of Labor Statistics) flat files
- BEA NIPA (Bureau of Economic Analysis National Income and Product Accounts)

## Key Architecture Decisions

### getBLSFiles Structure
- Two source families, `blsSources()$join_engine`:
  - `"legacy"`: the original 12 sources (`cpi`, `eci`, `cex`, `jolts`, `cps`,
    `ces`, `ces_allemp`, `ces_total`, `averageprice`, `food`, `sae`, `laus`).
    Lookup joins are hand-mapped per source in `R/getBLSFiles.R`, unchanged
    since before the 2026-08 registry refactor. Known compound keys:
    - CEX `characteristics`: join on `(demographics_code, characteristics_code)`
    - CEX `item`: join on `(subcategory_code, item_code)`
  - `"derived"`: every source added since (`ppi`, `ppi_industry`,
    `import_export`, `productivity`, `ecec`, `cpi_w`, `cpi_chained`, plus
    Tier 2-4 registered but not all live-verified). Lookup joins are derived
    by column-name intersection in `R/bls-join.R::bls_build_series()` — the
    key is any `*_code` column shared between a lookup file and `series`,
    which also auto-detects compound keys (e.g. `wp.item` on
    `(group_code, item_code)`). New sources normally need only a
    `bls_registry()` row in `R/bls-registry.R`, not new join code.
- Metadata columns (`display_level`, `selectable`, `sort_sequence`) are renamed with file prefixes to avoid collisions
- `display_level` is important for hierarchy filtering (keep it, don't drop)
- `se`/`su` are deprecated aliases for `sae`/`laus` (warn on use); `su` is a
  real BLS prefix (Chained CPI), which the old alias was squatting on. See
  `bls_deprecated_aliases` in `R/bls-registry.R`.
- Period parsing (`R/bls-period.R::bls_parse_period()`) is shared across all
  sources. BLS period codes are not all monthly/quarterly: `M13`, `S01`,
  `S02`, `S03`, and `Q05` are BLS-computed averages, flagged via `is_average`
  and landing on December of that year (same date as a real Q4/M12 row for
  the same series — expected, not a join bug). Not dropped by default
  (`include_averages = TRUE`): CEX publishes nothing but `A01`.

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

- [x] **Add more BLS data sources** - Done 2026-08-26: `ppi` (`wp`),
  `ppi_industry` (`pc`), `import_export` (`ei`), `productivity` (`pr`),
  `ecec` (`cm`), `cpi_w` (`cw`), `cpi_chained` (`su`). Compound keys are now
  auto-detected (see getBLSFiles Structure above) rather than needing a
  manual check per source. Tier 2-4 sources (`oews`, `bed`, `atus`, etc.) are
  registered in `blsSources()` for discoverability but not all live-verified
  this round — see `recommendations.md` / `BLS_COVERAGE_PLAN.md`.

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
