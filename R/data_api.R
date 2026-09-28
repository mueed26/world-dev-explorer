# Backend data layer: a small client for the World Bank Open Data API
# (https://datahelpdesk.worldbank.org/knowledgebase/articles/889392) with
# retries, pagination, an on-disk cache and a stale-cache fallback so the app
# keeps working when the API is slow or offline.

WB_BASE_URL <- "https://api.worldbank.org/v2"

wb_url <- function(path, ...) {
  query <- c(list(format = "json"), list(...))
  query_string <- paste(
    names(query), vapply(query, as.character, character(1)),
    sep = "=", collapse = "&"
  )
  paste0(WB_BASE_URL, "/", path, "?", query_string)
}

# The API reports errors with HTTP 200 and a body like
# [{"message":[{"id":"120","key":"Invalid value","value":"..."}]}].
check_wb_error <- function(response) {
  if (is.data.frame(response) && "message" %in% names(response)) {
    details <- response$message[[1]]
    stop("World Bank API error: ", paste(details$value, collapse = "; "), call. = FALSE)
  }
  invisible(response)
}

wb_request <- function(url, retries = 3, reader = jsonlite::fromJSON) {
  last_error <- NULL
  for (attempt in seq_len(retries)) {
    response <- tryCatch(reader(url, flatten = TRUE), error = function(e) e)
    if (!inherits(response, "error")) {
      return(check_wb_error(response))
    }
    last_error <- response
    if (attempt < retries) Sys.sleep(attempt)
  }
  stop(
    "World Bank API request failed after ", retries, " attempts: ",
    conditionMessage(last_error),
    call. = FALSE
  )
}

# Fetches every page of an endpoint and row-binds the results.
wb_fetch_all <- function(path, ..., per_page = 20000, request = wb_request) {
  first <- request(wb_url(path, ..., per_page = per_page, page = 1))
  pages <- as.integer(first[[1]]$pages)
  rows <- list(first[[2]])
  if (length(pages) == 1 && !is.na(pages) && pages > 1) {
    for (page in 2:pages) {
      rows[[page]] <- request(wb_url(path, ..., per_page = per_page, page = page))[[2]]
    }
  }
  rows <- Filter(function(r) is.data.frame(r) && nrow(r) > 0, rows)
  if (length(rows) == 0) return(NULL)
  dplyr::bind_rows(rows)
}

empty_indicator_frame <- function() {
  data.frame(iso3 = character(), year = integer(), value = numeric(), stringsAsFactors = FALSE)
}

parse_indicator <- function(rows) {
  if (is.null(rows) || nrow(rows) == 0) return(empty_indicator_frame())
  out <- data.frame(
    iso3 = as.character(rows$countryiso3code),
    year = as.integer(rows$date),
    value = suppressWarnings(as.numeric(rows$value)),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$iso3) & nzchar(out$iso3) & !is.na(out$value), , drop = FALSE]
  out <- out[order(out$iso3, out$year), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Keeps real countries only; regional and income-group aggregates are dropped.
parse_countries <- function(rows) {
  out <- data.frame(
    iso3 = rows$id,
    country = rows$name,
    region = trimws(rows$region.value),
    income = trimws(rows$incomeLevel.value),
    stringsAsFactors = FALSE
  )
  out <- out[out$region != "Aggregates" & nzchar(out$region), , drop = FALSE]
  out <- out[order(out$country), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# ---- Caching ---------------------------------------------------------------

cache_dir <- function() {
  Sys.getenv("WDE_CACHE_DIR", file.path(getwd(), "cache"))
}

cache_path <- function(key, dir = cache_dir()) {
  file.path(dir, paste0(gsub("[^A-Za-z0-9_.-]", "_", key), ".rds"))
}

# Returns the cached value when it is younger than `ttl_hours`, otherwise
# calls `fetch()` and stores the result. If fetching fails but an expired copy
# exists, the expired copy is returned with a warning instead of an error.
with_cache <- function(key, fetch, ttl_hours = 24, dir = cache_dir()) {
  path <- cache_path(key, dir)
  age_hours <- if (file.exists(path)) {
    as.numeric(difftime(Sys.time(), file.mtime(path), units = "hours"))
  } else {
    Inf
  }
  if (age_hours < ttl_hours) return(readRDS(path))

  value <- tryCatch(fetch(), error = function(e) e)
  if (!inherits(value, "error")) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    saveRDS(value, path)
    return(value)
  }
  if (file.exists(path)) {
    warning("Using stale cache for '", key, "': ", conditionMessage(value), call. = FALSE)
    return(readRDS(path))
  }
  stop(value)
}

# ---- Public API used by the Shiny modules ---------------------------------

get_countries <- function() {
  with_cache("countries", function() {
    parse_countries(wb_fetch_all("country", per_page = 400))
  }, ttl_hours = 24 * 7)
}

get_indicator <- function(indicator, start = 2000, end = current_year()) {
  key <- paste("indicator", indicator, start, end, sep = "_")
  values <- with_cache(key, function() {
    parse_indicator(wb_fetch_all(
      paste0("country/all/indicator/", indicator),
      date = paste0(start, ":", end)
    ))
  })
  out <- merge(values, get_countries(), by = "iso3")
  out$indicator <- rep(indicator, nrow(out))
  out <- out[order(out$country, out$year), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# In-memory memo shared by all sessions so each indicator is read once per
# process, on top of the on-disk cache.
data_store <- function(loader = get_indicator) {
  memo <- new.env(parent = emptyenv())
  function(indicator) {
    if (is.null(memo[[indicator]])) memo[[indicator]] <- loader(indicator)
    memo[[indicator]]
  }
}
