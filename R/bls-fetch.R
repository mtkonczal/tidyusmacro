# Fetch layer for BLS flat files: URL construction, user-agent handling, and
# the directory-listing parser used to discover files and their sizes before
# committing to a download. Shared by getBLSFiles() (legacy + registry
# sources) and blsFiles().

bls_base_url <- "https://download.bls.gov/pub/time.series/"

# BLS requires a contact email in the User-Agent header; restore the caller's
# option on exit per CRAN policy (options(HTTPUserAgent=) is process-global).
bls_with_agent <- function(email, expr) {
  old <- options(HTTPUserAgent = email)
  on.exit(options(old), add = TRUE)
  force(expr)
}

# Read one BLS tab-delimited file as all-character columns; typing is the
# caller's job; a code like "0000" must never lose its leading zeros to a
# guessed integer type.
#' @importFrom readr read_tsv cols col_character
bls_read <- function(prefix, file, email, show_progress = FALSE) {
  url <- paste0(bls_base_url, prefix, "/", prefix, ".", file)
  bls_with_agent(email, {
    readr::read_tsv(
      url,
      col_types = readr::cols(.default = readr::col_character()),
      progress = show_progress
    )
  })
}

# Parse the BLS directory listing (an Apache-style autoindex page) into file
# name, byte size, and remote mtime -- the mtime is an exact cache key, should
# an on-disk cache be added later (CLAUDE.md backlog, medium priority).
bls_list_files <- function(prefix, email) {
  url <- paste0(bls_base_url, prefix, "/")
  txt <- bls_with_agent(email, paste(readLines(url, warn = FALSE), collapse = "\n"))
  txt <- gsub("<br>", "\n", txt, fixed = TRUE)

  rx <- "(\\d+)/(\\d+)/(\\d{4})\\s+(\\d+):(\\d+)\\s+(AM|PM)\\s+(\\d+) <A HREF=\"[^\"]*\">([^<]+)</A>"
  m <- regmatches(txt, gregexpr(rx, txt, perl = TRUE))[[1]]
  if (!length(m)) {
    stop("Could not parse the BLS directory listing for '", prefix, "'.", call. = FALSE)
  }
  g <- regmatches(m, regexec(rx, m, perl = TRUE))

  # regexec puts the whole match at [[1]], so capture group n is at [[n + 1]].
  pick <- function(i) vapply(g, function(x) x[[i + 1L]], character(1))
  hour <- as.integer(pick(4))
  ampm <- pick(6)
  hour <- ifelse(ampm == "PM" & hour < 12, hour + 12, ifelse(ampm == "AM" & hour == 12, 0, hour))

  out <- data.frame(
    file = pick(8),
    bytes = as.numeric(pick(7)),
    modified = as.POSIXct(
      sprintf(
        "%04d-%02d-%02d %02d:%02d:00",
        as.integer(pick(3)), as.integer(pick(1)), as.integer(pick(2)),
        hour, as.integer(pick(5))
      ),
      tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
  out$is_data <- grepl("\\.data\\.", out$file, ignore.case = TRUE)
  # Strip the "{prefix}." stem so it can be passed straight to file =.
  out$stem <- sub(paste0("^", prefix, "\\."), "", out$file, ignore.case = TRUE)
  out[order(!out$is_data, out$file), ]
}
