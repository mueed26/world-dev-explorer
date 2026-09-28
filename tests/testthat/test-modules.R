# Server-side tests for the Shiny modules, using a fake data loader so no
# network access is needed.

suppressWarnings(suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(plotly)
  library(DT)
}))

fake_countries <- data.frame(
  iso3 = sprintf("C%02d", 1:12),
  country = sprintf("Country %02d", 1:12),
  stringsAsFactors = FALSE
)

fake_loader <- function(id) {
  scale <- switch(id,
    NY.GDP.PCAP.CD = function(i, y) 500 * i^2 * (1.03^(y - 2000)),
    SP.DYN.LE00.IN = function(i, y) 50 + 2.5 * i + 0.1 * (y - 2000),
    IT.NET.USER.ZS = function(i, y) pmin(100, 5 * i + 2 * (y - 2000)),
    EG.ELC.ACCS.ZS = function(i, y) pmin(100, 40 + 5 * i + (y - 2000)),
    function(i, y) 10 * i + (y - 2000)
  )
  fake_indicator(fake_countries$iso3, 2000:2023, scale)
}

test_that("overview module reports headline numbers for the chosen year", {
  testServer(overview_server, args = list(load_indicator = fake_loader), {
    session$setInputs(indicator = "SP.DYN.LE00.IN", year = 2023)
    expect_equal(nrow(snapshot()), 12)
    expect_true(all(snapshot()$year == 2023))
    expect_equal(output$map_title, "Life expectancy at birth (years), 2023")
  })
})

test_that("compare module filters countries and years", {
  testServer(compare_server, args = list(load_indicator = fake_loader, countries = fake_countries), {
    session$setInputs(indicator = "NY.GDP.PCAP.CD", countries = c("C01", "C02"), years = c(2010, 2020), log = FALSE)
    d <- selected()
    expect_setequal(unique(d$iso3), c("C01", "C02"))
    expect_equal(range(d$year), c(2010, 2020))
  })
})

test_that("forecast module produces a forecast and a backtest", {
  testServer(forecast_server, args = list(load_indicator = fake_loader, countries = fake_countries), {
    session$setInputs(country = "C03", indicator = "SP.DYN.LE00.IN", horizon = 3)
    expect_equal(result()$forecast$year, 2024:2026)
    expect_false(is.null(backtest()))
    expect_equal(output$title, "Life expectancy at birth (years): Country C03")
  })
})

test_that("clusters module groups every complete country", {
  testServer(clusters_server, args = list(load_indicator = fake_loader), {
    session$setInputs(year = 2020, k = 3)
    expect_equal(nrow(result()$data), 12)
    expect_equal(nlevels(result()$data$cluster), 3)
    expect_match(output$elbow_title, "k = 3")
  })
})
