# CLAUDE.md

This file contains context and guidance for Claude Code when working on
this project.

## Project Overview

**tidyusmacro** is an R package for downloading and tidying U.S.
macroeconomic data from: - FRED (Federal Reserve Economic Data) - BLS
(Bureau of Labor Statistics) flat files - BEA NIPA (Bureau of Economic
Analysis National Income and Product Accounts)

## Key Architecture Decisions

### getBLSFiles Structure

- **One join engine.** `bls_build_series()` (`R/bls-join.R`) derives
  each lookup’s join key by column-name intersection with `series`: the
  key is any `*_code` column shared between a lookup file and `series`.
  It auto-detects compound keys (e.g. `wp.item` on
  `(group_code, item_code)`, CEX’s `characteristics` on
  `(demographics_code, characteristics_code)`) and it subsumes the two
  exceptions the old hand-mapped list carried (`ce.datatype` keys on
  `data_type_code`, `la.state_region_division` on `srd_code`) without
  being told, because it reads column names rather than file stems.
  Adding a source is a `bls_registry()` row, not new join code.
- The hand-mapped `legacy` engine that served the original ten sources
  was deleted 2026-08-31 after a live before/after diff over all ten
  confirmed the derived rule reproduces it. That diff lives in
  `verification/` (gitignored); `verification/capture.R` and `compare.R`
  re-run it.
