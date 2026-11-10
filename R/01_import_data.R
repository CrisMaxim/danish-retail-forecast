# Import Danish retail data from Statistics Denmark
# Source table: DETA212A

# Install the required package if it is missing
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite")
}

# Read the table metadata
metadata_url <- paste0(
  "https://api.statbank.dk/v1/tableinfo/DETA212A",
  "?format=JSON&lang=en"
)

metadata <- jsonlite::fromJSON(metadata_url)

# Show the table title and available variables
print(metadata$text)
print(metadata$variables[, c("id", "text")])

# Show available industries and their codes
print(metadata$variables$values[[1]], row.names = FALSE)

# Show available index types and their codes
print(metadata$variables$values[[2]], row.names = FALSE)

# Request all industries, index types and months
request <- list(
  table = "DETA212A",
  format = "CSV",
  lang = "en",
  timeOrder = "Ascending",
  variables = list(
    list(code = "BRANCHEDB25UDVALG", values = list("*")),
    list(code = "INDEKSTYPE", values = list("*")),
    list(code = "Tid", values = list("*"))
  )
)

# Install the HTTP package if needed
if (!requireNamespace("httr", quietly = TRUE)) {
  install.packages("httr")
}

# Convert the request to JSON
request_json <- jsonlite::toJSON(
  request,
  auto_unbox = TRUE
)

# Send the request to Statistics Denmark
response <- httr::POST(
  url = "https://api.statbank.dk/v1/data",
  body = charToRaw(request_json),
  httr::content_type_json(),
  httr::timeout(120)
)

# Stop and show the API message if the request fails
if (httr::http_error(response)) {
  stop(httr::content(response, as = "text", encoding = "UTF-8"))
}

# Save the original CSV
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

writeBin(
  httr::content(response, as = "raw"),
  "data/raw/retail_DETA212A.csv"
)

# Save the metadata
jsonlite::write_json(
  metadata,
  path = "data/raw/retail_DETA212A_metadata.json",
  pretty = TRUE,
  auto_unbox = TRUE
)

# Read the data
retail_raw <- read.csv2(
  "data/raw/retail_DETA212A.csv",
  fileEncoding = "UTF-8-BOM",
  stringsAsFactors = FALSE
)

# Inspect the result
print(head(retail_raw))
str(retail_raw)
print(nrow(retail_raw))