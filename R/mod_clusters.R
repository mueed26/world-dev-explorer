# Clusters tab: groups countries with similar development profiles using
# k-means on GDP per capita, life expectancy, internet use and electricity access.

clusters_ui <- function(id) {
  ns <- NS(id)
  layout_sidebar(
    sidebar = sidebar(
      sliderInput(ns("year"), "Year", min = 2005, max = current_year(), value = current_year() - 2, step = 1, sep = ""),
      sliderInput(ns("k"), "Number of clusters (k)", min = 2, max = 7, value = 4),
      helpText(
        "Features: GDP per capita (log), life expectancy, internet users and",
        "electricity access. Each is standardised before clustering. Clusters",
        "are numbered from lowest to highest average GDP."
      )
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        full_screen = TRUE,
        card_header("Countries by cluster"),
        plotlyOutput(ns("scatter"), height = "400px")
      ),
      card(
        full_screen = TRUE,
        card_header("Cluster map"),
        plotlyOutput(ns("map"), height = "400px")
      )
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("Cluster profiles (averages)"),
        DTOutput(ns("profile"))
      ),
      card(
        card_header(textOutput(ns("elbow_title"), inline = TRUE)),
        plotlyOutput(ns("elbow"), height = "260px")
      )
    )
  )
}

clusters_server <- function(id, load_indicator) {
  moduleServer(id, function(input, output, session) {
    frames <- reactive({
      stats::setNames(lapply(CLUSTER_FEATURES, function(f) load_or_fail(load_indicator, f)), CLUSTER_FEATURES)
    })

    features <- reactive({
      f <- build_feature_matrix(frames(), year = input$year)
      validate(need(nrow(f) >= 10, "Not enough countries with complete data for this year."))
      f
    })

    result <- reactive(cluster_countries(features(), k = input$k))
    elbow <- reactive(elbow_curve(features()))

    output$scatter <- renderPlotly(plot_cluster_scatter(result()))
    output$map <- renderPlotly(plot_cluster_map(result()))

    output$profile <- renderDT({
      p <- cluster_profile(result())
      datatable(
        data.frame(
          Cluster = p$cluster,
          Countries = p$countries,
          `GDP per capita` = fmt_value(p$NY.GDP.PCAP.CD, "usd"),
          `Life expectancy` = fmt_value(p$SP.DYN.LE00.IN, "years"),
          `Internet users` = fmt_value(p$IT.NET.USER.ZS, "pct"),
          Electricity = fmt_value(p$EG.ELC.ACCS.ZS, "pct"),
          check.names = FALSE
        ),
        rownames = FALSE, options = list(dom = "t", ordering = FALSE)
      )
    })

    output$elbow_title <- renderText(sprintf(
      "Choosing k: %.0f%% of variance explained with k = %d",
      100 * result()$variance_explained, input$k
    ))
    output$elbow <- renderPlotly(plot_elbow(elbow(), input$k))
    # Inline text in a card header has no size until it renders, which Shiny
    # would otherwise treat as hidden and never compute.
    outputOptions(output, "elbow_title", suspendWhenHidden = FALSE)
  })
}
