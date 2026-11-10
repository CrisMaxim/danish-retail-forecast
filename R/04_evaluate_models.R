# Compare forecasting models using time series cross-validation

# 1. Install and load packages
packages <- c("dplyr", "tsibble", "fable", "fabletools")

missing_packages <- packages[
  !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

library(dplyr)
library(tsibble)
library(fable)
library(fabletools)

# 2. Read the prepared data
retail <- read.csv(
  "data/processed/retail_total_monthly.csv",
  stringsAsFactors = FALSE
) |>
  mutate(month = yearmonth(as.Date(date))) |>
  select(month, retail_index) |>
  arrange(month) |>
  as_tsibble(index = month)

stopifnot(
  !anyNA(retail$retail_index),
  all(is.finite(retail$retail_index)),
  all(retail$retail_index > 0)
)

# 3. Define the evaluation settings
initial_window <- 72L
forecast_horizon <- 3L
test_months <- 12L

development_n <- nrow(retail) - test_months

stopifnot(
  development_n >= initial_window + forecast_horizon
)

development <- retail |>
  slice_head(n = development_n)

final_test <- retail |>
  slice_tail(n = test_months)

# Keep the final test period separate
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

saveRDS(
  list(development = development, final_test = final_test),
  "data/processed/evaluation_split.rds"
)

# 4. Create expanding training windows
# Keep only windows with all three future months available
last_window_id <- development_n -
  initial_window - forecast_horizon + 1L

cv_data <- development |>
  stretch_tsibble(.init = initial_window, .step = 1) |>
  filter(.id <= last_window_id)

cat("Training windows:", last_window_id, "\n")

# 5. Fit the same five candidates to each training window
# ARIMA uses a stepwise search without approximate estimation
cv_models <- cv_data |>
  model(
    Seasonal_naive = SNAIVE(retail_index),
    Drift = RW(retail_index ~ drift()),
    ETS = ETS(retail_index),
    ARIMA = ARIMA(
      retail_index,
      stepwise = TRUE,
      approximation = FALSE
    ),
    Regression = TSLM(retail_index ~ trend() + season())
  )

# 6. Forecast the next three months from each window
cv_forecasts <- cv_models |>
  forecast(h = forecast_horizon)

# 7. Match forecasts to observed values
actuals <- development |>
  as_tibble() |>
  rename(actual = retail_index)

cv_predictions <- cv_forecasts |>
  as_tibble() |>
  select(.id, .model, month, .mean) |>
  arrange(.id, .model, month) |>
  group_by(.id, .model) |>
  mutate(horizon = row_number()) |>
  ungroup() |>
  left_join(actuals, by = "month") |>
  mutate(error = actual - .mean)

# Stop if a model failed or an observation is missing
stopifnot(
  nrow(cv_predictions) ==
    last_window_id * 5L * forecast_horizon,
  !anyNA(cv_predictions$actual),
  !anyNA(cv_predictions$.mean),
  all(is.finite(cv_predictions$.mean))
)

# 8. Calculate errors separately for each forecast horizon
scores_by_horizon <- cv_predictions |>
  group_by(.model, horizon) |>
  summarise(
    N = n(),
    RMSE = sqrt(mean(error^2)),
    MAE = mean(abs(error)),
    MAPE = 100 * mean(abs(error / actual)),
    .groups = "drop"
  ) |>
  arrange(horizon, RMSE)

# Overall comparison: equal weight for each horizon
scores_overall <- cv_predictions |>
  group_by(.model) |>
  summarise(
    N = n(),
    RMSE = sqrt(mean(error^2)),
    MAE = mean(abs(error)),
    MAPE = 100 * mean(abs(error / actual)),
    .groups = "drop"
  ) |>
  arrange(RMSE)

# 9. Save the evaluation results
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

write.csv(
  scores_by_horizon,
  "outputs/tables/cv_scores_by_horizon.csv",
  row.names = FALSE
)

write.csv(
  scores_overall,
  "outputs/tables/cv_scores_overall.csv",
  row.names = FALSE
)

write.csv(
  cv_predictions,
  "outputs/tables/cv_predictions.csv",
  row.names = FALSE
)

capture.output(
  sessionInfo(),
  file = "outputs/tables/evaluation_session_info.txt"
)

# 10. Display results
cat("\nResults by forecast horizon:\n")
print(scores_by_horizon, n = Inf)

cat("\nOverall results, ordered by RMSE:\n")
print(scores_overall)
