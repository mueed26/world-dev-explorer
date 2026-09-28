test_that("wb_url builds a JSON query string", {
  url <- wb_url("country/all/indicator/SP.POP.TOTL", date = "2000:2020", per_page = 100)
  expect_equal(
    url,
    "https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL?format=json&date=2000:2020&per_page=100"
  )
})

test_that("parse_indicator returns tidy, sorted, non-missing rows", {
  raw <- read_fixture("indicator_sample.json")
  out <- parse_indicator(raw[[2]])

  expect_named(out, c("iso3", "year", "value"))
  expect_setequal(unique(out$iso3), c("CHN", "IND", "PAK"))
  expect_type(out$year, "integer")
  expect_false(anyNA(out$value))
  expect_equal(out, out[order(out$iso3, out$year), ], ignore_attr = TRUE)
})

test_that("parse_indicator handles empty responses", {
  expect_equal(nrow(parse_indicator(NULL)), 0)
})

test_that("parse_countries drops regional aggregates", {
  raw <- read_fixture("countries_sample.json")
  out <- parse_countries(raw[[2]])

  expect_true("ABW" %in% out$iso3)
  expect_false("AFE" %in% out$iso3)
  expect_false(any(out$region == "Aggregates"))
  expect_false(any(grepl(" $", out$region)))
})

test_that("API error payloads raise a readable error", {
  raw <- read_fixture("error_sample.json")
  expect_error(check_wb_error(raw), "World Bank API error: The provided parameter value is not valid")
})

test_that("wb_request retries transient failures", {
  calls <- 0
  flaky_reader <- function(url, ...) {
    calls <<- calls + 1
    if (calls < 2) stop("timeout")
    list(list(pages = 1), data.frame(x = 1))
  }
  out <- wb_request("http://example", retries = 3, reader = flaky_reader)
  expect_equal(calls, 2)
  expect_equal(out[[2]]$x, 1)
})

test_that("wb_request gives up after the retry budget", {
  always_fails <- function(url, ...) stop("offline")
  expect_error(wb_request("http://example", retries = 1, reader = always_fails), "after 1 attempts: offline")
})

test_that("wb_fetch_all walks every page", {
  fake_request <- function(url) {
    page <- as.integer(sub(".*page=(\\d+).*", "\\1", url))
    list(list(pages = 3), data.frame(page = page))
  }
  out <- wb_fetch_all("anything", request = fake_request)
  expect_equal(out$page, 1:3)
})

test_that("with_cache stores, reuses and expires values", {
  dir <- withr_tempdir()
  calls <- 0
  fetch <- function() {
    calls <<- calls + 1
    calls
  }

  expect_equal(with_cache("k", fetch, dir = dir), 1)
  expect_equal(with_cache("k", fetch, dir = dir), 1)
  expect_equal(calls, 1)

  Sys.setFileTime(cache_path("k", dir), Sys.time() - 48 * 3600)
  expect_equal(with_cache("k", fetch, ttl_hours = 24, dir = dir), 2)
})

test_that("with_cache falls back to a stale copy when fetching fails", {
  dir <- withr_tempdir()
  with_cache("k", function() "old", dir = dir)
  Sys.setFileTime(cache_path("k", dir), Sys.time() - 48 * 3600)

  expect_warning(
    value <- with_cache("k", function() stop("offline"), ttl_hours = 24, dir = dir),
    "stale cache"
  )
  expect_equal(value, "old")
  expect_error(with_cache("missing", function() stop("offline"), dir = dir), "offline")
})

test_that("data_store only loads each indicator once", {
  calls <- 0
  store <- data_store(function(id) {
    calls <<- calls + 1
    id
  })
  store("A")
  store("A")
  store("B")
  expect_equal(calls, 2)
})
