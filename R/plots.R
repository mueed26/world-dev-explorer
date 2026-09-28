# Plotly chart builders used by the Shiny modules.

CLUSTER_COLORS <- c("#D55E00", "#E69F00", "#009E73", "#0072B2", "#CC79A7", "#56B4E9", "#999999")
SERIES_COLORS <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#000000", "#999999")

map_geo <- list(
  showframe = FALSE,
  showcoastlines = FALSE,
  showcountries = TRUE,
  countrycolor = "rgba(0,0,0,0.15)",
  bgcolor = "rgba(0,0,0,0)",
  projection = list(type = "natural earth")
)

finish_plot <- function(p) {
  p |>
    plotly::layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor = "rgba(0,0,0,0)",
      font = list(family = "Inter, system-ui, sans-serif")
    ) |>
    plotly::config(displaylogo = FALSE)
}

plot_choropleth <- function(df, info) {
  log_scale <- isTRUE(info$log_scale) && all(df$value > 0)
  z <- if (log_scale) log10(df$value) else df$value
  hover <- paste0(
    "<b>", df$country, "</b><br>", fmt_value(df$value, info$unit), " (", df$year, ")"
  )

  p <- plotly::plot_ly(
    type = "choropleth", locations = df$iso3, z = z, text = hover,
    hoverinfo = "text", colorscale = "Viridis", reversescale = FALSE,
    marker = list(line = list(color = "white", width = 0.3))
  )
  if (log_scale) {
    ticks <- seq(floor(min(z)), ceiling(max(z)))
    p <- plotly::colorbar(p, title = info$short, tickvals = ticks, ticktext = fmt_value(10^ticks, info$unit))
  } else {
    p <- plotly::colorbar(p, title = info$short)
  }
  p |>
    plotly::layout(geo = map_geo, margin = list(l = 0, r = 0, t = 0, b = 0)) |>
    finish_plot()
}

plot_trends <- function(df, info, log_scale = FALSE) {
  p <- plotly::plot_ly()
  countries <- unique(df$country)
  for (i in seq_along(countries)) {
    d <- df[df$country == countries[i], ]
    p <- plotly::add_lines(
      p, x = d$year, y = d$value, name = countries[i],
      line = list(width = 2.5, color = SERIES_COLORS[(i - 1) %% length(SERIES_COLORS) + 1]),
      text = fmt_value(d$value, info$unit),
      hovertemplate = paste0("<b>", countries[i], "</b> %{x}: %{text}<extra></extra>")
    )
  }
  p |>
    plotly::layout(
      xaxis = list(title = ""),
      yaxis = list(title = info$label, type = if (log_scale) "log" else "linear"),
      hovermode = "x unified",
      legend = list(orientation = "h", y = -0.15)
    ) |>
    finish_plot()
}

plot_forecast <- function(fc, info) {
  history <- fc$history
  future <- fc$forecast
  last <- history[nrow(history), ]
  bridge <- data.frame(year = c(last$year, future$year), value = c(last$value, future$mean))

  plotly::plot_ly() |>
    plotly::add_ribbons(
      x = future$year, ymin = future$lo95, ymax = future$hi95, name = "95% interval",
      fillcolor = "rgba(0,114,178,0.12)", line = list(color = "transparent"), hoverinfo = "skip"
    ) |>
    plotly::add_ribbons(
      x = future$year, ymin = future$lo80, ymax = future$hi80, name = "80% interval",
      fillcolor = "rgba(0,114,178,0.25)", line = list(color = "transparent"), hoverinfo = "skip"
    ) |>
    plotly::add_lines(
      x = history$year, y = history$value, name = "Actual",
      line = list(color = "#1f2937", width = 2.5),
      text = fmt_value(history$value, info$unit), hovertemplate = "%{x}: %{text}<extra>Actual</extra>"
    ) |>
    plotly::add_lines(
      x = bridge$year, y = bridge$value, name = "Forecast",
      line = list(color = "#0072B2", width = 2.5, dash = "dash"),
      text = fmt_value(bridge$value, info$unit), hovertemplate = "%{x}: %{text}<extra>Forecast</extra>"
    ) |>
    plotly::layout(
      xaxis = list(title = ""),
      yaxis = list(title = info$label),
      hovermode = "x unified",
      legend = list(orientation = "h", y = -0.15)
    ) |>
    finish_plot()
}

plot_cluster_scatter <- function(result) {
  d <- result$data
  k <- nlevels(d$cluster)
  plotly::plot_ly(
    d, x = ~NY.GDP.PCAP.CD, y = ~SP.DYN.LE00.IN, color = ~cluster,
    colors = CLUSTER_COLORS[seq_len(k)], type = "scatter", mode = "markers",
    marker = list(size = 10, opacity = 0.85, line = list(color = "white", width = 1)),
    text = ~paste0(
      "<b>", country, "</b><br>Cluster ", cluster,
      "<br>GDP per capita: ", fmt_value(NY.GDP.PCAP.CD, "usd"),
      "<br>Life expectancy: ", fmt_value(SP.DYN.LE00.IN, "years"),
      "<br>Internet users: ", fmt_value(IT.NET.USER.ZS, "pct")
    ),
    hoverinfo = "text"
  ) |>
    plotly::layout(
      xaxis = list(title = "GDP per capita (US$, log scale)", type = "log"),
      yaxis = list(title = "Life expectancy (years)"),
      legend = list(title = list(text = "Cluster"))
    ) |>
    finish_plot()
}

plot_cluster_map <- function(result) {
  d <- result$data
  k <- nlevels(d$cluster)
  colors <- CLUSTER_COLORS[seq_len(k)]
  # Plotly choropleths are continuous, so build a stepped colour scale.
  stops <- seq(0, 1, length.out = k + 1)
  colorscale <- do.call(rbind, lapply(seq_len(k), function(i) {
    data.frame(stop = c(stops[i], stops[i + 1]), color = colors[i])
  }))

  plotly::plot_ly(
    type = "choropleth", locations = d$iso3, z = as.integer(d$cluster),
    zmin = 0.5, zmax = k + 0.5, colorscale = colorscale,
    text = paste0("<b>", d$country, "</b><br>Cluster ", d$cluster), hoverinfo = "text",
    marker = list(line = list(color = "white", width = 0.3))
  ) |>
    plotly::colorbar(title = "Cluster", tickvals = seq_len(k), ticktext = seq_len(k)) |>
    plotly::layout(geo = map_geo, margin = list(l = 0, r = 0, t = 0, b = 0)) |>
    finish_plot()
}

plot_elbow <- function(elbow, k) {
  plotly::plot_ly() |>
    plotly::add_trace(
      x = elbow$k, y = elbow$variance_explained, type = "scatter", mode = "lines+markers",
      line = list(color = "#0072B2"), marker = list(size = 8, color = "#0072B2"),
      hovertemplate = "k = %{x}: %{y:.1%} explained<extra></extra>"
    ) |>
    plotly::add_trace(
      x = k, y = elbow$variance_explained[elbow$k == k], type = "scatter", mode = "markers",
      marker = list(size = 14, color = "#D55E00"), hoverinfo = "skip"
    ) |>
    plotly::layout(
      showlegend = FALSE,
      xaxis = list(title = "Number of clusters (k)", dtick = 1),
      yaxis = list(title = "Variance explained", tickformat = ".0%")
    ) |>
    finish_plot()
}
