# Read the original data
retail_raw <- read.csv2(
  "data/raw/retail_DETA212A.csv",
  fileEncoding = "UTF-8-BOM",
  colClasses = "character",
  stringsAsFactors = FALSE
)

# Select total retail trade and the unadjusted quantity index
retail <- retail_raw[
  retail_raw$BRANCHEDB25UDVALG == "G47 Retail trade" &
    retail_raw$INDEKSTYPE == "Quantity indices",
  c("TID", "INDHOLD")
]

names(retail) <- c("month", "retail_index")

# Convert months to dates and index values to numbers
retail$date <- as.Date(
  paste0(gsub("M", "-", retail$month), "-01")
)

retail$retail_index <- as.numeric(retail$retail_index)

# Sort chronologically
retail <- retail[order(retail$date), ]
rownames(retail) <- NULL

# Check that the series is usable
stopifnot(
  nrow(retail) > 0,
  !anyNA(retail$date),
  !anyNA(retail$retail_index),
  !anyDuplicated(retail$date)
)

expected_dates <- seq(
  min(retail$date),
  max(retail$date),
  by = "month"
)

stopifnot(identical(retail$date, expected_dates))

# Save the prepared data
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

write.csv(
  retail,
  "data/processed/retail_total_monthly.csv",
  row.names = FALSE
)

# Inspect the prepared series
print(head(retail))
print(tail(retail))
print(nrow(retail))

