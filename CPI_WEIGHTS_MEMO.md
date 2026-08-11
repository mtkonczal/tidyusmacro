# CPI weights: they are in the flat-file directory, and they're monthly

## Short version

They are hiding there. `download.bls.gov/pub/time.series/cu/` has a file called
**`cu.aspect`** (31 MB, restamped with every CPI release). It is undocumented in
`cu.txt` — which is why you never saw it, `cu.txt` was last touched in Feb 2018 and
the aspect files were added in **November 2024**. The documentation lives on a
separate fact sheet instead.

`cu.aspect` contains **monthly relative importance for every CPI-U series, keyed on
`series_id`, back to March 2012.** There is a matching `cw.aspect` for CPI-W.

That kills the manual download, kills the name-matching join, and upgrades you from
one annual December number to a real monthly series.

## What's in the file

Tab-delimited, same shape as the `cu.data.*` files:
`series_id | year | period | aspect_type | value | footnote_codes`

| Code | Meaning | Coverage |
|------|---------|----------|
| **I** | **Relative importance (monthly)** | CPI-U & CPI-W, **Mar 2012 →** |
| I1 | End-of-year relative importance | CPI-U & CPI-W, Dec 2020 → |
| F | Seasonal factor | CPI-U & CPI-W |
| **W1** | **1-month effect on all items** | CPI-U, Mar 2012 → |
| **WC** | **12-month effect on all items** | CPI-U, Mar 2012 → |
| V1 / VC | Prior 1-month / 12-month percent change | CPI-U |
| M1 / MC | Median standard error, 1-mo / 12-mo change | CPI-U |
| H1 / HC | "Largest/smallest change since" reference | CPI-U |

Two things worth flagging beyond the weights themselves:

- **W1 and WC are BLS's own contribution decomposition.** The "energy contributed
  0.14pp to the monthly increase" number, computed in-house with the actual
  production weights. Free cross-check on everything in `subtract_cpi_items()`.
- **M1 and MC are median standard errors.** You can put real error bands on the
  1-month prints instead of hand-waving about noise.

Same data is also on the public API with `"aspects": "true"` if you'd rather not
carry a 31 MB file.

## Three bugs in the current pipeline

I read `scripts/01_download_cpi_data.R` and `weights/inflation_weights.csv`
(1,345 rows) and checked the values against the published BLS tables.

**1. The 2026 weights are missing, so this year is running on Dec-2024 weights.**
The CSV stops at `year_weight = 2025`, and `pmin(year, latest_weight_year)` silently
maps all 2026 observations onto it. The Dec-2025 table has been out since January.
The drift is not cosmetic:

| Item | You're using (Dec 2024) | Actual (Dec 2025) | Off by |
|------|------------------------|-------------------|--------|
| New vehicles | 4.393 | 3.838 | **+14%** |
| Used cars and trucks | 2.391 | 2.759 | **−13%** |
| Energy | 6.216 | 6.383 | −2.6% |
| Shelter | 35.483 | 35.625 | −0.4% |

Silently, with no error — `pmin()` degrades quietly by design.

**2. Everything before 2022 uses Dec-2021 weights.** `base_weight` is the
`year_weight == 2022` block, applied to the full history. For anything reaching back
past 2021 this is materially wrong — the Dec-2021 basket has gasoline at 4.096 and
used cars at 3.726, both near post-COVID peaks.

**3. The 2022 block is a different item universe than 2023–2025.** 382 items vs 321.
The 2022 vintage carries analytic aggregates the later vintages dropped
(`All items less food and shelter`, `Bacon and related products`, ~60 others); the
later vintages carry `Unsampled *` items the 2022 block lacks. Since the join is
`left_join(..., by = "item_name")` with a 2022 fallback, an item that exists only in
2022 gets a **2021 weight applied to 2025 data**, and an `Unsampled` item gets `NA`
for every pre-2022 year. Both pass through without warning.

