# Explore the Danish retail quantity index
# Source: Statistics Denmark, table DETA212A

# Read the prepared data
retail <- read.csv(
  "data/processed/retail_total_monthly.csv",
  stringsAsFactors = FALSE
)

retail$date <- as.Date(retail$date)

# Create a monthly time series
start_year <- as.integer(format(min(retail$date), "%Y"))
start_month <- as.integer(format(min(retail$date), "%m"))

retail_ts <- ts(
  retail$retail_index,
  start = c(start_year, start_month),
  frequency = 12
)

# Define the charts
draw_charts <- function() {
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  
  par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))
  
  plot(
    retail$date,
    retail$retail_index,
    type = "l",
    col = "#0072B2",
    lwd = 2,
    main = "Danish retail trade: monthly quantity index",
    xlab = "Year",
    ylab = "Index"
  )
  
  monthplot(
    retail_ts,
    labels = month.abb,
    col = "#0072B2",
    main = "Seasonal pattern by month",
    xlab = "Month",
    ylab = "Index"
  )
}

# Save the charts
dir.create(
  "outputs/figures",
  recursive = TRUE,
  showWarnings = FALSE
)

png(
  "outputs/figures/retail_exploration.png",
  width = 1600,
  height = 1200,
  res = 150
)

draw_charts()
dev.off()

# STL decomposition: trend, seasonality and remainder
# Use only development data; reserve the final 12 months

retail_stl_ts <- ts(
  head(retail$retail_index, -12),
  start = c(start_year, start_month),
  frequency = 12
)

stl_fit <- stl(
  retail_stl_ts,
  s.window = 13,
  robust = TRUE
)

# Save the decomposition plot
png(
  "outputs/figures/retail_stl.png",
  width = 1600,
  height = 1400,
  res = 150
)

plot(
  stl_fit,
  main = "Danish retail trade: STL decomposition"
)

dev.off()
