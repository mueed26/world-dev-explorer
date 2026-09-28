# Overview tab: world map, headline numbers and a top-10 table for one indicator.

overview_ui <- function(id) {
  ns <- NS(id)
  layout_sidebar(
    sidebar = sidebar(
      selectInput(ns("indicator"), "Indicator", indicator_choices()),
      sliderInput(
        ns("year"), "Year",
        min = 2000, max = current_year(), value = current_year() - 1, step = 1, sep = ""
      ),
      helpText(
        "Countries without a value for the chosen year show their most recent",
        "value from the previous five years."
      )
    ),
    uiOutput(ns("kpis")),
    layout_columns(
      col_widths = c(8, 4),
      card(
        full_screen = TRUE,
        card_header(textOutput(ns("map_title"), inline = TRUE)),
        plotlyOutput(ns("map"), height = "460px")
      ),
      card(
        card_header("Highest 10 countries"),
        DTOutput(ns("top"))
      )
    )
  )
}

overview_server <- function(id, load_indicator) {
  moduleServer(id, function(input, output, session) {
    data <- reactive(load_or_fail(load_indicator, input$indicator))
    info <- reactive(indicator_info(input$indicator))

    observeEvent(data(), {
      latest <- max(data()$year)
      updateSliderInput(session, "year", max = latest, value = min(input$year, latest))
    })

    snapshot <- reactive({
      d <- data()
      s <- latest_values(d[d$year > input$year - 5, ], max_year = input$year)
      validate(need(nrow(s) > 0, "No data for this indicator around the selected year."))
      s
    })

    output$map_title <- renderText(paste0(info()$label, ", ", input$year))

    outputOptions(output, "map_title", suspendWhenHidden = FALSE)

    output$kpis <- renderUI({
      s <- snapshot()
      unit <- info()$unit
      top <- which.max(s$value)
      bottom <- which.min(s$value)
      layout_columns(
        fill = FALSE,
        value_box("Countries with data", nrow(s), theme = "primary"),
        value_box("Global median", fmt_value(stats::median(s$value), unit), theme = "secondary"),
        value_box("Highest", fmt_value(s$value[top], unit), s$country[top], theme = "success"),
        value_box("Lowest", fmt_value(s$value[bottom], unit), s$country[bottom], theme = "warning")
      )
    })

    output$map <- renderPlotly(plot_choropleth(snapshot(), info()))

    output$top <- renderDT({
      s <- snapshot()
      s <- utils::head(s[order(-s$value), ], 10)
      datatable(
        data.frame(Country = s$country, Value = fmt_value(s$value, info()$unit), Year = s$year),
        rownames = FALSE, options = list(dom = "t", pageLength = 10, ordering = FALSE)
      )
    })
  })
}

# Loads an indicator, turning API failures into a friendly message in the UI.
load_or_fail <- function(load_indicator, id) {
  tryCatch(
    load_indicator(id),
    error = function(e) {
      validate(need(FALSE, paste("Could not load data from the World Bank API:", conditionMessage(e))))
    }
  )
}
