# ============================================================================
# GoogleTrendArchive DATA PROCESSING PIPELINE
# ============================================================================
# This script processes raw daily CSV files from Google's Trending Now system
# into a single consolidated dataset with calculated trend durations.
#
# Input: Daily CSV files organized by location in separate folders
# see daily_compressed.zip
# Output: Single CSV with deduplicated trends and calculated durations
# ============================================================================

library(tidyverse)
library(lubridate)
library(data.table)

daily_base_dir <- ""#data directory with the (sub)folders
output_file <- "googletrendarchive_preprocessed.csv"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Parse Google's bucketed search volume format (e.g., "50K+", "2M+", "500+")
parse_search_volume <- function(volume_str) {
  if (is.na(volume_str) || volume_str == "") return(NA_real_)
  
  clean <- str_remove(volume_str, "\\+")
  
  if (str_detect(clean, "K$")) {
    return(as.numeric(str_remove(clean, "K")) * 1000)
  } else if (str_detect(clean, "M$")) {
    return(as.numeric(str_remove(clean, "M")) * 1000000)
  } else {
    return(as.numeric(clean))
  }
}

# Load all CSV files for a single location
load_location_data <- function(location_folder) {
  location <- basename(location_folder)
  
  files <- list.files(location_folder, 
                      pattern = "trending_.*_1d_.*\\.csv$", 
                      full.names = TRUE, 
                      recursive = TRUE)
  
  if (length(files) == 0) {
    cat("  ", location, ": No files found\n")
    return(NULL)
  }
  
  cat("  Loading", location, ":", length(files), "files\n")
  
  # Load and combine all files for this location
  data <- map_dfr(files, function(file) {
    tryCatch({
      df <- read_csv(file, show_col_types = FALSE, col_types = cols(.default = "c"))
      
      if (nrow(df) == 0) return(NULL)
      
      # Extract collection date from filename (format: YYYYMMDD)
      filename <- basename(file)
      date_match <- str_match(filename, "(\\d{8})")
      collection_date <- if (!is.na(date_match[1])) {
        ymd(date_match[2])
      } else {
        NA_Date_
      }
      
      # Add metadata
      df %>%
        mutate(
          location = location,
          collection_date = collection_date
        )
    }, error = function(e) {
      warning("Error loading ", file, ": ", e$message)
      return(NULL)
    })
  })
  
  return(data)
}

# ============================================================================
# STEP 1: LOAD ALL RAW DATA
# ============================================================================

cat("=== STEP 1: LOADING RAW DATA ===\n\n")

# Find all location folders
folders <- list.dirs(daily_base_dir, full.names = TRUE, recursive = FALSE)
folders <- folders[basename(folders) != "weekly" & basename(folders) != "reconstructed"]

cat("Found", length(folders), "locations\n\n")

# Load data from all locations
all_data <- map_dfr(folders, load_location_data)

cat("\n✓ Loaded", format(nrow(all_data), big.mark = ","), "raw trend records\n")
cat("  Date range:", min(all_data$collection_date, na.rm = TRUE), 
    "to", max(all_data$collection_date, na.rm = TRUE), "\n\n")

# ============================================================================
# STEP 2: PARSE AND STANDARDIZE FIELDS
# ============================================================================

cat("=== STEP 2: PARSING FIELDS ===\n\n")

# Standardize column names
colnames(all_data) <- tolower(colnames(all_data))
colnames(all_data) <- str_replace_all(colnames(all_data), " ", "_")

cat("Parsing search volumes...\n")
all_data <- all_data %>%
  mutate(search_volume_lower = map_dbl(search_volume, parse_search_volume))

cat("Parsing timestamps...\n")
all_data_parsed <- all_data %>%
  mutate(
    # Remove timezone suffix and parse
    started_clean = str_remove(started, " UTC[+-]?\\d+$"),
    ended_clean = str_remove(ended, " UTC[+-]?\\d+$"),
    
    # Parse to POSIXct timestamps (UTC)
    start_time = parse_date_time(started_clean, 
                                 orders = c("Bdy IMS p"), 
                                 tz = "UTC", 
                                 quiet = TRUE),
    end_time = parse_date_time(ended_clean, 
                               orders = c("Bdy IMS p"), 
                               tz = "UTC", 
                               quiet = TRUE),
    
    # Count queries in trend breakdown (comma-separated)
    n_queries = str_count(trend_breakdown, ",") + 1
  ) %>%
  select(-started_clean, -ended_clean) %>%
  arrange(trends, location, collection_date, start_time)

