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

## Dating convention

A row stamped month *t* carries the relative importance BLS labels month
*t-1*. That is the weight base for the *t-1* to *t* change, so the row
you want for a change ending in month *t* is the row dated *t* – not a
lag of it.

Verified against the June 2026 news release: the "Relative importance
May 2026" column in Tables 6 and 7 matches the rows dated 2026-06-01 for
all 307 items exactly, and matches the rows dated 2026-05-01 for only 43
of them. The same shift explains why BLS's published "Relative
importance, December YYYY" table is the **January YYYY+1** row of this
file.

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

  The percent change *at the reference month named by `H1`/`HC`*, not
  the current month's change. Read them together with `H1`/`HC`: they
  are the two right-hand columns of news release Tables 6 and 7
  ("Largest (L) or Smallest (S) change since: Date / Percent change").
  The current month's percent change is not in this file; compute it
  from the index.

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

## Reproducing the published effect columns

`W1` and `WC` are BLS's own contribution decomposition, and they equal
the "effect on All Items" columns of Tables 6 and 7 exactly (verified
for June 2026: 269 of 269 and 306 of 306 items, zero deviation). Prefer
them to rolling your own.

If you do need to roll your own – for a custom aggregation BLS does not
publish – the 1-month effect is *not* relative importance times the
seasonally adjusted percent change. Relative importance is defined on
the NSA index, so it has to be put on an SA footing first:

\$\$W1\_{i,t} = I\_{i,t} \times \frac{SA\_{i,t-1} /
NSA\_{i,t-1}}{SA\_{all,t-1} / NSA\_{all,t-1}} \times \frac{SA\_{i,t} /
SA\_{i,t-1} - 1}{1} \times 100\$\$

That reproduces `W1` exactly (270 of 270 items in June 2026). Dropping
the seasonal-factor ratio costs 0.018 percentage points on gasoline and
0.008 on energy – small, but large enough to change a rounded headline
contribution. There is no equally clean reconstruction of `WC`: chaining
twelve monthly NSA effects lands within 0.027 percentage points, which
is why the recommendation is to use BLS's value.

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
