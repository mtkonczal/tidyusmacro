## tidyusmacro 0.2.0

This is a feature update. It adds four exported functions
(`getDallasTrimPCE()`, `getUnrateFRED()`, `date_breaks_gg()`,
`date_breaks_n()`), one dataset, and fixes a download failure in
`getFRED()` by switching to `httr::GET()`.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Found the following (possibly) invalid URLs:
    URL: https://download.bls.gov/pub/time.series/
    Status: 403

  This URL is valid. The Bureau of Labor Statistics returns 403 Forbidden
  to automated (non-browser) requests, including the URL checker. The page
  loads normally in a browser.

## Examples

Examples that download data from government servers (BLS, BEA, FRED,
Dallas Fed) are wrapped in \dontrun{}. BLS in particular rejects requests
from automated agents without a contact email, so these examples cannot
run reliably on check machines.
