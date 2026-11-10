# Diagnose the ETS model selected through cross-validation

library(dplyr)
library(tsibble)
library(fable)
library(fabletools)

# 1. Read the saved split
evaluation_split <- readRDS(
  "data/processed/evaluation_split.rds"
)

development <- evaluation_split$development

# 2. Fit ETS using development data only
ets_fit <- development |>
  model(ETS = ETS(retail_index))

# Show the selected ETS specification and parameters
report(ets_fit)

# 3. Extract fitted values and innovations
ets_augmented <- augment(ets_fit)

innovations <- ets_augmented$.innov

stopifnot(
  length(innovations) == nrow(development),
  all(is.finite(innovations))
)

# 4. Create output folders
dir.create("outputs/models", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

# 5. Save the fitted model and its report
saveRDS(
  ets_fit,
  "outputs/models/ets_development.rds"
)

capture.output(
  report(ets_fit),
  file = "outputs/tables/ets_model_report.txt"
)

write.csv(
  as_tibble(ets_augmented),
  "outputs/tables/ets_fitted_values.csv",
  row.names = FALSE
)

# 6. Save diagnostic charts directly to PNG
png(
  "outputs/figures/ets_diagnostics.png",
  width = 1800,
  height = 1400,
  res = 150
)

par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))

plot(
  as.Date(development$month),
  innovations,
  type = "l",
  col = "#0072B2",
  main = "ETS innovations over time",
  xlab = "Year",
  ylab = "Innovation"
)
abline(h = 0, col = "grey40", lty = 2)

acf(
  innovations,
  lag.max = 36,
  main = "ACF of ETS innovations"
)

hist(
  innovations,
  breaks = "FD",
  col = "#56B4E9",
  border = "white",
  main = "Distribution of innovations",
  xlab = "Innovation"
)

qqnorm(
  innovations,
  main = "Normal Q-Q plot",
  col = "#0072B2"
)
qqline(innovations, col = "#D55E00", lwd = 2)

dev.off()

# 7. Display a short summary
cat("\nNumber of innovations:", length(innovations), "\n")
cat("Mean innovation:", mean(innovations), "\n")

report(ets_fit)

# Ljung-Box diagnostic for seasonal ETS
# Check autocorrelation jointly through lag 24

lb_test <- Box.test(
  innovations,
  lag = 24,
  type = "Ljung-Box",
  fitdf = 0
)

print(lb_test)

capture.output(
  lb_test,
  file = "outputs/tables/ets_ljung_box.txt"
)
