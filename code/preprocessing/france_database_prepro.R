# Clean the environment
rm(list = ls())
gc()


# import libraries
library(sf)
library(tidyverse)
library(here)
library(terra)
library(dplyr)


# # Set the working directory, since the project is not storage in the github repository
# we set our work directory where the github repository is
# setwd("I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\github\\MammanlsDistributionToDwC-A")



# Load the data
path_ungulates <- 'data/large_mammals/france/eco_met_reseau_os_repartition_ongules_pol_2154.shp'
ungulates_france <- st_read(path_ungulates)
# View(ungulates_france)
# names(ungulates_france)

eea_grid_fr_path <- "data/grid_ref_data/france/fr_10km.shp"
eea_grid_fr <- st_read(eea_grid_fr_path)
# head(eea_grid_fr)
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
View(ungulates_france)

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
#View(ungulates_france)

# Create a year column base on the date in the code column
ungulates_france <- ungulates_france %>%
  mutate(year = str_sub(code, start = -4, end = -1))
View(ungulates_france)




# Checks
unique(is.na(ungulates_france$speciesCode)) # False
unique(is.na(ungulates_france$year)) # False 

# check whats is the max and min year in the dataset
year_max <- max(ungulates_france$year)
year_min <- min(ungulates_france$year)

# Get unique years
unique_years <- sort(unique(ungulates_france$year), decreasing = T)
length(unique_years)
unique_species <- unique(ungulates_france$speciesCode)

# Create a sepatate dataframe for each of the species
france_ungualates_spp <- list()
for (sp in unique_species){
  sp_data <- ungulates_france[ungulates_france$speciesCode == sp, ]
  france_ungualates_spp[[sp]] <- sp_data
}

# View(france_ungualates_spp[[1]])

# We process the ungulates by species, but in Order to not lose the year information
# We need to loop this by year for each of the species, so we dont lose the year info by species
# otherwise we  wont know which grids are for wichi years
results_by_year <- list()
for (year in unique_years){
  cat("processing year:", year, "\n")
  # Create a copy of the grid for this year
  eea_grid_year <- eea_grid_fr
  
  # Now we loop over the species
  for (sp in names(france_ungualates_spp)){
    cat("processing species:", sp, "for the year:", year, "\n")
    
    species_data <-  france_ungualates_spp[[sp]] # extract the data by the species names
    species_data_year <- species_data[species_data$year == year,] # Filter by year
    
    # make valid the data
    species_data_year <- st_make_valid(species_data_year)
    
    # Initialize a column in the grid for this specie and year
    species_column  <-  sp
    # Start the species column in the Grid
    if (!species_column %in% colnames(eea_grid_year)){
      eea_grid_year[[species_column]] <- 0
    }
    
    # Compute spatial intersection to update the grid
    if (nrow(species_data_year) > 0) {
      # Spatial intersection
      intersects <- sf::st_intersects(eea_grid_year, species_data_year, sparse = F)
      eea_grid_year[[species_column]] <- ifelse(rowSums(intersects) > 0 , 1, eea_grid_year[[species_column]])
      
    }
    cat("Specie:", sp, "for year:", year,"processed\n")
  }
  # Save the grid for the current in the results list
  results_by_year[[year]] <- eea_grid_year
  cat("year:", year, "processing completed\n")
}


# Over all check for
lapply(results_by_year, function(grid) {
  grid %>%
    st_drop_geometry() %>%
    summarize(across(everything(), ~ sum(. > 0, na.rm = TRUE)))
})


# Check
View(results_by_year)
View(results_by_year[['2023']])
unique(results_by_year[['2022']]$RUPRUP)


#  We process first one year
eea_grid_fr_2016 <- results_by_year[['2016']]
# 
# $`2016`
# CELLCODE EOFORIGIN NOFORIGIN CERELA RUPRUP RUPPYR DAMDAM OVIMUS CAPIBE CAPPYR CERNIP AMMLER MUNREE
# 1     9978      9978      9978      0    615    140      0    287    140     12      0      0      0

eea_grid_fr_1987 <- results_by_year[['1987']]
# $`1987`
# CELLCODE EOFORIGIN NOFORIGIN CERELA RUPRUP RUPPYR DAMDAM OVIMUS CAPIBE CAPPYR CERNIP AMMLER MUNREE
# 1     9978      9978      9978      0    436    114      0    204      0      0      0      0      0

# checks
unique(eea_grid_fr_2016$RUPRUP)
unique(eea_grid_fr_1987$RUPRUP)

