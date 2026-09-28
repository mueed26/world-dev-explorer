# Catalog of World Bank indicators the app knows how to display.
# `unit` drives number formatting, `log_scale` drives map colouring and
# `lower`/`upper` are the natural bounds used to clip forecast intervals.

INDICATORS <- data.frame(
  id = c(
    "NY.GDP.PCAP.CD", "SP.DYN.LE00.IN", "SP.POP.TOTL", "IT.NET.USER.ZS",
    "EG.ELC.ACCS.ZS", "EN.GHG.CO2.PC.CE.AR5", "SL.UEM.TOTL.ZS",
    "FP.CPI.TOTL.ZG", "SE.XPD.TOTL.GD.ZS"
  ),
  label = c(
    "GDP per capita (current US$)", "Life expectancy at birth (years)",
    "Population", "Internet users (% of population)",
    "Access to electricity (% of population)", "CO2 emissions per capita (t)",
    "Unemployment (% of labour force)", "Inflation, consumer prices (annual %)",
    "Education spending (% of GDP)"
  ),
  short = c(
    "GDP per capita", "Life expectancy", "Population", "Internet users",
    "Electricity access", "CO2 per capita", "Unemployment", "Inflation",
    "Education spending"
  ),
  unit = c("usd", "years", "people", "pct", "pct", "tonnes", "pct", "pct", "pct"),
  log_scale = c(TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE),
  lower = c(0, 0, 0, 0, 0, 0, 0, -Inf, 0),
  upper = c(Inf, Inf, Inf, 100, 100, Inf, 100, Inf, 100),
  stringsAsFactors = FALSE
)

indicator_choices <- function() {
  stats::setNames(INDICATORS$id, INDICATORS$label)
}

indicator_info <- function(id) {
  row <- INDICATORS[INDICATORS$id == id, , drop = FALSE]
  if (nrow(row) != 1) stop("Unknown indicator: ", id, call. = FALSE)
  as.list(row)
}

current_year <- function() {
  as.integer(format(Sys.Date(), "%Y"))
}
