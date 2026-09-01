## tidyusmacro 0.3.0

This release rewrites the BLS flat-file layer. It fixes two data-correctness
bugs, unifies two divergent code paths into one, and makes release-day
downloads retry rather than abort.

The user-visible changes are listed under "Breaking changes" in NEWS.md. In
short: `getBLSFiles()` now joins every lookup table BLS publishes for a survey
rather than a hand-maintained subset (additive columns only); BLS files are
read as character and then selectively re-typed, so identifier codes keep their
leading zeros; and BLS-computed average rows (period codes `M13`, `S01`-`S03`,
`Q05`, `A01`) are dated the last day of the period they cover instead of
sharing a date with the observed December value.

There are no reverse dependencies on CRAN.

## Test environments

* local macOS 15.6 (darwin25.6.0), R 4.4.2
  `R CMD check --as-cran` on the built tarball, with
  `_R_CHECK_CRAN_INCOMING_` and `_R_CHECK_CRAN_INCOMING_REMOTE_` set to TRUE.

## R CMD check results

0 errors | 0 warnings | 2 notes

* checking CRAN incoming feasibility ... NOTE
  Found the following (possibly) invalid URLs:
    URL: https://download.bls.gov/pub/time.series/
      From: man/getBLSFiles.Rd
      Status: 403
    URL: https://www.bls.gov/web/empsit/cesnaicsrev.htm
      From: man/getCESRevisions.Rd
      Status: 403

  Both URLs are valid and current. The Bureau of Labor Statistics returns 403
  Forbidden to programmatic requests that do not carry a contact email in the
  User-Agent header, which is what the URL checker sends. Verified while
  preparing this submission: both URLs return HTTP 200 when the request
  carries a contact email, and both load normally in a browser. This is
  exactly why the package requires an `email` argument for every BLS download,
  and it is the same note reported for the 0.2.0 submission.

* checking for future file timestamps ... NOTE
    unable to verify current time

  This is the check machine being unable to reach the time server used by
  that test, not a property of the package.

## Examples and tests

Examples that download data from government servers (BLS, BEA, FRED, Dallas
Fed) are wrapped in `\dontrun{}`. BLS in particular rejects requests from
automated agents without a contact email, so these examples cannot run
reliably on check machines.

The test suite is offline. Tests that would touch the network are guarded with
`testthat::skip_on_cran()`. The parsing, registry, and type-coercion logic that
carries the correctness risk in this release is covered by unit tests that use
no network at all.

The vignette's data-download chunks are set `eval = FALSE` and `purl = FALSE`,
so neither rendering nor `R CMD check`'s vignette tangle makes a network call.
