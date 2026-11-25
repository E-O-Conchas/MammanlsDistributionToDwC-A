#######################################
# Author: Emmanuel Oceguera
# Date: July 2024
# 
# Work: This script prepares and processes spatial data for mammals distribution. It includes setting up the 
# environment, importing data and libraries, and ensuring each shapefile is annotated with relevant metadata. 
# The script loops through directories, processes files, adds necessary columns, and verifies data integrity, 
# ensuring compatibility with standardized formats for further analysis and integration.
#######################################

# Clean the environment
rm(list = ls())
gc()

# Set working directory
setwd("I://biocon//Emmanuel_Oceguera//projects//Mammals_species_distribution_DarwingCore//output")
getwd()

# Import necessary libraries
library(tidyverse)
library(sf)
library(stringr)

# Import reference shapefiles database
shapefiles_info <- read.csv("I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/data/in_process/europe/10072024/01database_shp_by_country.csv",
                            sep = ",",
                            header = TRUE)

# Define directory containing all European shapefiles
dir_europe <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/output"
country_dirs <- list.dirs(dir_europe, recursive = FALSE, full.names = TRUE)

# Create a list to store shapefiles by country
shapefiles_by_country <- list()

# Loop through each country directory and store the shapefiles
for (country_dir in country_dirs) {
  country_name <- basename(country_dir)
  shp_files <- list.files(country_dir, pattern = "\\.shp$", full.names = TRUE)
  shapefiles_by_country[[country_name]] <- shp_files
}

# Ensure there are no leading or trailing spaces in the shapefile names
shapefiles_info$shapefile_name <- trimws(shapefiles_info$shapefile_name)

# Loop through each country and their corresponding shapefiles
for (country in names(shapefiles_by_country)) {
  shp_files <- shapefiles_by_country[[country]]
  
  for (shp_file in shp_files) {
    base_name <- basename(shp_file)
    
    # Find the corresponding eventID using both the country and the BaseName
    event_row <- shapefiles_info %>%
      filter(shapefile_name == base_name & country == country)
    
    if (nrow(event_row) == 1) {
      event_id <- event_row$eventId
      
      cat("This is the event ID:", event_id, "\n")
      
      if (file.exists(shp_file)) {
        # Read the shapefile
        shapefile_data <- st_read(shp_file, quiet = TRUE)
        
        # Add the eventID as a new column
        shapefile_data <- shapefile_data %>%
          mutate(eventID = event_id)
        
        # Save the modified shapefile (overwrite the existing file)
        st_write(shapefile_data, shp_file, delete_layer = TRUE, quiet = TRUE)
        
        # Confirm that the file has been saved
        cat("Updated shapefile saved at:", shp_file, "\n")
      } else {
        cat("The file does not exist:", shp_file, "\n")
      }
    } else {
      cat("No corresponding eventID found for:", base_name, "in country:", country, "\n")
    }
  }
}

# Verification step to ensure all shapefiles have an eventID column
for (country in names(shapefiles_by_country)) {
  shp_files <- shapefiles_by_country[[country]]
  
  for (shp_file in shp_files) {
    if (file.exists(shp_file)) {
      shapefile_data <- st_read(shp_file, quiet = TRUE)
      
      if (!"eventID" %in% colnames(shapefile_data)) {
        cat("Warning: The shapefile", shp_file, "does not contain the eventID column.\n")
      }
    }
  }
}

cat("Process completed.\n")
