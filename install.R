# Installs every package the app and its tests need.
# Run once from the project root:  Rscript install.R

packages <- c(
  # App
  "shiny", "bslib", "plotly", "DT", "jsonlite", "dplyr", "forecast",
  # Tests
  "testthat",
  # VS Code R support (optional, but recommended for development)
  "languageserver"
)

missing <- setdiff(packages, rownames(installed.packages()))
if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All packages are already installed.")
}