- **Pinned lookups.** `bls_registry()$lookups` pins the lookup stems for
  every tier 1 source, captured live 2026-08-31. When pinned,
  [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
  does not need the BLS HTML directory listing to discover lookups, so a
  change to that page cannot take down a release-day pull; the listing
  is then used only for the `max_mb` size guard and its failure
  downgrades to a warning. Refresh with
  `bls_lookup_candidates(bls_list_files(prefix, email))$stem`.
- **All-character reads, then selective re-typing.** `bls_read()` forces
  `col_character` so a code like `"0000"` never becomes `0`.
  `bls_retype()` (`R/bls-types.R`) then restores integer/logical types
  to the short list of columns that are genuinely typed: `year`,
  `*_display_level`, `*_sort_sequence`, `*_selectable`. This matters
  most for `display_level`, which drives hierarchy filtering: as
  character it compares lexically, so `"10" < "2"` is TRUE and a filter
  silently keeps the wrong rows. Coercion is skipped for any column
  where it would introduce NAs.
- All BLS HTTP goes through `bls_get()` (`R/bls-fetch.R`):
  [`httr::RETRY`](https://httr.r-lib.org/reference/RETRY.html), an
  HTTP/1.1 fallback for transport resets, and a hard status check. BLS
  returns 403 to any request without a contact email in the User-Agent
  (verified 2026-08-31), so the UA is passed explicitly rather than
  through `options(HTTPUserAgent=)`.
- Metadata columns (`display_level`, `selectable`, `sort_sequence`) are
  renamed with file prefixes to avoid collisions
- `display_level` is important for hierarchy filtering (keep it, don’t
  drop)
- `se`/`su` are deprecated aliases for `sae`/`laus` (warn on use); `su`
  is a real BLS prefix (Chained CPI), which the old alias was squatting
  on. See `bls_deprecated_aliases` in `R/bls-registry.R`.

### Period parsing

`R/bls-period.R::bls_parse_period()` is shared by
[`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)
and
[`getCPIAspects()`](https://www.mikekonczal.com/tidyusmacro/reference/getCPIAspects.md).
BLS period codes are not all monthly/quarterly: `M13`, `S01`, `S02`,
`S03`, and `Q05` are BLS-computed averages, flagged via `is_average`.

- **Month** is the end of the period (`Q01` -\> March). Averages land in
  the last month they cover: `M13`/`S03`/`Q05`/`A01` in December, `S01`
  in June.
- **Day** separates observed from computed. Observed values are dated
  the first of the month, matching `getFRED`/`getNIPAFiles`. Averages
  are dated the last day of their terminal month (`2024-12-31` for
  `M13`, `2024-06-30` for `S01`). Without this an annual average shares
  a `Date` with the real December observation and a stray
  `group_by(date)` double-counts silently; there is no month an average
  can occupy that an observed month does not already own, so the day is
  the only free dimension.
- Averages still share a date with each other (`M13`, `S02`, `S03` all
  land on December 31). Deliberate: they are all averages, so
  `is_average`/`freq` separates them. The full key is
  `(series_id, date, freq)`.
- Not dropped by default (`include_averages = TRUE`): CEX publishes
  nothing but `A01`. Passing `FALSE` on such a source now errors rather
  than returning zero rows.

### Pipe Operators

- Currently mixed usage of `%>%` (magrittr) and `|>` (base R)
- Package imports magrittr for `%>%`

## Potential Improvements

### High Priority

**Add testthat tests** - No test suite currently exists. Priority tests:

- `getFRED`: mock API responses, test column naming, test lagged
  calculation
- `getBLSFiles`: test join logic, verify no `.x/.y` columns for each
  data source
- `logLinearProjection`: test projection accuracy, edge cases

**Add vignettes** - Create practical workflow examples:

- Inflation analysis with PCE data
- Labor market dashboard with JOLTS/CES
- Combining multiple data sources

### Medium Priority

**Add caching for downloads** - Avoid repeated API calls:

- Consider `memoise` package or simple file-based cache
- Add `cache = TRUE/FALSE` parameter to data functions
- Respect cache expiration (e.g., daily for current data)

**FRED API key support** - Current implementation uses CSV endpoint:

- Add `api_key` parameter to
  [`getFRED()`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md)
- Higher rate limits with registered key
- Access to more series metadata

**Add more BLS data sources** - Done 2026-08-26: `ppi` (`wp`),
`ppi_industry` (`pc`), `import_export` (`ei`), `productivity` (`pr`),
`ecec` (`cm`), `cpi_w` (`cw`), `cpi_chained` (`su`). Compound keys are
now auto-detected (see getBLSFiles Structure above) rather than needing
a manual check per source. Tier 2 and Tier 3 (`oews`, `bed`, `atus`,
etc., 16 sources) live-verified 2026-08-31 — all download and join
cleanly except `osh_characteristics` (2.9 GB, intentionally gated behind
`max_mb`, not pulled routinely). Tier 4 is discontinued surveys,
registered for discoverability only — see `recommendations.md` /
`BLS_COVERAGE_PLAN.md`.

### Low Priority

**Standardize pipe usage** - Pick `%>%` or `|>` and use consistently

**Add progress bars** - For large downloads (CES full data is slow):

- Consider `cli` package for progress indication
- Show download progress for each file in
  [`getBLSFiles()`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)

**Consolidate date break functions** - `date_breaks_gg` and
`date_breaks_n` overlap:

- Consider merging or clarifying distinct use cases
- `date_breaks_gg` returns a function for ggplot
- `date_breaks_n` returns a vector directly

**Document return columns** - Add explicit column documentation:

- List expected columns in roxygen `@return` for each data source
- Consider adding a `columns` vignette

## Testing Commands

``` r

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

Full, current list:
[`blsSources()`](https://www.mikekonczal.com/tidyusmacro/reference/blsSources.md).
A few representative examples:

| Source | Prefix | Data File | Key Auxiliary Files |
|----|----|----|----|
| cpi | cu | data.0.Current | series, item, area, base, periodicity, seasonal |
| eci | ci | data.1.AllData | series, industry, owner, occupation, subcell, estimate, periodicity, area, seasonal |
| jolts | jt | data.1.AllItems | series, industry, state, dataelement, sizeclass, area, ratelevel, seasonal |
| ces | ce | data.0.AllCESSeries | series, datatype, supersector, industry, seasonal |
| cps | ln | data.1.AllData | series, plus 35 lookups |
| cex | cx | data.1.AllData | series, category, characteristics, demographics, item, subcategory, process |
| ppi | wp | data.0.Current | series, group, item (compound key), seasonal |

### BLS Flat File URL Pattern

    https://download.bls.gov/pub/time.series/{prefix}/{prefix}.{file}
