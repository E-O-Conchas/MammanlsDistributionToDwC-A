#######################################
# Author: Emmanuel Oceguera
# Date: July 2024
#  
# Work: This script processes mammal species distribution data across various European countries,
# transforming the data into Darwin Core standards. The objective is to aggregate, clean,
# and reformat the data for further analysis and publication, ensuring that each country's
# data is standardized and combined into a single, cohesive dataset.
#######################################

# Clear environment and set garbage collection
rm(list = ls())
gc()

# Set working directory
# setwd("I://biocon//output//raw_species_by_country")

# Import necessary libraries
library(tidyverse)
library(sf)
library(stringr)
library(RPostgres)
library(DBI)
library(yaml)

# access to the config path
config_path <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/config/config.yml"
config <- yaml::read_yaml(config_path)

# Get the connection parameters from the configuration file
dbname <- config$db$name
host <- config$db$host
port <- config$db$port
user <- config$db$user
password <- config$db$password
data_dir <- config$paths$data_dir
output_dir <- config$paths$output_dir

# Establish the connection
con <- dbConnect(RPostgres::Postgres(),
                 dbname = dbname,
                 host = host,
                 port = port,
                 user = user,
                 password = password,
                 options = "-c client_encoding=UTF8")

### Defined functions ###
# Function to process individual shape files and extract relevant columns
process_shapefile <- function(dataset_path) {
  # Read the shapefile
  shp_data <- st_read(dataset_path, quiet = TRUE)
  
  # Dynamically determine the species code column name based on the file name
  species_code <- tolower(str_extract(basename(dataset_path), "(?<=_)[^_]+(?=\\.shp$)"))
  
  
  if (is.na(species_code)) {
    issues_log[[dataset_path]] <- "Species code could not be determined"
    return(NULL)
  }
  
  cat("Species code:", species_code, " ", "\n")
  
  column_name <- paste0("m_", species_code)
  
  # Check if the species column exists in the shapefile
  if (!column_name %in% colnames(shp_data)) {
    issues_log[[dataset_path]] <- paste("Column does not exist in the shapefile:", column_name)
    return(NULL)
  }
  
  # Add the year column if it does not exist
  if (!"YEAR" %in% colnames(shp_data)){
    shp_data$YEAR <- NA # Assing NA to the YEAR column missing datasets
    
  }
  # Select the required columns: the first three columns, the species-specific column, and 'eventID'
  shp_data_selected <- shp_data %>%
    select(1:3, all_of(column_name), "eventID", "YEAR")
  
  # Rename the species-specific column to include the species code for clarity
  colnames(shp_data_selected)[4] <- species_code
  
  # creae and if else statement id the eoforigin and noforigin are numeric or double,
  # conver to a charachter
  if (is.numeric(shp_data_selected$eoforigin) || is.double(shp_data_selected$eoforigin)) {
    shp_data_selected$eoforigin <- as.character(shp_data_selected$eoforigin)
  }
  
  if (is.numeric(shp_data_selected$noforigin) || is.double(shp_data_selected$noforigin)) {
    shp_data_selected$noforigin <- as.character(shp_data_selected$noforigin)
  }
  
  return(shp_data_selected)
}


