# tidyusmacro: Downloading and Cleaning U.S. Macroeconomic Data

Utilities to retrieve and tidy U.S. macroeconomic data from public
government data providers, returning consistent tibbles ready for
modeling and graphics.

## Data download functions

- [`getFRED`](https://www.mikekonczal.com/tidyusmacro/reference/getFRED.md):

  One or more series from FRED, merged by date.

- [`getBLSFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getBLSFiles.md):

  BLS flat files (CPI, CES, CPS, JOLTS, ECI, CEX, and others), merged
  with their lookup tables.

- [`getNIPAFiles`](https://www.mikekonczal.com/tidyusmacro/reference/getNIPAFiles.md):

  BEA NIPA flat files, expanded to one row per table line.

- [`getPCEInflation`](https://www.mikekonczal.com/tidyusmacro/reference/getPCEInflation.md):

  PCE price indices with nominal-share weights and growth rates.

- [`getDallasTrimPCE`](https://www.mikekonczal.com/tidyusmacro/reference/getDallasTrimPCE.md):

  Component panel underlying the Dallas Fed trimmed-mean PCE inflation
  rate.

- [`getUnrateFRED`](https://www.mikekonczal.com/tidyusmacro/reference/getUnrateFRED.md):

  Unemployment rate built from FRED levels.

## Analysis and plotting helpers

- [`logLinearProjection`](https://www.mikekonczal.com/tidyusmacro/reference/logLinearProjection.md):

  Log-linear trend projection for use inside
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html).

- [`date_breaks_gg`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_gg.md),
  [`date_breaks_n`](https://www.mikekonczal.com/tidyusmacro/reference/date_breaks_n.md):

  Date axis breaks anchored to the data.

- [`theme_esp`](https://www.mikekonczal.com/tidyusmacro/reference/esp_theme.md):

  Economic Security Project ggplot2 theme and color scales.

## Included datasets

[`cesDiffusionIndex`](https://www.mikekonczal.com/tidyusmacro/reference/cesDiffusionIndex.md),
[`dallasTrimPCEcomponents`](https://www.mikekonczal.com/tidyusmacro/reference/dallasTrimPCEcomponents.md).

## See also

Useful links:

- <https://github.com/mtkonczal/tidyusmacro>

- <https://www.mikekonczal.com/tidyusmacro/>

- Report bugs at <https://github.com/mtkonczal/tidyusmacro/issues>

## Author

**Maintainer**: Mike Konczal <konczal@gmail.com>

Authors:

- Mike Konczal <konczal@gmail.com>
