# Compare tab: multi-country trend lines with growth summary and CSV export.

DEFAULT_COUNTRIES <- c("IND", "CHN", "USA", "BRA", "NGA")

compare_ui <- function(id) {
  ns <- NS(id)
  layout_sidebar(
    sidebar = sidebar(
      selectInput(ns("indicator"), "Indicator", indicator_choices()),
      selectizeInput(
        ns("countries"), "Countries", choices = NULL, multiple = TRUE,
        options = list(maxItems = 8, placeholder = "Pick up to 8 countries")
      ),
      sliderInput(ns("years"), "Years", min = 2000, max = current_year(), value = c(2000, current_year()), sep = ""),
      checkboxInput(ns("log"), "Log scale", FALSE),
      downloadButton(ns("download"), "Download CSV", class = "btn-outline-primary")
    ),
    card(
      full_screen = TRUE,
      card_header(textOutput(ns("title"), inline = TRUE)),
      plotlyOutput(ns("chart"), height = "420px")
    ),
    card(
      card_header("Growth summary"),
      DTOutput(ns("summary"))
    )
  )
}

compare_server <- function(id, load_indicator, countries) {
  moduleServer(id, function(input, output, session) {
    observe({
      choices <- stats::setNames(countries$iso3, countries$country)
      updateSelectizeInput(session, "countries", choices = choices, selected = DEFAULT_COUNTRIES, server = TRUE)
    })

    info <- reactive(indicator_info(input$indicator))
    selected <- reactive({
      validate(need(length(input$countries) > 0, "Pick at least one country."))
      d <- load_or_fail(load_indicator, input$indicator)
      d[d$iso3 %in% input$countries & d$year >= input$years[1] & d$year <= input$years[2], ]
    })

    output$title <- renderText(info()$label)

    outputOptions(output, "title", suspendWhenHidden = FALSE)

    output$chart <- renderPlotly({
      d <- selected()
      validate(need(nrow(d) > 0, "No data for these countries in the selected years."))
      plot_trends(d, info(), log_scale = input$log)
    })

    output$summary <- renderDT({
      s <- trend_summary(selected(), input$countries)
      unit <- info()$unit
      datatable(
        data.frame(
          Country = s$country,
          From = paste0(fmt_value(s$first_value, unit), " (", s$first_year, ")"),
          To = paste0(fmt_value(s$latest_value, unit), " (", s$latest_year, ")"),
          Change = fmt_value(s$change, unit),
          `Annual growth (CAGR)` = fmt_pct(s$cagr),
          check.names = FALSE
        ),
        rownames = FALSE, options = list(dom = "t", ordering = FALSE)
      )
    })

    output$download <- downloadHandler(
      filename = function() paste0("world-dev-", input$indicator, "-", Sys.Date(), ".csv"),
      content = function(file) {
        d <- selected()
        utils::write.csv(d[, c("country", "iso3", "region", "income", "indicator", "year", "value")], file, row.names = FALSE)
      }
    )
  })
}
