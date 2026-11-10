# Final evaluation on the reserved test period
# Compare the selected ETS procedure with Seasonal naive

library(dplyr)
library(tsibble)
library(fable)
library(fabletools)

# 1. Read the saved development/test split
evaluation_split <- readRDS(
  "data/processed/evaluation_split.rds"
)

development <- evaluation_split$development
final_test <- evaluation_split$final_test

all_data <- bind_rows(development, final_test) |>
  arrange(month)

development_n <- nrow(development)
forecast_horizon <- 3L

# Use only origins with all three test months available
origins <- seq.int(
  from = development_n,
  to = nrow(all_data) - forecast_horizon
)

results <- vector("list", length(origins))

# 2. Refit and forecast at each origin
for (i in seq_along(origins)) {
  
  origin <- origins[i]
  
  # Only observations available before the forecast
  training <- all_data |>
    slice_head(n = origin)
  
  # The next three observed months, used only for scoring
  actuals <- all_data |>
    as_tibble() |>
    slice((origin + 1L):(origin + forecast_horizon)) |>
    transmute(month, actual = retail_index)
  
  fitted_models <- training |>
    model(
      ETS = ETS(retail_index),
      Seasonal_naive = SNAIVE(retail_index)
    )
  
  predictions <- fitted_models |>
    forecast(h = forecast_horizon) |>
    hilo(level = c(80, 95)) |>
    as_tibble() |>
    transmute(
      .model,
      month,
      .mean,
      lower_80 = `80%`$lower,
      upper_80 = `80%`$upper,
      lower_95 = `95%`$lower,
      upper_95 = `95%`$upper
    ) |>
    arrange(.model, month) |>
    group_by(.model) |>
    mutate(horizon = row_number()) |>
    ungroup() |>
    left_join(actuals, by = "month") |>
    mutate(
      origin_month = max(training$month),
      error = actual - .mean
    )
  
  results[[i]] <- predictions
}

test_predictions <- bind_rows(results)

# 3. Check that every prediction was produced
stopifnot(
  nrow(test_predictions) ==
    length(origins) * 2L * forecast_horizon,
  !anyNA(test_predictions$actual),
  !anyNA(test_predictions$.mean),
  all(is.finite(test_predictions$.mean)),
  all(test_predictions$actual > 0)
)

# 4. Scores for each forecast horizon
test_scores_by_horizon <- test_predictions |>
  group_by(.model, horizon) |>
  summarise(
    N = n(),
    RMSE = sqrt(mean(error^2)),
    MAE = mean(abs(error)),
    MAPE = 100 * mean(abs(error / actual)),
    .groups = "drop"
  ) |>
  arrange(horizon, RMSE)

# 5. Overall scores with equal weight for each horizon
test_scores_overall <- test_predictions |>
  group_by(.model) |>
  summarise(
    N = n(),
    RMSE = sqrt(mean(error^2)),
    MAE = mean(abs(error)),
    MAPE = 100 * mean(abs(error / actual)),
    .groups = "drop"
  ) |>
  arrange(RMSE)

# 6. Save results
dir.create(
  "outputs/tables",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  test_predictions,
  "outputs/tables/final_test_predictions.csv",
  row.names = FALSE
)

write.csv(
  test_scores_by_horizon,
  "outputs/tables/final_test_scores_by_horizon.csv",
  row.names = FALSE
)

write.csv(
  test_scores_overall,
  "outputs/tables/final_test_scores_overall.csv",
  row.names = FALSE
)

# 7. Show results
cat("\nTest results by forecast horizon:\n")
print(test_scores_by_horizon, n = Inf)

cat("\nOverall test results:\n")
print(test_scores_overall)

# Check prediction interval coverage by forecast horizon
interval_coverage <- test_predictions |>
  group_by(.model, horizon) |>
  summarise(
    N = n(),
    inside_80 = sum(actual >= lower_80 & actual <= upper_80),
    inside_95 = sum(actual >= lower_95 & actual <= upper_95),
    coverage_80_pct = 100 * inside_80 / N,
    coverage_95_pct = 100 * inside_95 / N,
    .groups = "drop"
  )

print(interval_coverage, n = Inf, width = Inf)

write.csv(
  interval_coverage,
  "outputs/tables/final_test_interval_coverage.csv",
  row.names = FALSE
)

