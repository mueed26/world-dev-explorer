test_that("latest_values picks each country's most recent year", {
  df <- fake_indicator(years = 2000:2010)
  df$value[df$iso3 == "BBB" & df$year == 2010] <- NA

  out <- latest_values(df)
  expect_equal(out$year[out$iso3 == "AAA"], 2010)
  expect_equal(out$year[out$iso3 == "BBB"], 2009)
  expect_equal(latest_values(df, max_year = 2005)$year, c(2005, 2005))
})

test_that("cagr matches a known growth rate and handles bad input", {
  expect_equal(cagr(100, 121, 2), 0.1)
  expect_true(is.na(cagr(0, 10, 5)))
  expect_true(is.na(cagr(10, 20, 0)))
})

test_that("trend_summary reports first and latest values per country", {
  df <- fake_indicator(years = 2000:2010)
  out <- trend_summary(df, c("AAA", "BBB"))

  expect_equal(nrow(out), 2)
  aaa <- out[out$country == "Country AAA", ]
  expect_equal(aaa$first_value, 100)
  expect_equal(aaa$latest_value, 110)
  expect_equal(aaa$change, 10)
  expect_equal(nrow(trend_summary(df, "ZZZ")), 0)
})

test_that("prepare_series interpolates interior gaps", {
  y <- prepare_series(c(2000, 2001, 2003), c(1, 2, 4))
  expect_equal(as.numeric(y), c(1, 2, 3, 4))
  expect_equal(stats::start(y)[1], 2000)
})

test_that("forecast_series returns intervals that contain the mean", {
  years <- 2000:2022
  values <- 50 + 0.8 * (years - 2000) + sin(years)
  fc <- forecast_series(years, values, h = 4)

  expect_equal(fc$forecast$year, 2023:2026)
  expect_true(all(fc$forecast$lo95 <= fc$forecast$lo80))
  expect_true(all(fc$forecast$lo80 <= fc$forecast$mean))
  expect_true(all(fc$forecast$mean <= fc$forecast$hi80))
  expect_true(all(fc$forecast$hi80 <= fc$forecast$hi95))
  expect_match(fc$model, "ARIMA")
})

test_that("forecast_series clips to natural bounds", {
  years <- 2000:2020
  values <- pmin(100, 60 + 2.5 * (years - 2000))
  fc <- forecast_series(years, values, h = 10, lower = 0, upper = 100)
  expect_true(all(fc$forecast$hi95 <= 100))
  expect_true(all(fc$forecast$lo95 >= 0))
})

test_that("forecast_series refuses short series", {
  expect_error(forecast_series(2015:2018, 1:4), "at least 10 years")
})

test_that("backtest beats a naive forecast on a clean trend", {
  years <- 2000:2022
  values <- 10 + 3 * (years - 2000)
  bt <- backtest_forecast(years, values, holdout = 5)

  expect_equal(bt$holdout, 5)
  expect_lt(bt$arima_mape, bt$naive_mape)
  expect_error(backtest_forecast(2010:2020, 1:11), "at least 15 years")
})

test_that("mape and mae compute simple errors", {
  expect_equal(mape(c(100, 200), c(110, 180)), 10)
  expect_equal(mae(c(1, 2), c(2, 4)), 1.5)
})

test_that("build_feature_matrix keeps countries with every feature", {
  frames <- list(
    A = fake_indicator(c("AAA", "BBB", "CCC"), 2015:2020),
    B = fake_indicator(c("AAA", "BBB"), 2015:2020)
  )
  out <- build_feature_matrix(frames, year = 2020)
  expect_setequal(out$iso3, c("AAA", "BBB"))
  expect_true(all(c("A", "B", "country", "region") %in% names(out)))

  # Values older than the window are ignored.
  expect_equal(nrow(build_feature_matrix(frames, year = 2030, window = 5)), 0)
})

test_that("cluster_countries finds obvious groups and orders them by GDP", {
  set.seed(1)
  n <- 30
  features <- data.frame(
    iso3 = sprintf("C%02d", 1:n), country = sprintf("Country %d", 1:n),
    region = "R", income = "I",
    NY.GDP.PCAP.CD = c(rep(500, 10), rep(5000, 10), rep(50000, 10)) * runif(n, 0.9, 1.1),
    SP.DYN.LE00.IN = c(rep(55, 10), rep(68, 10), rep(80, 10)) + rnorm(n),
    stringsAsFactors = FALSE
  )
  result <- cluster_countries(features, k = 3)

  expect_equal(as.integer(result$data$cluster), rep(1:3, each = 10))
  expect_gt(result$variance_explained, 0.9)

  profile <- cluster_profile(result)
  expect_equal(profile$countries, c(10, 10, 10))
  expect_true(all(diff(profile$NY.GDP.PCAP.CD) > 0))

  elbow <- elbow_curve(features, ks = 2:4)
  expect_equal(elbow$k, 2:4)
  expect_error(cluster_countries(features[1:2, ], k = 3), "Fewer countries")
})

test_that("formatters produce readable labels", {
  expect_equal(fmt_value(1234.4, "usd"), "$1,234")
  expect_equal(fmt_value(12.345, "pct"), "12.3%")
  expect_equal(fmt_value(c(1.5e9, 2.5e6, NA), "people"), c("1.50B", "2.5M", "n/a"))
  expect_equal(fmt_pct(0.051), "5.1%")
})