# Visualize to confirm
RUPRUP_2016 <- eea_grid_fr_2016[eea_grid_fr_2016$RUPRUP == 1, ]
plot(st_geometry(RUPRUP_2016), col = "red")

# Compare vs 1987
RUPRUP_1987 <- eea_grid_fr_1987[eea_grid_fr_1987$RUPRUP == 1, ]
plot(st_geometry(RUPRUP_1987), col = "yellow", add = TRUE)

# Hybrid Approach
# 
# Keep the specific years in the occurrences table while summarizing the full year range in the eventID.
# For example:
#   In the events table: yearIni = 1900, yearEnd = 2023.
# In the occurrences table: Each occurrence retains its specific year.
# Advantages:
#   Captures granular details while aligning with existing structure.
#   Provides flexibility for queries by specific years or ranges.
# Disadvantages:
#   Requires adjustments to the Darwin Core archive generation process.



# Define the output directory for saving files
getwd()
output_directory <- "output\\data\\france\\ungulates"

# Ensure the output directory exists
if (!dir.exists(output_directory)) {
  dir.create(output_directory, recursive = TRUE)
}

# We create the species list by year as references
species_list <- lapply(results_by_year, function(grid) {
  grid %>%
    st_drop_geometry() %>%
    summarize(across(everything(), ~ sum(. > 0, na.rm = TRUE))) %>%
    select(where(~ . > 0)) %>%
    names()
})
  
print(species_list)
names(results_by_year[[1]])

# Flatten the species list to get unique speices acroos   
# unique_species <- unique(unlist(species_list))[4:13]
unique_species <- unique(names(results_by_year[[1]]))[5:14]
  
# Loop over each unique year and save the grid
for (year in names(results_by_year)) {
  
  data_year <- results_by_year[[year]] %>% 
    mutate(YEAR = year) # Add the year column
  
  # Define year folder 
  year_folder <- file.path(output_directory, year)
  #print(year_folder)
  
  if (!dir.exists(year_folder)){
    dir.create(year_folder, recursive = T)
  }
  
  # We loop over each species
  for(species_code in unique_species){
    
    if(!(species_code %in% colnames(data_year))){
      cat("species:", species_code, "not found in year:", year, "\n")
      next
    }
    
    if (sum(data_year[[species_code]] > 0, na.rm = T) == 0){
      next
    }
    
    new_column_name <-  paste0("m_", tolower(species_code))
    
    # Filter the data for the current species and rename columns
    species_data <- data_year %>% 
      select(CELLCODE, EOFORIGIN, NOFORIGIN, YEAR, all_of(species_code), geometry) %>%
      rename(!!new_column_name := all_of(species_code)) %>%
      mutate(eventID = "NOJH6465") # Set the right eventID

    # Define the output file path for the species within the year folder
    output_file <- file.path(year_folder, paste0("M_", toupper(species_code), ".shp"))
    
    # Write the shapefile
    terra::writeVector(vect(species_data), output_file, overwrite = TRUE)
  }
}






### Calcaulate some metrics let it for the future
# 
# # find out the total number of cell across all the year for species
# # Select the species-year columns
# distribution_columns <- colnames(eea_grid_fr_1987)[5:14]
# 
# # Pivot the data to long format for easier grouping and summarization
# distribution_long <- eea_grid_fr_1987 %>%
#   st_drop_geometry() %>% # Drop the geometry for simpler processing
#   pivot_longer(
#     cols = all_of(distribution_columns),
#     names_to = c("species", "year"),
#     names_sep = "_",
#     values_to = "presence"
#   )
# # View(distribution_long)
# 
# # Filter only the rows where presence is 1
# distribution_summary <- distribution_long %>%
#   filter(presence > 0) %>% # Keep only presence data
#   group_by(species, year) %>% # Group by species and year
#   summarize(total_cells = n(), .groups = "drop") # Count the number of cells
# # View(distribution_summary)
# 
# # Summarize the total cells by year across all species
# yearly_summary <- distribution_summary %>%
#   group_by(year) %>%
#   summarize(total_cells = sum(total_cells), .groups = "drop")
# # View(yearly_summary)
# 
# # Summarize total cells by species across all years
# species_summary <- distribution_long %>%
#   filter(presence > 0) %>% # Keep only presence data
#   group_by(species) %>% # Group by species only
#   summarize(total_cells = n(), .groups = "drop") # Count the number of cells
# #View(species_summary)
# 
# species_names_aligned <- tolower(unique(species_summary$species))
# species_names_aligned <-  paste0("FR_M_", unique(species_summary$species))
# 
# 
# 
# 
