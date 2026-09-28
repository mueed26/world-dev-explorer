# Load the app's backend code (the R/ folder) before the tests run.
for (file in list.files(test_path("..", "..", "R"), pattern = "\\.R$", full.names = TRUE)) {
  source(file, local = FALSE)
}

read_fixture <- function(name) {
  jsonlite::fromJSON(test_path("fixtures", name), flatten = TRUE)
}

# A synthetic indicator frame shaped like get_indicator() output.
fake_indicator <- function(iso3 = c("AAA", "BBB"), years = 2000:2020, fn = function(i, y) 100 * i + y - 2000) {
  rows <- expand.grid(year = years, i = seq_along(iso3))
  data.frame(
    iso3 = iso3[rows$i],
    country = paste("Country", iso3[rows$i]),
    region = "Test region",
    income = "Test income",
    year = rows$year,
    value = fn(rows$i, rows$year),
    stringsAsFactors = FALSE
  )
}

# A fresh, empty directory for cache tests.
withr_tempdir <- function() {
  dir <- tempfile("wde-cache-")
  dir.create(dir)
  dir
}