### List all the shape file  by countries ###
# Define directory containing all European shapefiles
country_dirs <- list.dirs(data_dir, recursive = FALSE, full.names = TRUE)
# Initialize issues log
issues_log <- list()
# Define a list to save the resuts
shapefiles_by_country <- list()
# Loop through each country
for (country_dir in country_dirs) {
  cat("Processing:", basename(country_dir), "\n")
  # Extract base name
  country_name <- basename(country_dir)
  # List the shapefiles 
  shp_files <- list.files(country_dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
  # Append the path to the list
  shapefiles_by_country[[country_name]] <- shp_files
}


### Combine all the shape files by country ###

# Deine a list to save the results
mammals_data_by_country <- list()

# Loop trough each country
for (country in names(shapefiles_by_country)) {
  cat("Processing:", country, "\n")
  shp_files <- shapefiles_by_country[[country]]
  
  # Process the shp using the costume function
  combined_data_list <- lapply(shp_files, process_shapefile)
  # Combine the tables
  combined_data <- bind_rows(combined_data_list[!sapply(combined_data_list, is.null)])
  mammals_data_by_country[[country]] <- combined_data
}

# Check the data
# mammals_data_by_country[[1]]
# View(mammals_data_by_country)

### reorder Columns and fill missing Values ###

# Define the list to save the reorder results
mammals_data_by_country_reorder <- list()
# Loop trough each country
for (country in names(mammals_data_by_country)) {
  cat("Processing:", country, "\n")
  shp_files <- mammals_data_by_country[[country]] 
  # Filter the the shapefile with null values and we reorder the columns
  if(!is.null(shp_files)){
    shp_files <- shp_files %>% 
      select(-c(eventID, geometry), everything(), YEAR, eventID, geometry)
    
    # Replace NA (all the species columns must be numeric)
    shp_files <- shp_files %>%
      mutate(across(where(is.numeric), ~ ifelse(is.na(.), 0, .)))
  }
  mammals_data_by_country_reorder[[country]] <- shp_files
}

# Check
# head(mammals_data_by_country_reorder)[[11]])
# View(mammals_data_by_country_reorder)

### Standardize Columns across all the countries ###

# Define  fixed columns
standard_fixed_colnames <- c("cellcode", "eoforigin", "noforigin", "year", "eventID", "geometry")

# Loop through each element in the list
for (i in names(mammals_data_by_country_reorder)) {
  cat("processing:", i, "\n")
  # Get the current column names of the element
  current_colnames <- colnames(mammals_data_by_country_reorder[[i]])
  
  # Standardize only the fixed column names, keeping species columns intact
  standardized_colnames <- current_colnames
  standardized_colnames[match(tolower(standard_fixed_colnames), tolower(current_colnames))] <- standard_fixed_colnames

  # Apply the standardized column names back to the dataset
  colnames(mammals_data_by_country_reorder[[i]]) <- standardized_colnames
}

# Verify the updated column names
# sapply(mammals_data_by_country_reorder, colnames)
# names(mammals_data_by_country_reorder[[32]])

### Remove duplicate columns across all the countries ###
# After align the column names I found out that some species were some columns are duplicated

# Loop through each element in the list to standardize column names
for (i in seq_along(mammals_data_by_country_reorder)) {
  # Get the current column names of the element
  current_shp <- mammals_data_by_country_reorder[[i]]
  # print(names(current_shp)) 
  # Define the column names that we want to exclude from the data set
  columns_to_delete <- c("EofOrigin", "NofOrigin")
  # Check if any of the columns exist in the dataset
  columns_present <- columns_to_delete[columns_to_delete %in% colnames(current_shp)]
  # Filter out the columns to delete
  if (length(columns_present) > 0){
    current_shp <- current_shp %>% select(-all_of(columns_present))
    # Append to the list
    mammals_data_by_country_reorder[[i]] <- current_shp
  }else{
    cat("Columns not found in the data set . Skipping deletion step.\n")
  }
}

for (i in seq_along(mammals_data_by_country_reorder)) {
  current_shp <- mammals_data_by_country_reorder[[i]]
  
  # Identify and remove truly duplicated column names
  unique_cols <- !duplicated(names(current_shp))  
  current_shp <- current_shp[, unique_cols, drop = FALSE]
  
  # Assign the cleaned dataset back
  mammals_data_by_country_reorder[[i]] <- current_shp
}

#Check the List to see if the extra columns were remove
sapply(mammals_data_by_country_reorder, colnames)
names(mammals_data_by_country_reorder[['Portugal']]) # it has duplicate columns


#### Aggregate data by country, summarizing by species presence in each spatial cell ###

# Define species codes 
species_codes_list <- c(
  # Ungulates
  "alcalc","ammler","capibe", "cappyr", "cerela", "ruprup", "susscr", 
  "capcap", "bisbon", "capaeg", "ruppyr", "rantar", "ruporn", "munree", 
  "ovimus", "damdam", "cernip","oviamm",
  # Carnivores
  "canlup", "lynlyn", "lynpar", "gulgul", "ursarc")
# Use as patter
species_patter <- paste(species_codes_list, collapse = "|")


eu_mammals_occ_data_grouped <- list()

# Loop through  each of the countries
for (country in names(mammals_data_by_country_reorder)) {
  # Get the country shp file
  shp_files <- mammals_data_by_country_reorder[[country]]
  # Get the species columns
  species_columns <- colnames(shp_files)[grepl(species_patter, colnames(shp_files))]
  cat(colnames(species_columns), "\n")
  # Summarize data, keeping the maximum presence value within each cell
  shp_files_grouped <- shp_files %>%
    group_by(cellcode, eoforigin, noforigin, eventID, year) %>%
    summarise(across(all_of(species_columns), ~ max(.x, na.rm = TRUE)), .groups = 'drop')
  
  eu_mammals_occ_data_grouped[[country]] <- shp_files_grouped
}


# Check
head(eu_mammals_occ_data_grouped['Albania'])


#### Write the output files to the respective country folder ####

# Loop trough each of the countries
for (country in names(eu_mammals_occ_data_grouped)) {
  
  # Define the path to the spp folder
  output_dir <- file.path(dir_europe, country, "spp")
  
  # Check if the "spp" folder exist and delete it if does
  if (dir.exists(output_dir)) {
    unlink(output_dir, recursive = TRUE)
  }
  
  # create the directory again
  dir.create(output_dir, recursive =TRUE)
  
  # Define the output  fot he shapefile
  output_path <- file.path(output_dir, paste0(tolower(country), "_mammals_spp_grid.shp"))
  
  # Write the summarized shapefiles
  st_write(eu_mammals_occ_data_grouped[[country]], output_path, delete_layer = TRUE, quiet = TRUE)
}


# Transform dataset into long format
eu_mammals_occ_data_long <- list()

for (country in names(eu_mammals_occ_data_grouped)) {
  shp_files <- eu_mammals_occ_data_grouped[[country]]
  
  mammals_occ_df_long <- as.data.frame(shp_files) %>%
    pivot_longer(cols = where(is.numeric), names_to = 'taxonID', values_to = 'presence') %>%
    mutate(scientificName = case_when(
      # Ungulates
      taxonID == "alcalc" ~ "Alces alces",
      taxonID == "capibe" ~ "Capra ibex",
      taxonID == "cappyr" ~ "Capra pyrenaica",
      taxonID == "cerela" ~ "Cervus elaphus",
      taxonID == "ruprup" ~ "Rupicapra rupicapra",
      taxonID == "susscr" ~ "Sus scrofa",
      taxonID == "capcap" ~ "Capreolus capreolus",
      taxonID == "bisbon" ~ "Bison bonasus",
      taxonID == "capaeg" ~ "Capra hircus aegagrus",
      taxonID == "ruppyr" ~ "Rupicapra pyrenaica",
      taxonID == "rantar" ~ "Rangifer tarandus",
      taxonID == "ruporn" ~ "Rupicapra pyrenaica ornata",
      taxonID == "ovimus" ~ "Ovis aries musimon",
      taxonID == "oviamm" ~ "Ovis ammon",
      taxonID == "damdam" ~ "Dama dama",
      taxonID == "cernip" ~ "Cervus nippon",
      # Carnivors
      taxonID == "canlup" ~ "Canis lupus",
      taxonID == "ursarc" ~ "Ursus arctos",
      taxonID == "lynlyn" ~ "Lynx lynx",
      taxonID == "gulgul" ~ "Gulo gulo",
      taxonID == "lynpar" ~ "Lynx pardinus",
      TRUE ~ NA_character_),
      country = country,
      decimalLatitude = NA_real_,
      decimalLongitude = NA_real_,
      basisOfRecord = 'MaterialCitation') %>% 
    mutate(eventID = eventID)
  
  eu_mammals_occ_data_long[[country]] <- mammals_occ_df_long
}



# Extract centroids and coordinates and create a harmonized data frame
eu_mammals_occ_pts <- list()

for (country in names(eu_mammals_occ_data_long)) {
  shp_files <- eu_mammals_occ_data_long[[country]]
  
  shp_files_pts <- st_centroid(st_as_sf(shp_files)) %>%
    mutate(decimalLongitude = st_coordinates(geometry)[,1],
           decimalLatitude = st_coordinates(geometry)[,2]) %>%
    as.data.frame() %>%
    select(cellcode, taxonID, scientificName, presence, country, decimalLatitude, decimalLongitude, basisOfRecord, eventID)
  
  # Create a sf object and write it
  shp_files_pts_sf <- st_as_sf(shp_files_pts, coords = c("decimalLongitude", "decimalLatitude"), crs = 3035)
  
  output_dir <- file.path(dir_europe, country, "spp")
  
  # Create the subfolder if it does not exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Define the output file paths
  output_path <- file.path(output_dir, paste0(tolower(country), "_mammals_spp_pts.shp"))
  output_path_gpkg <- file.path(output_dir, paste0(tolower(country), "_mammals_spp_pts.gpkg"))
  output_path_csv <- file.path(output_dir, paste0(tolower(country), "_mammals_spp_pts.csv"))
  
  # Write the sf file
  st_write(shp_files_pts_sf, output_path, delete_layer = TRUE, quiet = TRUE, append=FALSE)
  st_write(shp_files_pts_sf, output_path_gpkg, driver = "gpkg", append=FALSE)
  write.csv(shp_files_pts, output_path_csv, append=FALSE)
  
  cat("Shapefiles written to:", output_dir, "/n")
  
  eu_mammals_occ_pts[[country]] <- shp_files_pts
}

# Combine all country data into one data frame
eu_mammals_occ_merged <- bind_rows(eu_mammals_occ_pts)


# Add occurrence remarks
eu_mammals_occ_merged$occurrenceRemarks <- ifelse(eu_mammals_occ_merged$presence == 1, 'resident', 
                                                  ifelse(eu_mammals_occ_merged$presence == 9, 'sporadic',
                                                         ifelse(eu_mammals_occ_merged$presence == 5, 'extinct', NA)))
                                                         
                                                                


# # Save the final combined data set to files
# final_output_path <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/output"
# st_write(st_as_sf(eu_mammals_occ_merged, coords = c("decimalLongitude", "decimalLatitude"), crs = 3035), paste0(final_output_path, "/mammals_ungulates_dwc_occ.gpkg"), driver = "gpkg")

# optionally
# We export the merged final file into the postgres
# Specify the shema where we want to save the files
table_name <- 'mammals_ungulates_dwc_occ'
table_name_sf <- 'mammals_ungulates_dwc_occ_sf'
schema <- 'eu_mammals_darwin_core'

# convert data frame to shp object
eu_mammals_occ_merged_sf <- st_as_sf(eu_mammals_occ_merged, coords = c("decimalLongitude", "decimalLatitude"), crs = 3035)

# Write the table from the list to the postgresSQL database
st_write(eu_mammals_occ_merged, 
         dsn = con, 
         layer = Id(schema = schema, table = table_name), 
         append = FALSE,
         delete_layer = TRUE) # Overwrite the existing table

st_write(eu_mammals_occ_merged_sf, 
         dsn = con, 
         layer = Id(schema = schema, table = table_name_sf), 
         append = FALSE,
         delete_layer = TRUE) # Overwrite the existing table






