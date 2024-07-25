#######################################
# Author: Emmanuel Oceguera
# Date: July 2024
#  
# Work: This script processes European mammals species distribution shapefiles by country and species. 
# It reads shapefiles, filters species occurrences within each country, 
# and exports the results to new shapefiles. 
#######################################



# Load necessary libraries
library(sf)
library(dplyr)
library(stringr)

# Set the working directory
setwd("I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore")
dir_europe <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/data/occurrances_data/raw_data_by_country"

# List of species IDs
species_list <- c("alcalc", "capibe", "cappyr", "cerela", "ruprup", "susscr", "capcap", "bisbon", "capaeg",
                  "lynpar", "ruppyr", "rantar", "ruporn", "canlup", "ursarc", "lynlyn", "gulgul")

# Add "m_" prefix to match with the column names
species_list_columns <- paste0("m_", species_list)

# Function to create output directory if it doesn't exist
create_output_dir <- function(directory) {
  if (!dir.exists(directory)) {
    dir.create(directory, recursive = TRUE)
  }
}

# Function to process each shapefile (each species by country)
process_shapefile <- function(country_name, species_code, country_layer, sp_occ_layer, ea_grid, output_base_dir) {
  # Select country
  country_selection <- country_layer %>%
    filter(CNTR_ID == country_name) # Adjust the column name as needed
  
  # Select species occurrences within the country
  species_selection <- st_intersection(sp_occ_layer, country_selection) %>%
    filter(.data[[species_code]] %in% c(1, 9)) %>%
    rename(CellCode = cellcode)
  
  # Check if the species_selection has polygon geometries
  if (!any(st_geometry_type(species_selection) %in% c("POLYGON", "MULTIPOLYGON"))) {
    cat("Skipping", species_code, "for", country_name, "- no polygon geometries.\n")
    return(NULL)
  }
  
  # Check if the species_selection has relevant information
  if (nrow(species_selection) == 0) {
    cat("Skipping", species_code, "for", country_name, "- no relevant species data.\n")
    return(NULL)
  }
  
  # Join the species occurrences back to the original grid based on CellCode
  spp_eea_grid <- ea_grid %>%
    st_join(species_selection, by = 'CellCode')
  
  # Filter to keep only grid cells with species occurrences
  spp_eea_grid_filtered <- spp_eea_grid %>%
    filter(!is.na(.data[[species_code]])) %>%
    select(-CellCode.y, -eoforigin, -noforigin) %>%
    rename(cellcode = CellCode.x)
  
  # Remove duplicate CellCode entries
  spp_eea_grid_filtered <- spp_eea_grid_filtered[!duplicated(spp_eea_grid_filtered$cellcode), ]
  
  # Check if the filtered grid has any rows left
  if (nrow(spp_eea_grid_filtered) == 0) {
    cat("Skipping", species_code, "for", country_name, "- no data after filtering.\n")
    return(NULL)
  }
  
  # Define the output directory and file path
  output_dir <- file.path(output_base_dir, country_name)
  create_output_dir(output_dir)
  
  output_file <- file.path(output_dir, paste0(toupper(species_code), ".shp"))
  
  # Export the selected features to a new shapefile
  st_write(spp_eea_grid_filtered, output_file, append = FALSE, delete_layer = TRUE, quiet = TRUE)
  cat("Exported", species_code, "data for", country_name, "to", output_file, "/n")
}

# Read the country layer and species occurrence layer
country_layer <- st_read("data/boundaries_shp/admin_boundaries_EU+ctry.shp")
country_layer_3035 <- st_transform(country_layer, 3035)

ea_grid <- st_read("S:/Emmanuel_OcegueraConchas/data/Europe_ref_grid/europe_10km.shp")
sp_occ_layer <- st_read("data/occurrances_data/sp_occu_20190829.shp")
sp_occ_layer_3035 <- sp_occ_layer %>%
  st_transform(3035)

# Loop through each country and species
for (country_name in unique(country_layer_3035$CNTR_ID)) {
  for (species_code in species_list_columns) {
    process_shapefile(country_name, species_code, country_layer_3035, sp_occ_layer_3035, ea_grid, dir_europe)
  }
}

cat("Process completed./n")
