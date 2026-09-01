# Post-join type restoration.
#
# Every BLS file is read as all-character (see bls_read()), because letting
# readr guess is how a code like "0000" silently becomes the integer 0 and an
# item code like "1E3" becomes 1000. That is the right default for a file whose
# columns are mostly identifiers.
#
# But it is the wrong final answer for the handful of columns that really are
# numbers. `display_level` in particular drives hierarchy filtering, and as
# character it compares lexically: "10" < "2" is TRUE, so a filter meant to keep
# the top of the CPI item tree silently keeps the wrong rows. That is a worse
# failure than a lost leading zero because it produces plausible output.
#
# So: read everything as character, then coerce back a short, explicit list of
# columns, and only where the coercion is lossless. Any column not named here
# stays character, including every *_code, *_text, and *_name column.

# Matches `year`, `begin_year`, `end_year`, `*_display_level`, `*_sort_sequence`.
bls_integer_pattern <- "(^|_)year$|display_level$|sort_sequence$"

# Matches `*_selectable`. BLS writes these as "T"/"F".
bls_logical_pattern <- "selectable$"

bls_as_logical <- function(x) {
  u <- toupper(trimws(x))
  out <- rep(NA, length(x))
  out[u %in% c("T", "TRUE", "Y", "YES")] <- TRUE
  out[u %in% c("F", "FALSE", "N", "NO")] <- FALSE
  out
}

# Coerce `x` with `f`, but only if that introduces no new NAs. Returns the
# original vector unchanged if the coercion would lose information, so a column
# BLS fills with something unexpected degrades to character instead of to NA.
bls_safe_coerce <- function(x, f) {
  if (!is.character(x)) {
    return(x)
  }
  new <- suppressWarnings(f(x))
  if (any(is.na(new) & !is.na(x))) x else new
}

#' Restore numeric and logical types to the columns that are genuinely typed
#' @param df Data frame straight out of the join pipeline, all character except
#'   `value`.
#' @param verbose Logical; report columns that were left as character because
#'   coercion would have introduced NAs.
#' @return `df` with the matched columns coerced.
#' @noRd
bls_retype <- function(df, verbose = TRUE) {
  left_alone <- character(0)

  for (nm in names(df)) {
    if (!is.character(df[[nm]])) next

    if (grepl(bls_integer_pattern, nm)) {
      new <- bls_safe_coerce(df[[nm]], as.integer)
    } else if (grepl(bls_logical_pattern, nm)) {
      new <- bls_safe_coerce(df[[nm]], bls_as_logical)
    } else {
      next
    }

    if (is.character(new)) {
      left_alone <- c(left_alone, nm)
    } else {
      df[[nm]] <- new
    }
  }

  if (verbose && length(left_alone)) {
    message(
      "Left as character (coercion would have introduced NAs): ",
      paste(left_alone, collapse = ", ")
    )
  }

  df
}
