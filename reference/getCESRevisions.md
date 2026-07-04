# Download CES Monthly Jobs Revisions

Scrapes the Bureau of Labor Statistics table of monthly Current
Employment Statistics (CES) revisions from
<https://www.bls.gov/web/empsit/cesnaicsrev.htm> and returns a tidy
tibble of first, second, and third prints of the over-the-month change
in total nonfarm employment (1979-present), seasonally adjusted and not
seasonally adjusted, along with the revision deltas between prints.

## Usage

``` r
getCESRevisions(
  source_url = "https://www.bls.gov/web/empsit/cesnaicsrev.htm",
  timeout = 60
)
```

## Arguments

- source_url:

  Character string with the BLS revisions page URL. Defaults to the CES
  NAICS revisions page; override only if BLS moves the page.

- timeout:

  Numeric. Maximum seconds to wait for the page to load in headless
  Chrome before failing. Default 60.

## Value

A tibble with one row per month and columns:

- date:

  Observation month (first of month).

- year:

  Calendar year (integer).

- month:

  Three-letter month abbreviation.

- month_num:

  Month number 1-12 (integer).

- sa_1st, sa_2nd, sa_3rd:

  Seasonally adjusted first, second, and third prints of the
  over-the-month employment change (thousands).

- sa_rev_2nd_minus_1st, sa_rev_3rd_minus_2nd, sa_rev_3rd_minus_1st:

  Seasonally adjusted revisions between prints (thousands).

- nsa_1st, nsa_2nd, nsa_3rd:

  Not seasonally adjusted prints (thousands).

- nsa_rev_2nd_minus_1st, nsa_rev_3rd_minus_2nd, nsa_rev_3rd_minus_1st:

  Not seasonally adjusted revisions (thousands).

- source_url:

  URL the data was scraped from.

- scraped_at:

  UTC timestamp of the download (vintage).

## Details

The BLS revisions page sits behind Akamai bot detection that rejects
requests from R's HTTP stack (`httr`/`curl`) based on their TLS
fingerprint, regardless of the User-Agent header. This function
therefore fetches the page through a headless Chrome browser via the
chromote package, which requires a local installation of Google Chrome
(or another Chromium-based browser). Both chromote and rvest must be
installed to use this function.

Each calendar year on the page is published as its own table with a
three-row header (adjustment status, measure, print). Tables are parsed
with
[`rvest::html_table()`](https://rvest.tidyverse.org/reference/html_table.html),
headers are flattened, and target columns are located by pattern so that
reordering or added columns on the BLS page do not silently misalign
values. If the same year-month appears in more than one table, the most
complete row is kept.

All values are over-the-month changes in thousands of jobs. Recent
months will have `NA` second or third prints until those estimates are
published; revision columns are `NA` until both prints exist.

## Examples

``` r
if (FALSE) { # \dontrun{
  revisions <- getCESRevisions()

  # Average absolute seasonally adjusted revision, first to third print:
  mean(abs(revisions$sa_rev_3rd_minus_1st), na.rm = TRUE)
} # }
```