**Not a bug, but undocumented and worth a comment in the code:** your `year_weight`
is offset one year from BLS's table naming. Your `year_weight = 2025` block is
BLS's December **2024** table — I verified every value matches exactly (Food 13.691,
Energy 6.216, Shelter 35.483, OER 26.282, Gasoline 2.902, New vehicles 4.393, Used
2.391). Same for 2024 ↔ Dec 2023. That's a defensible start-of-year convention, but
it's the kind of thing that bites in six months.

## Recommendation

Swap `weights/inflation_weights.csv` for `cu.aspect`, joined on
`area_code + item_code + year + period`. `scripts/01_download_cpi_data.R` becomes:

```r
cpi_data <- getBLSFiles("cpi", "rortybomb@gmail.com")

source("scripts/01b_download_cpi_weights.R")
aspects     <- get_cpi_aspects("cu", refresh = TRUE)
cpi_weights <- get_cpi_weights_monthly(aspects)
cpi_data    <- attach_cpi_weights(cpi_data, cpi_weights)
```

Three notes on the join:

- **Join on `item_code`, not `item_name`.** BLS renames items; the codes are stable.
- **Ignore the `seasonal` flag when joining.** Relative importance is defined on the
  NSA series (`CUUR…`), but applies to the item regardless of adjustment. Your main
  analysis filters `seasonal == "S"`, so a naive `series_id` join returns all `NA`.
  The attached function strips seasonal and joins on area + item.
- **Use `weight_lag` for 1-month contributions.** Contribution to month *t* is based
  on the RI at *t−1*. The function returns both columns.

`attach_cpi_weights()` also sets `weight_is_imputed` wherever it had to back-fill,
so the pre-2012 fallback is visible instead of silent.

## The pre-2012 gap

`cu.aspect` starts March 2012. Two options for going back further, both one-time:

1. **Cost weights, Dec 2011 → present.** `bls.gov/web/cpi/cpi-u-historical-cost-weights.xlsx`.
   Dollar amounts rather than percentages, which makes them *additive* — genuinely
   better than relative importance for aggregation. BLS notes they're produced
   outside the production system, so treat as slightly lower-grade.
2. **The relative importance archive, back to 1947.** Annual December tables:
   `ri-archive-2010-2019.zip`, `…2000-2009.zip`, `…1990-1999.zip`,
   `…1987-1989.zip`, and `historical-relative-importance-1947-1986.xlsx`. These are
   still name-keyed spreadsheets, so it's the same parsing pain you have now — but
   as a one-time backfill script rather than a monthly chore.

If you want monthly precision pre-2012 rather than a December step function, you can
interpolate: within a weight year, RI drifts deterministically with relative prices,
so an item's December RI plus its index level and the all-items index recovers the
intervening months. You already have the index levels.

## One caveat

The BLS download host is blocked from my sandbox, so I could not open `cu.aspect`
and read rows — everything above about its contents comes from BLS's fact sheet plus
the directory listing. The coverage dates (Mar 2012 for `I`, Dec 2020 for `I1`) are
BLS's stated dates, not something I confirmed against the bytes.

`validate_cpi_weights(aspects)` in the attached script checks all of it in one call:
actual coverage by aspect type, whether All items sums to 100 every month, and a
December-by-December diff against your existing CSV. Run that before you delete
anything.

## Sources

- [Using CPI Metadata (Aspect) Files](https://www.bls.gov/cpi/factsheets/using-cpi-metadata-aspect-files.htm)
- [download.bls.gov/pub/time.series/cu/](https://download.bls.gov/pub/time.series/cu/)
- [Relative Importance and Weight Information](https://www.bls.gov/cpi/tables/relative-importance/home.htm)
- [CPI Cost Weights](https://www.bls.gov/cpi/tables/relative-importance/cost-weights.htm)
- [Relative importance, December 2025](https://www.bls.gov/cpi/tables/relative-importance/2025.htm) / [December 2024](https://www.bls.gov/cpi/tables/relative-importance/2024.htm) / [December 2023](https://www.bls.gov/cpi/tables/relative-importance/2023.htm)
- [BLS Data API features](https://www.bls.gov/bls/api_features.htm)
