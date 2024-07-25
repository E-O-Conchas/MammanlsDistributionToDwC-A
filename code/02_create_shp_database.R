###############################
# Author: Emmanuel Oceguera
# Date: July 2024
#
# Work: This script processes European mammals species distribution shapefiles. 
# It lists all shapefiles by country, merges them with an existing database to include EventIds, 
# identifies any missing shapefiles, and saves the final merged database.
###############################

# Clean the environment
rm(list = ls())
gc()

# Set the working directory
setwd("I://biocon//Emmanuel_Oceguera//projects//Mammals_species_distribution_DarwingCore//output")
getwd()

# Import necessary libraries
library(tidyverse)
library(sf)
library(stringr)

# Define the directory containing all the European shapefiles
dir_europe <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/output"
country_dirs <- list.dirs(dir_europe, recursive = F, full.names = T)

# Create an empty data frame to store the results
results <- data.frame(country = character(), shapefile_name = character(), stringsAsFactors = F)

# List of shapefiles by country
shapefiles_by_country <- list()

# Loop through each country directory and list all .shp files
for (country_dir in country_dirs) {
  country_name <- basename(country_dir)
  shp_files <- list.files(country_dir, pattern = "\\.shp$", full.names = TRUE)
  shapefiles_by_country[[country_name]] <- shp_files
}

# Create the results data frame by looping through shapefiles by country
for (country in names(shapefiles_by_country)) {
  shp_files <- shapefiles_by_country[[country]]
  country_shp_df <- data.frame(country = country, shapefile_name = basename(shp_files), stringsAsFactors = FALSE)
  results <- bind_rows(results, country_shp_df)
}

# Import the CSV file with the EventId included
csv_path <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/data/in_process/europe/10072024/shapefiles_database.csv"
shp_dataBase <- read.csv(csv_path)

# Update the index in shp_dataBase
shp_dataBase <- shp_dataBase %>% 
  mutate(ID = row_number())

# Perform an anti-join to find rows in 'results' that are not in 'shp_dataBase'
missing_rows <- results %>%
  anti_join(shp_dataBase, by = c("shapefile_name" = "BaseName"))

# Add eventId to results based on matching shapefile_name
shp_database_final <- results %>% 
  mutate(eventId = ifelse(shapefile_name %in% shp_dataBase$BaseName, 
                          shp_dataBase$eventId[match(shapefile_name, shp_dataBase$BaseName)], 
                          NA))

# Save the final database to a CSV file
root <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/data/in_process/europe/10072024"
write.csv(shp_database_final, paste0(root, "/database_shp_by_country.csv"), row.names = FALSE)
