# Analysis layer: summaries, ARIMA forecasting with backtesting, and k-means
# clustering. Everything here is pure (no Shiny), so it is unit-tested.

latest_values <- function(df, max_year = Inf) {
  df <- df[df$year <= max_year & !is.na(df$value), , drop = FALSE]
  df <- df[order(df$iso3, -df$year), , drop = FALSE]
  out <- df[!duplicated(df$iso3), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Compound annual growth rate; NA when it is undefined.
cagr <- function(first, last, years) {
  ifelse(years > 0 & first > 0 & last > 0, (last / first)^(1 / years) - 1, NA_real_)
}

trend_summary <- function(df, iso3s) {
  df <- df[df$iso3 %in% iso3s & !is.na(df$value), , drop = FALSE]
  if (nrow(df) == 0) {
    return(data.frame(
      country = character(), first_year = integer(), first_value = numeric(),
      latest_year = integer(), latest_value = numeric(), change = numeric(),
      cagr = numeric()
    ))
  }
  rows <- lapply(split(df, df$iso3), function(d) {
    d <- d[order(d$year), ]
    n <- nrow(d)
    data.frame(
      country = d$country[1],
      first_year = d$year[1],
      first_value = d$value[1],
      latest_year = d$year[n],
      latest_value = d$value[n],
      change = d$value[n] - d$value[1],
      cagr = cagr(d$value[1], d$value[n], d$year[n] - d$year[1]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(-out$latest_value), ]
}

# ---- Forecasting -----------------------------------------------------------

# Builds an annual ts, filling interior gaps by linear interpolation.
prepare_series <- function(years, values) {
  keep <- !is.na(values)
  years <- years[keep]
  values <- values[keep]
  if (length(years) < 2) stop("Not enough data points to build a series.", call. = FALSE)
  ord <- order(years)
  all_years <- seq(min(years), max(years))
  filled <- stats::approx(years[ord], values[ord], xout = all_years)$y
  stats::ts(filled, start = min(all_years), frequency = 1)
}

mape <- function(actual, predicted) {
  ok <- !is.na(actual) & actual != 0
  mean(abs((actual[ok] - predicted[ok]) / actual[ok])) * 100
}

mae <- function(actual, predicted) {
  mean(abs(actual - predicted), na.rm = TRUE)
}

forecast_series <- function(years, values, h = 5, min_points = 10,
                            lower = -Inf, upper = Inf) {
  y <- prepare_series(years, values)
  if (length(y) < min_points) {
    stop(sprintf(
      "Need at least %d years of data to forecast (found %d).", min_points, length(y)
    ), call. = FALSE)
  }
  fit <- forecast::auto.arima(y)
  fc <- forecast::forecast(fit, h = h, level = c(80, 95))
  clip <- function(x) pmin(pmax(as.numeric(x), lower), upper)
  list(
    history = data.frame(year = as.integer(stats::time(y)), value = as.numeric(y)),
    forecast = data.frame(
      year = as.integer(round(stats::time(fc$mean))),
      mean = clip(fc$mean),
      lo80 = clip(fc$lower[, 1]), hi80 = clip(fc$upper[, 1]),
      lo95 = clip(fc$lower[, 2]), hi95 = clip(fc$upper[, 2])
    ),
    model = as.character(fit)
  )
}

# Hold out the last `holdout` years, fit ARIMA on the rest and compare it with
# a naive "last value carries forward" baseline.
backtest_forecast <- function(years, values, holdout = 5, min_train = 10) {
  y <- prepare_series(years, values)
  n <- length(y)
  if (n < min_train + holdout) {
    stop(sprintf(
      "Need at least %d years of data to backtest (found %d).", min_train + holdout, n
    ), call. = FALSE)
  }
  train <- stats::ts(y[seq_len(n - holdout)], start = stats::start(y), frequency = 1)
  actual <- as.numeric(y[(n - holdout + 1):n])
  arima_pred <- as.numeric(forecast::forecast(forecast::auto.arima(train), h = holdout)$mean)
  naive_pred <- rep(as.numeric(train[length(train)]), holdout)
  list(
    holdout = holdout,
    arima_mape = mape(actual, arima_pred),
    naive_mape = mape(actual, naive_pred),
    arima_mae = mae(actual, arima_pred),
    naive_mae = mae(actual, naive_pred)
  )
}

# ---- Clustering ------------------------------------------------------------

CLUSTER_FEATURES <- c("NY.GDP.PCAP.CD", "SP.DYN.LE00.IN", "IT.NET.USER.ZS", "EG.ELC.ACCS.ZS")
META_COLUMNS <- c("iso3", "country", "region", "income")

# One row per country with the latest value of each indicator inside a
# `window`-year window ending at `year`. Countries missing any feature are dropped.
build_feature_matrix <- function(frames, year, window = 5) {
  wide <- NULL
  for (id in names(frames)) {
    d <- frames[[id]]
    d <- latest_values(d[d$year > year - window, , drop = FALSE], max_year = year)
    d <- stats::setNames(d[, c("iso3", "value")], c("iso3", id))
    wide <- if (is.null(wide)) d else merge(wide, d, by = "iso3")
  }
  meta <- unique(do.call(rbind, lapply(frames, function(f) f[, META_COLUMNS])))
  out <- merge(meta[!duplicated(meta$iso3), ], wide, by = "iso3")
  out[order(out$country), , drop = FALSE]
}

# k-means on standardised features (GDP is log-transformed first). Clusters
# are relabelled 1..k in order of mean GDP so colours stay stable.
cluster_countries <- function(features, k = 4, seed = 42,
                              log_cols = "NY.GDP.PCAP.CD") {
  cols <- setdiff(names(features), c(META_COLUMNS, "cluster"))
  if (nrow(features) < k) stop("Fewer countries than clusters.", call. = FALSE)
  x <- as.matrix(features[, cols, drop = FALSE])
  for (col in intersect(log_cols, cols)) x[, col] <- log10(x[, col])

  set.seed(seed)
  km <- stats::kmeans(scale(x), centers = k, nstart = 25)
  rank <- order(tapply(x[, 1], km$cluster, mean))
  features$cluster <- factor(match(km$cluster, rank), levels = seq_len(k))
  list(
    data = features,
    features = cols,
    variance_explained = km$betweenss / km$totss
  )
}

cluster_profile <- function(result) {
  d <- result$data
  profile <- stats::aggregate(d[, result$features, drop = FALSE], by = list(cluster = d$cluster), FUN = mean)
  profile$countries <- as.integer(table(d$cluster)[as.character(profile$cluster)])
  profile
}

elbow_curve <- function(features, ks = 2:8, seed = 42) {
  ks <- ks[ks <= nrow(features)]
  data.frame(
    k = ks,
    variance_explained = vapply(ks, function(k) {
      cluster_countries(features, k = k, seed = seed)$variance_explained
    }, numeric(1))
  )
}
