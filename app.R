# World Development Explorer
# Shiny automatically sources every file in R/ before running this script.

library(shiny)
library(bslib)
library(plotly)
library(DT)

load_indicator <- data_store()

ui <- page_navbar(
  title = "World Development Explorer",
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    base_font = font_google("Inter"),
    primary = "#0072B2"
  ),
  header = tags$head(tags$link(rel = "stylesheet", href = "styles.css")),
  fillable = FALSE,
  nav_panel("Overview", icon = icon("earth-americas"), overview_ui("overview")),
  nav_panel("Compare", icon = icon("chart-line"), compare_ui("compare")),
  nav_panel("Forecast", icon = icon("wand-magic-sparkles"), forecast_ui("forecast")),
  nav_panel("Clusters", icon = icon("circle-nodes"), clusters_ui("clusters")),
  nav_panel("About", icon = icon("circle-info"), about_ui()),
  nav_spacer(),
  nav_item(tags$a("Data: World Bank", href = "https://data.worldbank.org", target = "_blank"))
)

server <- function(input, output, session) {
  countries <- tryCatch(get_countries(), error = function(e) {
    showNotification(
      paste("Could not load the country list:", conditionMessage(e)),
      type = "error", duration = NULL
    )
    data.frame(iso3 = character(), country = character())
  })

  overview_server("overview", load_indicator)
  compare_server("compare", load_indicator, countries)
  forecast_server("forecast", load_indicator, countries)
  clusters_server("clusters", load_indicator)
}

shinyApp(ui, server)
