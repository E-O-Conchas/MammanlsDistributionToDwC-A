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
setwd("I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\github\\MammanlsDistributionToDwC-A")

# Load the data
root <- 'I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\data\\raw_data\\Poland'

# Set the output folder 
output_root <- "I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\output\\raw_species_by_country"
output_dir <- file.path(output_root, "Poland")

# Read csv
# Read csv
csv_path <- file.path(root, "0021372_fixed.csv")
species_distribution <- read.csv(csv_path, header = TRUE)
View(species_distribution)

# We define the species code map
species_list <- c(
  "Alces alces", 
  "Cervus elaphus", 
  "Rupicapra rupicapra",
  "Capreolus capreolus", 
  "Dama dama", 
  "Sus scrofa", 
  "Cervus nippon",
  "Ovis ammon"
  )

species_dis_filtered <- species_distribution %>% 
  filter(species %in% species_list)

# ungulates
# | Taxon Code | Scientific Name     |
# | ---------- | ------------------- |
# | **alcalc** | Alces alces         |
# | **cerela** | Cervus elaphus      |
# | **ruprup** | Rupicapra rupicapra |
# | **susscr** | Sus scrofa          |
# | **capcap** | Capreolus capreolus |
# | **damdam** | Dama dama           |
# | **cernip** | Cervus nippon       |
# | **oviamm** | Ovis ammon          |

# # Carnivors   
#   **bisbon** | Bison bonasus    
#   **canlup** | Canis lupus     
#   **ursarc** | Ursus arctos 
#   **lynlyn** | Lynx lynx 

species_dis_filtered
# conver to a sf object 
species_dis_filtered_sf <- st_as_sf(species_dis_filtered,
                                    coords = c("decimalLongitude", "decimalLatitude"), 
                                    crs = 4326)  # WGS84
# reproject to LAEA Europe 3035
species_dis_filtered_sf <- st_transform(species_dis_filtered_sf, crs=3035)

# we save it to check it:
file_path <- file.path(output_dir,"filtered_species_test.shp")
st_write(species_dis_filtered_sf, file_path)

# Import eea grid
eea_grid_pl_path <- "data\\grid_ref_data\\poland\\pl_10km.shp"
eea_grid_pl <- st_read(eea_grid_pl_path)

# Reproject the ungulates data
species_dis_filtered_sf <- st_transform(species_dis_filtered_sf, crs = st_crs(eea_grid_pl))


# Check the unique species
spp_names <- unique(species_dis_filtered_sf$species)


# Map the species code
species_code_map <- c(
  "Dama dama" = "DAMDAM", 
  "Alces alces" = "ALCALC",
  "Rupicapra rupicapra" = "RUPRUP",
  "Cervus elaphus" = "CERELA",
  "Sus scrofa" = "SUSSCR",
  "Capreolus capreolus" = "CAPCAP",
  "Cervus nippon" = "CERNIP",
  "Ovis ammon" = "OVIAMM"
)

# Add the species code to the data
ungulates_poland <- species_dis_filtered_sf %>% 
  mutate(speciesCode = species_code_map[species])
# check
unique(ungulates_poland$speciesCode)

# check max an min year
year_max <- max(ungulates_poland$year)
year_min <- min(ungulates_poland$year)
# time period 1987-2020

# Get unique year
unique_years <- sort(unique(ungulates_poland$year), decreasing = T)
unique_species  <- unique(ungulates_poland$species)

# Create a separate df for each of the species
ungulates_poland_spp <- list()

for(sp in unique_species){
  sp_data <-  ungulates_poland[ungulates_poland$species == sp, ]
  ungulates_poland_spp[[sp]] <- sp_data
}

# We process the ungulates by species, but in Order to not lose the year information
# We need to loop this by year for each of the species, so we dont lose the year info by species
# otherwise we  wont know which grids are for wichi years
ungulates_poland_spp_year <- list()

for (year in unique_years){
  cat("processing year:", year, "\n")
  # Create a copy of the grid for this year
  eea_grid_year <- eea_grid_pl
  
  # Now we loop over the species
  for (sp in names(ungulates_poland_spp)){
    cat("processing species:", sp, "for the year:", year, "\n") 
    
    species_data <-  ungulates_poland_spp[[sp]] # extract the data by the species names
    species_data$year <- as.character(species_data$year)
    species_data_year <- species_data[species_data$year == year,] # Filter by year
    
    # make valid the data
    species_data_year <- st_make_valid(species_data_year)
    
    # Initialize a column in the grid for this specie and year
    species_column  <-  species_code_map[sp]
    # Start the species column in the Grid
    if (!species_column %in% colnames(eea_grid_year)){
      eea_grid_year[[species_column]] <- 0
    }
    
    # Compute spatial intersection to update the grid
    if (nrow(species_data_year) > 0) {
      # Spatial intersection
      intersects <- sf::st_intersects(eea_grid_year, species_data_year, sparse = F)
      eea_grid_year[[species_column]] <- ifelse(rowSums(intersects) > 0 , 1, eea_grid_year[[species_column]])
      # eea_grid_year$geometry <- st_sfc(eea_grid_year$geometry)
      # eea_grid_year <- st_as_sf(eea_grid_year)
    }
    cat("Specie:", sp, "for year:", year,"processed\n")
  }
  
  # Save the grid for the current in the results list
  ungulates_poland_spp_year[[as.character(year)]] <- eea_grid_year
  cat("year:", year, "processing completed\n")
}