cat("✓ Parsing complete\n\n")

# ============================================================================
# STEP 3: CREATE TREND EPISODES AND CALCULATE DURATIONS
# ============================================================================

cat("=== STEP 3: EPISODE DEDUPLICATION AND DURATION CALCULATION ===\n\n")

# Convert to data.table for faster processing
setDT(all_data_parsed)

# Sort by trend, location, and time
setorder(all_data_parsed, trends, location, collection_date, start_time)

cat("Step 3a: Identifying trend episodes...\n")
# Identify trend episodes (same trend appearing in multiple daily snapshots)
all_data_parsed[, `:=`(
  prev_start = shift(start_time),
  prev_end = shift(end_time)
), by = .(trends, location)]

all_data_parsed[, `:=`(
  start_gap = as.numeric(difftime(start_time, prev_start, units = "hours")),
  time_gap = as.numeric(difftime(start_time, prev_end, units = "hours"))
)]

all_data_parsed[, new_episode := is.na(prev_start) | (!is.na(start_gap) & abs(start_gap) > 1)]
all_data_parsed[is.na(new_episode), new_episode := TRUE]
all_data_parsed[, episode_id := cumsum(new_episode), by = .(trends, location)]

cat("Step 3b: Aggregating episodes...\n")
# Collapse multiple occurrences of the same trend into single episodes
# Use earliest start time and latest end time for each episode
episodes <- all_data_parsed[, .(
  start_time = min(start_time, na.rm = TRUE),
  end_time = max(end_time, na.rm = TRUE),
  first_collection_date = min(collection_date),
  last_collection_date = max(collection_date),
  n_days_observed = uniqueN(collection_date),
  total_occurrences = .N,
  search_volume_lower = max(search_volume_lower, na.rm = TRUE),
  n_queries = first(n_queries),
  trend_breakdown = first(trend_breakdown),
  collection_date = first(collection_date)
), by = .(trends, location, episode_id)]

# Replace Inf values with NA
episodes[is.infinite(start_time), start_time := as.POSIXct(NA)]
episodes[is.infinite(end_time), end_time := as.POSIXct(NA)]

cat("Step 3c: Calculating durations with patching...\n")
# Fix data quality issues and calculate durations

episodes[, `:=`(
  start_fixed = fifelse(!is.na(start_time) & !is.na(end_time) & end_time < start_time, 
                        end_time, start_time),
  end_fixed = fifelse(!is.na(start_time) & !is.na(end_time) & end_time < start_time,
                      start_time, end_time),
  times_were_swapped = !is.na(start_time) & !is.na(end_time) & end_time < start_time
)]

episodes[is.na(end_fixed) & !is.na(start_fixed), 
         end_estimated := as.POSIXct(paste(last_collection_date, "23:59:59"), tz = "UTC")]
episodes[is.na(end_estimated), end_estimated := end_fixed]

# Calculate final duration
episodes[, `:=`(
  duration_minutes = as.numeric(difftime(end_estimated, start_fixed, units = "mins")),
  duration_is_estimate = is.na(end_fixed) | times_were_swapped
)]

episodes[, duration_hours := duration_minutes / 60]

# Add date components for analysis
episodes[, `:=`(
  year = year(collection_date),
  month = month(collection_date),
  weekday = lubridate::wday(collection_date, label = TRUE)
)]

cat("Step 3d: Filtering invalid records...\n")
# Filter out records with missing or invalid data
all_data_clean <- episodes[
  !is.na(search_volume_lower) & 
    !is.na(duration_minutes) & 
    duration_minutes > 0
]

# Remove temporary working columns
all_data_clean[, c("start_fixed", "end_fixed", "end_estimated", 
                   "prev_start", "prev_end", "start_gap", "time_gap", "new_episode") := NULL]

cat("✓ Episode processing complete\n\n")



# Write to CSV
cat("\nWriting to", output_file, "...\n")
fwrite(all_data_clean, output_file)

