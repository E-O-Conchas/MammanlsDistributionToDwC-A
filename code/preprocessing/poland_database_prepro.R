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
root <- 'I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\data\\raw_data\\Poland'

# Set the output folder 
output_root <- "I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\output\\raw_species_by_country"
output_dir <- file.path(output_root, "Poland")

# Read csv



# List all the shp files in the EE folder
shp <- list.files(root, pattern = ".shp$", full.names = TRUE)

# load all the sho files listes in the above root
ungulates <- list()
View(ungulates)

for (shp_path in shp){  
  # extract only the basenames
  species_name <-  str_remove(basename(shp_path), ".shp")
  species_name_clean <-  str_remove(species_name, "EE_")
  #open data set
  spp <- st_read(shp_path)
  
  # attached the shp file to the ungulates list
  #ungulates[[basename]] <- spp 
  # Skip if not year column
  if(!"year" %in% colnames(spp)){
    warning(paste("No 'year' column in:", species_name_clean))
    next # we pass to the next loop if there is not issues
  }
  
  # We loop over the unique year
  for (yr in unique(spp$year) ){
    
    # Skip Na years
    if(is.na(yr)) next
    
    # we subset for that year
    spp_year <- spp %>% filter(year == yr)
    
    # Ensure the column is present
    spp_year$year <- yr
    
    # Create the folder
    year_folder <- file.path(output_dir, as.character(yr))
    #dir.create(year_folder)
    
    #cat(year_folder, "\n")
    # We append the final result into a list by species
    #ungulates[[species_name_clean]] <- spp_year
    
    year_key <- as.character(yr)
    #Define the output path
    #out_path <-  file.path(year_folder, paste0(species_name_clean, ".shp"))
    if(is.null(ungulates[[year_key]])){
      ungulates[[year_key]] <- list()
    }
    #Save the final result
    # st_write(spp_year,  out_path, append = FALSE, quiet = TRUE)
    ungulates[[year_key]][[species_name_clean]] <- spp_year
  }
}

names(ungulates[["2018"]])
View(ungulates)
names(ungulates[["2018"]][["M_SUSSCR"]])

# Open the grid reference at 10km for Estonia
eea_grid_ee_path <- "data/grid_ref_data/estonia/ee_10km.shp"
eea_grid_ee <- st_read(eea_grid_ee_path)

# head(eea_grid_fr)
# names(eea_grid_fr)

# Check the projection
ungulates <- lapply(ungulates, function(year_data){
  lapply(year_data, function(spp){
    st_transform(spp, crs = st_crs(eea_grid_ee))
  })
})



ungulates[["2018"]][["M_SUSSCR"]]$speciesCode


# Map the own species codes to the species names
species_code_map <- c(
  "Alces alces"= "ALCALC",
  "Cervus elaphus" = "CERELA",
  "Capreolus capreolus" = "CAPCAP",
  "Sus scrofa" = "SUSSCR"
)



# Add species code to the data
ungulates <- lapply(ungulates, function(year_data){
  lapply(year_data, function(spp){
    spp %>%
      mutate(speciesCode = species_code_map[as.character(species)])
  })
})

ungulates[["2018"]][["M_SUSSCR"]]$species
View(ungulates[["2018"]][["M_SUSSCR"]])

names(ungulates[["2018"]][["M_SUSSCR"]])


# Ungulates by yeas. This can be done before but I just realize after processing,
ungulates_by_year <- list()

wanted_cols <- c("occurrence", "species", "year", "speciesCode", "geometry")

for ( yr in names(ungulates)){
  species_list <- ungulates[[yr]]
  
  species_list_filtered <- lapply(species_list, function(spp){
    spp %>%
      select(any_of(wanted_cols) )
    
  })
  
  #Combine all species sf object into one table
  full_year_table <- do.call(rbind, species_list_filtered)
  
  ungulates_by_year[[yr]] <- full_year_table
  
}

unique(ungulates_by_year[["2018"]]$species)

# Delete one year not valid
ungulates_by_year[["0"]] <- NULL

years <- as.integer(names(ungulates_by_year))

# check whats is the max and min year in the dataset
year_max <- max(years)
year_min <- min(years)

# Get unique years
unique_years <- sort(unique(years), decreasing = T)
length(unique_years)
unique_species <- unique(ungulates_by_year[["2018"]]$speciesCode)

# Create a sepatate dataframe for each of the species
estonia_ungualates_spp <- list()
for (sp in unique_species){
  all_year_data <- lapply(ungulates_by_year, function(year_df){
    year_df[year_df$speciesCode == sp, ]
  })
  
  estonia_ungualates_spp[[sp]] <- do.call(rbind, all_year_data)
}

names(estonia_ungualates_spp)

# We process the ungulates by species, but in Order to not lose the year information
# We need to loop this by year for each of the species, so we dont lose the year info by species
# otherwise we  wont know which grids are for wichi years
results_by_year <- list()


for (year in unique_years){
  cat("processing year:", year, "\n")
  # Create a copy of the grid for this year
  eea_grid_year <- eea_grid_ee
  
  # Now we loop over the species
  for (sp in names(estonia_ungualates_spp)){
    cat("processing species:", sp, "for the year:", year, "\n") 
    
    species_data <-  estonia_ungualates_spp[[sp]] # extract the data by the species names
    species_data$year <- as.character(species_data$year)
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
      eea_grid_year$geometry <- st_sfc(eea_grid_year$geometry)
      eea_grid_year <- st_as_sf(eea_grid_year)
    }
    cat("Specie:", sp, "for year:", year,"processed\n")
  }
  
  # Save the grid for the current in the results list
  results_by_year[[as.character(year)]] <- eea_grid_year
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


#  We process first one year
eea_grid_ee_2016 <- results_by_year[['2016']]
# 
# $`2016`
# CELLCODE EOFORIGIN NOFORIGIN ALCALC CAPCAP CERELA SUSSCR
# 1     1122      1122      1122     70    120      5     44

eea_grid_ee_1980 <- results_by_year[['1980']]




# checks
unique(eea_grid_ee_2016$ALCALC)
unique(eea_grid_ee_1980$ALCALC)

# Visualize to confirm
ALCALC_2016 <- eea_grid_ee_2016[eea_grid_ee_2016$ALCALC == 1, ]
plot(st_geometry(ALCALC_2016), col = "red")

# Compare vs 1980
ALCALC_1980 <- eea_grid_ee_1980[eea_grid_ee_1980$ALCALC == 1, ]
plot(st_geometry(ALCALC_1980), col = "yellow", add = TRUE)

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
output_directory <- "output\\data\\estonia\\ungulates"

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
unique_species <- unique(names(results_by_year[[1]]))[5:8]

backup <- results_by_year

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
      mutate(eventID = "ROAEE1485") # Set the right eventID
    
    # Define the output file path for the species within the year folder
    output_file <- file.path(year_folder, paste0("M_", toupper(species_code), ".shp"))
    
    # Write the shapefile
    terra::writeVector(vect(species_data), output_file, overwrite = TRUE)
  }
}
