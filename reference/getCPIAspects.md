# Download CPI Metadata (Aspect) Files from BLS

Downloads the BLS CPI "aspect" flat file, which carries the monthly
metadata that accompanies each published CPI series: relative importance
(weights), BLS's own contribution-to-the-all-items-change decomposition,
median standard errors, seasonal factors, and published percent changes.

## Usage

``` r
getCPIAspects(email, survey = c("cu", "cw"), aspect_type = NULL)
```

## Arguments

- email:

  Character string with your email address. Required by BLS for
  identifying users; set as the HTTP User-Agent header.

- survey:

  Character string, either `"cu"` (CPI-U, the default) or `"cw"`
  (CPI-W).

- aspect_type:

  Optional character vector of aspect codes to keep (e.g. `"I"` for
  relative importance). `NULL` (the default) returns every aspect type.

## Value

A tibble with one row per series/month/aspect_type and columns:

- series_id:

  Full BLS series identifier

- area_code, item_code, seasonal, periodicity_code:

  Components parsed out of `series_id`

- year, period, date:

  Observation month

- aspect_type:

  Aspect code (see Details)

- value:

  Published value as a character string, exactly as distributed

- value_num:

  Numeric version of `value`; `NA` for the text aspect types `H1` and
  `HC`

- footnote_codes:

  BLS footnote codes, if any

## Details

The aspect file lives at
`https://download.bls.gov/pub/time.series/cu/cu.aspect` and is restamped
with every CPI release. It is not described in `cu.txt` (that file was
last revised in February 2018; the aspect files were added in November
2024); the documentation is on a separate BLS fact sheet.

Aspect types, and the seasonal-adjustment domain each one is published
on:

- `I`:

  Relative importance, monthly. NSA series only (`CUUR`/`CWUR`), March
  2012 forward.

- `I1`:

  End-of-year relative importance. NSA only, Dec 2020 forward.

- `F`:

  Seasonal factor. SA series (`CUSR`).

- `W1`:

  Effect on the 1-month all items change, in percentage points.
  Published on the *seasonally adjusted* series.

- `WC`:

  Effect on the 12-month all items change, in percentage points.
  Published on the *not seasonally adjusted* series.

- `V1`, `VC`:

  Published 1-month (SA) and 12-month (NSA) percent changes.

- `M1`, `MC`:

  Median standard error of the 1-month (SA) and 12-month (NSA) percent
  change.

- `H1`, `HC`:

  Text notes flagging largest/smallest change since a reference date.
  Character, not numeric.

Note that `W1`/`V1`/`M1` attach to the SA series and `WC`/`VC`/`MC` to
the NSA series, matching BLS's convention of reporting 1-month changes
seasonally adjusted and 12-month changes not seasonally adjusted. Join
those on the full `series_id`. Relative importance (`I`) is the
exception: it is defined only on the NSA series but describes the item,
so it applies to the SA series too and should be joined on `area_code` +
`item_code` + `date`. This is what
[`getBLSFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md)`("cpi", ...)`
does.

## See also

[`getBLSFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md),
which attaches relative importance to CPI index values directly.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Everything
  aspects <- getCPIAspects("your.email@example.com")

  # BLS's own contribution decomposition, to check your own against
  effects <- getCPIAspects("your.email@example.com", aspect_type = c("W1", "WC"))
} # }
```
