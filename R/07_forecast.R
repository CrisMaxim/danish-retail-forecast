# Produce the final three-month retail forecast

library(dplyr)
library(tsibble)
library(fable)
library(fabletools)

# 1. Read all prepared observations
retail <- read.csv(
  "data/processed/retail_total_monthly.csv",
  stringsAsFactors = FALSE
) |>
  mutate(month = yearmonth(as.Date(date))) |>
  select(month, retail_index) |>
  arrange(month) |>
  as_tsibble(index = month)

# 2. Re-estimate the selected ETS procedure on all observations
final_fit <- retail |>
  model(ETS = ETS(retail_index))

report(final_fit)

# 3. Forecast the next three months
retail_forecast <- final_fit |>
  forecast(h = 3)

# 4. Extract prediction intervals
forecast_intervals <- retail_forecast |>
  hilo(level = c(80, 95)) |>
  as_tibble()

forecast_table <- forecast_intervals |>
  transmute(
    month = as.character(month),
    forecast = .mean,
    lower_80 = `80%`$lower,
    upper_80 = `80%`$upper,
    lower_95 = `95%`$lower,
    upper_95 = `95%`$upper
  )

# 5. Create output folders
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/models", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

# 6. Save forecasts and model
write.csv(
  forecast_table,
  "outputs/tables/retail_forecast_3_months.csv",
  row.names = FALSE
)

saveRDS(
  final_fit,
  "outputs/models/ets_final.rds"
)

capture.output(
  report(final_fit),
  file = "outputs/tables/ets_final_report.txt"
)

# 7. Plot the last three years and the forecast
history <- retail |>
  as_tibble() |>
  slice_tail(n = 36)

forecast_dates <- as.Date(retail_forecast$month)

png(
  "outputs/figures/retail_forecast_3_months.png",
  width = 1800,
  height = 1000,
  res = 150
)

par(mar = c(6, 5, 4, 2) + 0.1)

plot(
  as.Date(history$month),
  history$retail_index,
  type = "l",
  lwd = 2,
  xlim = range(c(as.Date(history$month), forecast_dates)),
  ylim = range(
    history$retail_index,
    forecast_table$lower_95,
    forecast_table$upper_95
  ),
  main = "Danish retail trade: three-month ETS forecast",
  xlab = "",
  ylab = "Quantity index",
  col = "#333333"
)

# Draw 95% and 80% prediction intervals
polygon(
  c(forecast_dates, rev(forecast_dates)),
  c(forecast_table$lower_95, rev(forecast_table$upper_95)),
  col = "#DCECF5",
  border = NA
)

polygon(
  c(forecast_dates, rev(forecast_dates)),
  c(forecast_table$lower_80, rev(forecast_table$upper_80)),
  col = "#91C4DF",
  border = NA
)

lines(
  c(tail(as.Date(history$month), 1), forecast_dates),
  c(tail(history$retail_index, 1), forecast_table$forecast),
  col = "#0072B2",
  lwd = 2,
  lty = 2
)

points(
  forecast_dates,
  forecast_table$forecast,
  col = "#0072B2",
  pch = 16
)

legend(
  "topleft",
  legend = c("Observed", "Forecast", "80% interval", "95% interval"),
  col = c("#333333", "#0072B2", "#91C4DF", "#DCECF5"),
  lty = c(1, 2, NA, NA),
  pch = c(NA, 16, 15, 15),
  bty = "n"
)

mtext(
  "Source: Statistics Denmark, DETA212A | Forecast based on data through September 2026",
  side = 1,
  line = 4,
  cex = 0.7
)

dev.off()

# 8. Display the forecast table
print(forecast_table)

# Compare each forecast with the same month one year earlier
previous_year <- retail |>
  as_tibble() |>
  transmute(
    month = month + 12,
    index_previous_year = retail_index
  )

forecast_yoy <- retail_forecast |>
  hilo(level = c(80, 95)) |>
  as_tibble() |>
  transmute(
    month,
    forecast = .mean,
    lower_80 = `80%`$lower,
    upper_80 = `80%`$upper,
    lower_95 = `95%`$lower,
    upper_95 = `95%`$upper
  ) |>
  left_join(previous_year, by = "month") |>
  mutate(
    change_yoy_pct =
      100 * (forecast / index_previous_year - 1),
    yoy_lower_80 =
      100 * (lower_80 / index_previous_year - 1),
    yoy_upper_80 =
      100 * (upper_80 / index_previous_year - 1),
    yoy_lower_95 =
      100 * (lower_95 / index_previous_year - 1),
    yoy_upper_95 =
      100 * (upper_95 / index_previous_year - 1)
  )

stopifnot(!anyNA(forecast_yoy$index_previous_year))

write.csv(
  forecast_yoy,
  "outputs/tables/retail_forecast_yoy.csv",
  row.names = FALSE
)

print(
  forecast_yoy |>
    select(month, change_yoy_pct, yoy_lower_95, yoy_upper_95),
  width = Inf
)
