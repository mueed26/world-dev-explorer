# Forecast tab: ARIMA forecast with prediction intervals and a backtest
# against a naive baseline.

forecast_ui <- function(id) {
  ns <- NS(id)
  layout_sidebar(
    sidebar = sidebar(
      selectizeInput(ns("country"), "Country", choices = NULL),
      selectInput(ns("indicator"), "Indicator", indicator_choices()),
      sliderInput(ns("horizon"), "Years ahead", min = 1, max = 10, value = 5),
      helpText(
        "The model is chosen automatically with auto.arima(). The backtest",
        "hides the last 5 years, forecasts them, and compares the error with",
        "a naive 'no change' forecast."
      )
    ),
    uiOutput(ns("kpis")),
    card(
      full_screen = TRUE,
      card_header(textOutput(ns("title"), inline = TRUE)),
      plotlyOutput(ns("chart"), height = "420px")
    ),
    card(
      card_header("Forecast values"),
      DTOutput(ns("table"))
    )
  )
}

forecast_server <- function(id, load_indicator, countries) {
  moduleServer(id, function(input, output, session) {
    observe({
      choices <- stats::setNames(countries$iso3, countries$country)
      updateSelectizeInput(session, "country", choices = choices, selected = "IND", server = TRUE)
    })

    info <- reactive(indicator_info(input$indicator))

    series <- reactive({
      req(input$country)
      d <- load_or_fail(load_indicator, input$indicator)
      d[d$iso3 == input$country, ]
    })

    result <- reactive({
      d <- series()
      i <- info()
      tryCatch(
        forecast_series(d$year, d$value, h = input$horizon, lower = i$lower, upper = i$upper),
        error = function(e) validate(need(FALSE, conditionMessage(e)))
      )
    })

    backtest <- reactive({
      d <- series()
      tryCatch(backtest_forecast(d$year, d$value, holdout = 5), error = function(e) NULL)
    })

    output$title <- renderText({
      d <- series()
      paste0(info()$label, ": ", d$country[1])
    })

    output$kpis <- renderUI({
      fc <- result()
      bt <- backtest()
      unit <- info()$unit
      final <- fc$forecast[nrow(fc$forecast), ]
      last <- fc$history[nrow(fc$history), ]
      backtest_box <- if (is.null(bt)) {
        value_box("Backtest error (MAPE)", "n/a", "Not enough history", theme = "secondary")
      } else {
        better <- bt$arima_mape < bt$naive_mape
        value_box(
          "Backtest error (MAPE)", sprintf("%.1f%%", bt$arima_mape),
          sprintf("Naive baseline: %.1f%%", bt$naive_mape),
          theme = if (better) "success" else "warning"
        )
      }
      layout_columns(
        fill = FALSE,
        value_box("Model", fc$model, theme = "primary"),
        value_box(paste("Latest actual", last$year), fmt_value(last$value, unit), theme = "secondary"),
        value_box(
          paste("Forecast", final$year), fmt_value(final$mean, unit),
          paste0("95%: ", fmt_value(final$lo95, unit), " to ", fmt_value(final$hi95, unit)),
          theme = "info"
        ),
        backtest_box
      )
    })

    outputOptions(output, "title", suspendWhenHidden = FALSE)

    output$chart <- renderPlotly(plot_forecast(result(), info()))

    output$table <- renderDT({
      f <- result()$forecast
      unit <- info()$unit
      datatable(
        data.frame(
          Year = f$year,
          Forecast = fmt_value(f$mean, unit),
          `80% interval` = paste(fmt_value(f$lo80, unit), "to", fmt_value(f$hi80, unit)),
          `95% interval` = paste(fmt_value(f$lo95, unit), "to", fmt_value(f$hi95, unit)),
          check.names = FALSE
        ),
        rownames = FALSE, options = list(dom = "t", ordering = FALSE)
      )
    })
  })
}
