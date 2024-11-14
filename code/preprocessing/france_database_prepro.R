# Clean the environment
rm(list = ls())
gc()


# import libraries
library(sf)
library(tidyverse)
library(here)
library(terra)
library(dplyr)

# Set the working directory
setwd("I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\data")
# Load the data
path_ungulates <- "I:/biocon/Magali_Weissgerber/wildE_indicators_draft_240311/Large mammals data/France/eco_met_reseau_os_repartition_ongules_pol_2154/eco_met_reseau_os_repartition_ongules_pol_2154.shp"
ungulates_france <- st_read(path_ungulates)
# names(ungulates_france)

eea_grid_fr_path <- "S:\\Emmanuel_OcegueraConchas\\mammals_darwinCore\\grid_ref_data\\FR\\eea_v_3035_10_km_eea-ref-grid-fr_p_2013_v02_r00\\fr_10km.shp"
eea_grid_fr <- st_read(eea_grid_fr_path)
# names(eea_grid_fr)

# Check the projection
st_crs(ungulates_france)
st_crs(eea_grid_fr)

# Reproject the ungulates data
ungulates_france <- st_transform(ungulates_france, crs = st_crs(eea_grid_fr))

# Check species
spp_names <-  unique(ungulates_france$espece)

# Map species codes to species names
species_names_maps <-  c(
  "CEE" = 'Cervus elaphus',
  "CHA" = 'Rupicapra rupicapra',
  "ISA" = 'Rupicapra pyrenaica', 
  "DAI" = 'Dama dama',
  "MOM" = 'Ovis gmelini musimon x Ovis sp',
  "BOQ" = 'Capra ibex',
  "BOI" = 'Capra pyrenaica',
  "MOC" = 'Ovis gmelini musimon', 
  "CSI" = 'Cervus nippon',
  "MAM" = 'Ammotragus lervia',
  "MUN" = 'Muntiacus reevesi'
)

# Create a new column with the species names
ungulates_france <- ungulates_france %>% 
  mutate(scientificName = species_names_maps[espece])
#View(ungulates_france)

# Map the own species codes to the species names
species_code_map <- c(
  "Cervus elaphus" = "CERELA",
  "Rupicapra rupicapra" = "RUPRUP",
  "Rupicapra pyrenaica" = "RUPPYR",
  "Dama dama" = "DAMDAM",
  "Ovis gmelini musimon x Ovis sp" = "OVIMUS",
  "Ovis gmelini musimon" = "OVIMUS", # New
  "Capra ibex" = "CAPIBE",
  "Capra pyrenaica" = "CAPPYR",
  "Cervus nippon" = "CERNIP",
  "Ammotragus lervia" = "AMMLER", # new
  "Muntiacus reevesi" = "MUNREE" # new
)
# Add the species code to the data
ungulates_france <- ungulates_france %>% 
  mutate(speciesCode = species_code_map[scientificName])
# View(ungulates_france)

# Create a year column base on the date in the code column
ungulates_france <- ungulates_france %>%
  mutate(year = str_sub(code, start = -4, end = -1))
# View(ungulates_france)

# Checks
unique(is.na(ungulates_france$speciesCode)) # False
unique(is.na(ungulates_france$year)) # False 

# check whats is the max and min year in the dataset
year_max <- max(ungulates_france$year)
year_min <- min(ungulates_france$year)

# Get unique years
unique_years <- sort(unique(ungulates_france$year), decreasing = T)
length(unique_years)

# Create separate dataframes for each year
Ungulates_by_year <- list()
for (year in unique_years) {
  year_data <- ungulates_france[ungulates_france$year == year, ]
  Ungulates_by_year[[year]] <- year_data
}

# esier way to create separate dataframes for each year
# Ungulates_by_year <- split(ungulates_france, ungulates_france$year)

# Create a list with species codes using lapply
species_code_by_year <- lapply(Ungulates_by_year, function(x) unique(x$speciesCode))

# loop through the years and species codes
for (year in names(Ungulates_by_year)) {
  year_data <- Ungulates_by_year[[year]]
  species_codes_for_year <- unique(year_data$speciesCode)
  print(paste("Processing year", year))
  
  # Convert to MULTIPOLYGON if needed
  # year_data <- st_cast(year_data, "MULTIPOLYGON")
  
  for (code in species_codes_for_year) {
    print(paste("Processing species code", code))

    year_specific_column <- paste0(code, "_", year)
    
    if (!year_specific_column %in% colnames(eea_grid_fr)) {
      eea_grid_fr[[year_specific_column]] <- 0
    }
    
    # Subset using base R indexing and then apply st_make_valid()
    present_data <- year_data[year_data$speciesCode == code, ]
    present_data <- st_make_valid(present_data)
    
    if (nrow(present_data) > 0) {
      intersects <- sf::st_intersects(eea_grid_fr, present_data, sparse = FALSE)
      eea_grid_fr[[year_specific_column]] <- ifelse(rowSums(intersects) > 0, 1, eea_grid_fr[[year_specific_column]])
    }
    print(paste("Species code", code, "done"))
  }
  print(paste("-----------------Year done"))
}

# checks
unique(eea_grid_fr$DAMDAM_2023) # False

# Visualize to confirm
dam_dam_2023 <- eea_grid_fr[eea_grid_fr$DAMDAM_2023 == 1, ]
plot(st_geometry(dam_dam_2023), col = "red", add = TRUE)

# Compare vs 1990
dam_dam_1990 <- eea_grid_fr[eea_grid_fr$DAMDAM_1990 == 1, ]
plot(st_geometry(dam_dam_1990), col = "yellow", add = TRUE)

# overlap the original data from the species_by_year list
plot(st_geometry(Ungulates_by_year$`1990`), col = "black", add = TRUE)

# Define the output directory for saving files
output_directory <- "raw_data\\France\\ungulates\\eeagrid_ungulates_by_year"

# Ensure the output directory exists
if (!dir.exists(output_directory)) {
  dir.create(output_directory, recursive = TRUE)
}

# Loop over each unique year and save the grid
for (year in unique_years) {
  # Filter columns that correspond to the current year (end with "_<year>")
  year_columns <- grep(paste0("_", year, "$"), colnames(eea_grid_fr), value = TRUE)
  print(year_columns)
  
  # Select columns for the current year, including geometry and grid identifiers
  year_grid <- eea_grid_fr %>%
    select(CELLCODE, EOFORIGIN, NOFORIGIN, all_of(year_columns), geometry)
    mutate(eventID)
  
  # Define the output file path
  output_file <- file.path(output_directory, paste0("eea_grid_fr_", year, ".shp"))
  
  # Save the current year's grid as a shapefile
  terra::writeVector(vect(year_grid), output_file, overwrite = TRUE)
  
  cat("Saved grid for year:", year, "to", output_file, "\n")
}