# Over all check for
lapply(ungulates_poland_spp_year, function(grid) {
  grid %>%
    st_drop_geometry() %>%
    summarize(across(everything(), ~ sum(. > 0, na.rm = TRUE)))
})


# Check
View(ungulates_poland_spp_year)
View(ungulates_poland_spp_year[['2020']])

#  We process first one year
eea_grid_pl_2020 <- ungulates_poland_spp_year[['2020']]
# 
# $`2020`
# CELLCODE EOFORIGIN NOFORIGIN    DAMDAM ALCALC RUPRUP CERELA SUSSCR CAPCAP CERNIP OVIAMM
# 1     4047      4047      4047      4    102      1      0      0      0      0      4

eea_grid_pl_1987 <- ungulates_poland_spp_year[['1987']]
View(eea_grid_pl_1987)

# $`1987`
# CELLCODE EOFORIGIN NOFORIGIN      DAMDAM ALCALC RUPRUP CERELA SUSSCR CAPCAP CERNIP OVIAMM
# 1     4047      4047      4047      0      1      0      0      0      0      0      0

# checks
unique(eea_grid_pl_2020$ALCALC)
unique(eea_grid_pl_1987$ALCALC)

# Visualitation test:
# importa libraries
library(giscoR)
library(ggplot2)

poland <- gisco_get_countries(res = "10", country = "PL", epsg = 3035)
nuts_pl <- gisco_get_nuts(nuts_level = 2, country = "PL", epsg = 3035)

ALCALC_2020 <- eea_grid_pl_2020[eea_grid_pl_2020$ALCALC == 1, ]
ALCALC_1987 <- eea_grid_pl_1987[eea_grid_pl_1987$ALCALC == 1, ]

ggplot() +
  geom_sf(data = nuts_pl, fill = NA, color = "darkgray")+
  geom_sf(data = ALCALC_2020, fill = "lightblue", color = NA)+
  theme_minimal()
  
# Add year column
ALCALC_1987$year <- "1987"
ALCALC_2020$year <- "2020"

# Combine into one object
alcalc_compare <- rbind(ALCALC_1987, ALCALC_2020)

ggplot() +
  geom_sf(data = gisco_get_countries(country = "PL", epsg = 3035), fill = "gray95", color = "black") +
  geom_sf(data = alcalc_compare, aes(fill = year), color = NA, alpha = 0.8) +
  facet_wrap(~year) +
  scale_fill_manual(values = c("1987" = "goldenrod", "2020" = "red")) +
  labs(title = "Alces alces distribution in Poland",
       subtitle = "Comparison: Earliest (1987) vs Most Recent (2020)") +
  theme_minimal()



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
output_directory <- "output\\data\\poland\\ungulates"

# Ensure the output directory exists
if (!dir.exists(output_directory)) {
  dir.create(output_directory, recursive = TRUE)
}

# We create the species list by year as references
species_list <- lapply(ungulates_poland_spp_year, function(grid) {
  grid %>%
    st_drop_geometry() %>%
    summarize(across(everything(), ~ sum(. > 0, na.rm = TRUE))) %>%
    select(where(~ . > 0)) %>%
    names()
})

print(species_list)
names(ungulates_poland_spp_year[[1]])

# Flatten the species list to get unique speices acroos   
unique_species <- unique(unlist(species_list))[4:11]


# Loop over each unique year and save the grid
for (year in names(ungulates_poland_spp_year)) {
  
  data_year <- ungulates_poland_spp_year[[year]] %>% 
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
      mutate(eventID = "OKAPL10336") # Set the right eventID
    
    # Define the output file path for the species within the year folder
    output_file <- file.path(year_folder, paste0("M_", toupper(species_code), ".shp"))
    
    # Write the shapefile
    terra::writeVector(vect(species_data), output_file, overwrite = TRUE)
  }
}



##### Count species by cells
# Extract species columns from any year (they are the same)
species_codes <- names(ungulates_poland_spp_year[[1]])
species_codes <- species_codes[!(species_codes %in% c("CELLCODE", "EOFORIGIN", "NOFORIGIN", "geometry"))]

# Count presence by year
cell_counts_by_year <- lapply(ungulates_poland_spp_year, function(grid) {
  grid %>%
    st_drop_geometry() %>%
    summarize(across(all_of(species_codes), ~ sum(. == 1, na.rm = TRUE)))
})

# Combine into one data.frame
cell_counts_df <- bind_rows(cell_counts_by_year, .id = "year")

# Sum across all years for each species (repeated cell = repeated count)
total_cell_counts <- cell_counts_df %>%
  select(all_of(species_codes)) %>%
  summarise(across(everything(), sum))

print(total_cell_counts)





