# Number formatting helpers shared by tables, value boxes and tooltips.

fmt_big <- function(x) {
  out <- ifelse(
    abs(x) >= 1e9, paste0(formatC(x / 1e9, format = "f", digits = 2), "B"),
    ifelse(
      abs(x) >= 1e6, paste0(formatC(x / 1e6, format = "f", digits = 1), "M"),
      ifelse(
        abs(x) >= 1e3, paste0(formatC(x / 1e3, format = "f", digits = 1), "K"),
        formatC(x, format = "f", digits = 0)
      )
    )
  )
  out[is.na(x)] <- "n/a"
  out
}

fmt_value <- function(x, unit = "") {
  out <- switch(unit,
    usd = paste0("$", formatC(x, format = "f", digits = 0, big.mark = ",")),
    pct = paste0(formatC(x, format = "f", digits = 1), "%"),
    years = paste0(formatC(x, format = "f", digits = 1), " yrs"),
    people = fmt_big(x),
    tonnes = paste0(formatC(x, format = "f", digits = 2), " t"),
    formatC(x, format = "f", digits = 2, big.mark = ",")
  )
  out[is.na(x)] <- "n/a"
  out
}

fmt_pct <- function(x, digits = 1) {
  out <- paste0(formatC(x * 100, format = "f", digits = digits), "%")
  out[is.na(x)] <- "n/a"
  out
}
