# About tab: what the app does and how it is built.

about_ui <- function() {
  layout_columns(
    col_widths = c(-2, 8, -2),
    card(
      card_body(
        class = "about",
        h2("About this project"),
        p(
          "World Development Explorer is an interactive R/Shiny dashboard built on live",
          a("World Bank Open Data", href = "https://data.worldbank.org", target = "_blank"),
          "for 200+ countries since 2000."
        ),
        h4("What you can do"),
        tags$ul(
          tags$li(strong("Overview:"), " map any of 9 indicators and see the leaders and laggards."),
          tags$li(strong("Compare:"), " plot up to 8 countries, see compound annual growth, export CSV."),
          tags$li(strong("Forecast:"), " ARIMA forecasts with 80% / 95% prediction intervals, validated by a 5-year backtest against a naive baseline."),
          tags$li(strong("Clusters:"), " k-means clustering of countries on development indicators, with an elbow chart for choosing k.")
        ),
        h4("How it is built"),
        tags$ul(
          tags$li(strong("Data layer (R/data_api.R):"), " World Bank API client with pagination, retries, a 24-hour disk cache and a stale-cache fallback when the API is down."),
          tags$li(strong("Analysis layer (R/analysis.R):"), " pure functions for summaries, forecasting and clustering, covered by testthat unit tests."),
          tags$li(strong("UI layer (R/mod_*.R):"), " Shiny modules with bslib (Bootstrap 5) and plotly."),
          tags$li(strong("Delivery:"), " Docker image and a GitHub Actions workflow that runs the tests on every push.")
        ),
        p(class = "text-muted small", "Forecasts are statistical extrapolations of past trends, not predictions of policy or shocks.")
      )
    )
  )
}
