# Offline tests for the CES revisions table parser using a minimal HTML
# fixture that mirrors the BLS page structure: a three-row header
# (adjustment status / measure / print) with colspan and rowspan, footnote
# markers on months and values, dashes for unpublished cells, and a
# non-monthly summary table that must be skipped.

make_year_table <- function() {
  html <- '
  <table>
    <tr>
      <th rowspan="3">Month</th><th rowspan="3">Year</th>
      <th colspan="6">Seasonally adjusted</th>
      <th colspan="6">Not seasonally adjusted</th>
    </tr>
    <tr>
      <th colspan="3">Over-the-month change</th>
      <th colspan="3">Revision* in over-the-month change</th>
      <th colspan="3">Over-the-month change</th>
      <th colspan="3">Revision* in over-the-month change</th>
    </tr>
    <tr>
      <th>1st</th><th>2nd</th><th>3rd</th>
      <th>2nd - 1st</th><th>3rd - 2nd</th><th>3rd - 1st</th>
      <th>1st</th><th>2nd</th><th>3rd</th>
      <th>2nd - 1st</th><th>3rd - 2nd</th><th>3rd - 1st</th>
    </tr>
    <tr>
      <td>Jan.</td><td>2024</td>
      <td>1,130</td><td>126</td><td>160</td><td>-4</td><td>34</td><td>30</td>
      <td>-2,649</td><td>-2635</td><td>-2630</td><td>14</td><td>5</td><td>19</td>
    </tr>
    <tr>
      <td>Feb. (P)</td><td>2024</td>
      <td>-92 (P)</td><td>&#8212;</td><td>&#8212;</td><td>&#8212;</td><td>&#8212;</td><td>&#8212;</td>
      <td>563</td><td>&#8212;</td><td>&#8212;</td><td>&#8212;</td><td>&#8212;</td><td>&#8212;</td>
    </tr>
  </table>'
  rvest::html_element(rvest::read_html(html), "table")
}

make_summary_table <- function() {
  html <- '
  <table>
    <tr><th rowspan="2">Time Period**</th>
        <th colspan="3">Seasonally adjusted</th>
        <th colspan="3">Not seasonally adjusted</th></tr>
    <tr><th>2nd - 1st</th><th>3rd - 2nd</th><th>3rd - 1st</th>
        <th>2nd - 1st</th><th>3rd - 2nd</th><th>3rd - 1st</th></tr>
    <tr><td>1979 - 2003</td><td>-3</td><td>17</td><td>14</td>
        <td>-4</td><td>16</td><td>12</td></tr>
  </table>'
  rvest::html_element(rvest::read_html(html), "table")
}

test_that("parser extracts values, handles footnotes, commas, and dashes", {
  skip_if_not_installed("rvest")

  out <- ces_revisions_parse_year_table(make_year_table())

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 2)
  expect_equal(out$year, c(2024L, 2024L))
  expect_equal(out$month, c("Jan", "Feb"))
  expect_equal(out$month_num, c(1L, 2L))

  # Comma stripping and negatives
  expect_equal(out$sa_1st, c(1130, -92))
  expect_equal(out$nsa_1st, c(-2649, 563))

  # Level vs revision columns must not be confused ("1st" appears in both)
  expect_equal(out$sa_rev_2nd_minus_1st[1], -4)
  expect_equal(out$sa_rev_3rd_minus_1st[1], 30)
  expect_equal(out$nsa_rev_3rd_minus_1st[1], 19)

  # Em-dash cells (unpublished prints) become NA
  expect_true(all(is.na(out[2, c("sa_2nd", "sa_3rd", "sa_rev_2nd_minus_1st")])))
})

test_that("parser skips non-monthly summary tables", {
  skip_if_not_installed("rvest")

  expect_null(ces_revisions_parse_year_table(make_summary_table()))
})
