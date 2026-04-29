library(readr)
library(dplyr)

dallasTrimPCEcomponents <- read_csv(
  "data-raw/dallas_trim_pce_components.csv",
  col_types = cols(
    dallas_idx  = col_integer(),
    name        = col_character(),
    series_code = col_character(),
    line_no     = col_integer(),
    bea_label   = col_character()
  )
) |> arrange(dallas_idx)

stopifnot(
  nrow(dallasTrimPCEcomponents) == 177,
  !any(is.na(dallasTrimPCEcomponents$series_code)),
  !any(is.na(dallasTrimPCEcomponents$line_no)),
  !any(duplicated(dallasTrimPCEcomponents$line_no)),
  93L %in% dallasTrimPCEcomponents$dallas_idx,
  !(94L %in% dallasTrimPCEcomponents$dallas_idx)
)

usethis::use_data(dallasTrimPCEcomponents, overwrite = TRUE)
