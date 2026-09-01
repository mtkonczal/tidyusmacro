# Fetch layer for BLS flat files: URL construction, user-agent handling, the
# retrying downloader, and the directory-listing parser used to discover files
# and their sizes before committing to a download.
#
# Everything here goes through httr::RETRY rather than handing a URL straight
# to readr. Two reasons. First, BLS returns 403 to any request without a
# contact email in the User-Agent (verified 2026-08-31: default libcurl UA
# gets 403, the email gets 200), so the UA has to be explicit rather than
# riding on a process-global option. Second, these downloads are on the
# critical path for release-day pulls, and a single transient failure at 8:31am
# should retry rather than abort the script. This mirrors the hardening
# getFRED() already has in fred_fetch_csv().

bls_base_url <- "https://download.bls.gov/pub/time.series/"

# BLS requires a contact email in the User-Agent header. Kept as a helper so
# there is one place that decides what identifies us to BLS.
#' @importFrom httr user_agent
bls_agent <- function(email) {
  if (is.null(email) || !nzchar(email)) {
    stop("BLS requires a contact email; pass email = to identify yourself.", call. = FALSE)
  }
  httr::user_agent(email)
}

# GET with retries, an HTTP/1.1 fallback for transport-level resets, and a hard
# status check. `dest` writes the body to a file (for the big data files);
# without it the body is returned as text (for the small listing pages).
#' @importFrom httr RETRY GET config status_code content write_disk
bls_get <- function(url, email, dest = NULL, times = 3) {
  ua <- bls_agent(email)
  cfg <- if (is.null(dest)) list() else list(httr::write_disk(dest, overwrite = TRUE))

  resp <- tryCatch(
    do.call(httr::RETRY, c(
      list("GET", url, ua),
      cfg,
      # 403 here means a rejected user agent and 404 a wrong path; neither is
      # transient, so fail fast instead of burning three attempts.
      list(times = times, quiet = TRUE, terminate_on = c(400, 403, 404))
    )),
    error = function(e) e
  )

  if (inherits(resp, "error")) {
    # Transport-level failure rather than an HTTP status. Force HTTP/1.1:
    # in libcurl, http_version = 2 means CURL_HTTP_VERSION_1_1.
    resp <- tryCatch(
      do.call(httr::GET, c(
        list(url, ua, httr::config(http_version = 2)), cfg
      )),
      error = function(e) {
        stop("Could not reach ", url, ": ", conditionMessage(e), call. = FALSE)
      }
    )
  }

  code <- httr::status_code(resp)
  if (code != 200) {
    stop(
      "HTTP ", code, " for ", url,
      if (code == 403) {
        " -- BLS rejects requests without a contact email in the User-Agent."
      } else {
        ""
      },
      call. = FALSE
    )
  }

  if (is.null(dest)) httr::content(resp, as = "text", encoding = "UTF-8") else dest
}

# Read one BLS tab-delimited file as all-character columns; typing is the
# caller's job (see bls_retype()). A code like "0000" must never lose its
# leading zeros to a guessed integer type.
#' @importFrom readr read_tsv cols col_character
bls_read <- function(prefix, file, email, show_progress = FALSE) {
  url <- paste0(bls_base_url, prefix, "/", prefix, ".", file)
  tmp <- tempfile(fileext = ".tsv")
  on.exit(unlink(tmp), add = TRUE)
  bls_get(url, email, dest = tmp)
  readr::read_tsv(
    tmp,
    col_types = readr::cols(.default = readr::col_character()),
    progress = show_progress
  )
}

# Parse the BLS directory listing (an Apache-style autoindex page) into file
# name, byte size, and remote mtime -- the mtime is an exact cache key, should
# an on-disk cache be added later (CLAUDE.md backlog, medium priority).
bls_list_files <- function(prefix, email) {
  url <- paste0(bls_base_url, prefix, "/")
  txt <- bls_get(url, email)
  txt <- gsub("<br>", "\n", txt, fixed = TRUE)

  rx <- "(\\d+)/(\\d+)/(\\d{4})\\s+(\\d+):(\\d+)\\s+(AM|PM)\\s+(\\d+) <A HREF=\"[^\"]*\">([^<]+)</A>"
  m <- regmatches(txt, gregexpr(rx, txt, perl = TRUE))[[1]]
  if (!length(m)) {
    stop(
      "Could not parse the BLS directory listing for '", prefix,
      "'. The listing page format may have changed; sources with a pinned ",
      "`lookups` entry in bls_registry() do not depend on it.",
      call. = FALSE
    )
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

# Size of one file without downloading it, for the max_mb guard when the
# directory listing is unavailable and the lookup list came from the registry.
#' @importFrom httr HEAD headers status_code
bls_head_size <- function(prefix, file, email) {
  url <- paste0(bls_base_url, prefix, "/", prefix, ".", file)
  resp <- tryCatch(
    httr::RETRY("HEAD", url, bls_agent(email), times = 2, quiet = TRUE,
                terminate_on = c(400, 403, 404)),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) != 200) return(NA_real_)
  len <- httr::headers(resp)[["content-length"]]
  if (is.null(len)) NA_real_ else as.numeric(len)
}
