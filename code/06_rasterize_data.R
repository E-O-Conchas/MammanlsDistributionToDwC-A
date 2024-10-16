# Work: This script is used to rasterize one specie distribution shapefile using the terra package in R.
# The shapefile is storage in a database in PostgreSQL and the connection is made using the SQLServer package.

getwd()

# Remove all the objects from the current workspace
rm(list = ls())
gc()

# Load the necessary library
library(terra)
library(RPostgres)
library(DBI)
library(yaml) # To read the configuration file
library(sf)
library(tidyverse)

# Access the configuration file
config_path <- "I:/biocon/Emmanuel_Oceguera/projects/Mammals_species_distribution_DarwingCore/config/config.yml"
config <- yaml::read_yaml(config_path)


# Get the connection parameters
db_host <- config$db$host
db_port <- config$db$port
db_name <- config$db$name
db_user <- config$db$user
db_password <- config$db$password

# Stable connection to the database
con <- dbConnect(RPostgres::Postgres(), dbname = db_name, host = db_host, port = db_port, user = db_user, password = db_password)

#Quesry to join occurrence and event tables and filter fo Alces alces
query <- "
SELECT o.*, e.\"yearIni\", e.\"yearEnd\", e.\"eventData\" 
FROM eu_mammals_darwin_core.mammals_ungulates_dwc_occ_sf o
JOIN eu_mammals_darwin_core.mammals_dwc_event e
ON o.\"eventID\" = e.\"eventID\"
WHERE o.\"scientificName\" = 'Alces alces' 
AND o.\"presence\" != 0"


# Read the data into an sf objec
alces_alces_sf <- st_read(con, query = query)
View(alces_alces_sf)
str(alces_alces_sf)


# convert the years to numeric
alces_alces_sf <- alces_alces_sf %>% 
  mutate(yearIni = as.numeric(yearIni), yearEnd = as.numeric(yearEnd))

# We read the eea 10 km
path_eea <- "S:\\Emmanuel_OcegueraConchas\\data\\Europe_ref_grid\\europe_10km.shp"
eea_10km <- st_read(path_eea)

# We rasterize the eea 10 km to be able to rasterize the species distribution
extent_grid <- st_bbox(eea_10km)
resolution <- 10000

# Create a raster using the extent values from the bounding box
eea_10km_raster <- terra::rast(xmin = extent_grid["xmin"], 
                               xmax = extent_grid["xmax"],
                               ymin = extent_grid["ymin"], 
                               ymax = extent_grid["ymax"],
                               resolution = resolution)
crs(eea_10km_raster) <- "epsg:3035" 


# Impute a default year for NA values, for example, 2000
alces_alces_sf_no_na <- alces_alces_sf %>%
  filter(!is.na(yearIni) & !is.na(yearEnd))

year_ranges_ <- unique(alces_alces_sf_no_na$yearIni)

# Get unique years or year ranges
year_ranges <- sort(unique(alces_alces_sf$yearIni))

# chekc status
status <- unique(alces_alces_sf$presence)

"1 = presence
5 = extinct
9 = sporadic"

output_file <- "I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\output\\rasters_species"
subDir <- "Alces_alces_rast"

# Extract the unique years 
unique_year_Init <- sort(unique(alces_alces_sf$yearIni))
unique_year_End <- sort(unique(alces_alces_sf$yearEnd))

# We define key years
key_years <- c(1980, 1995, 2005, 2015, 2020)
years <- c(1890, 1980, 1981, 1990, 1995, 2005, 2013, 2015, 2018)


# Create an empty list to store the rasters for those that have year and missing years
alce_alce_rasters <- list()

### Rasterize the data
# Filter occurrences for the time range 1890 to 2020
current_data <- alces_alces_sf %>%
  filter(yearIni >= 1890 & yearEnd <= 2020)

# Convert to SpatVector for rasterization
vect_data <- vect(current_data)

# Rasterize the data for the entire time range using the "presence" field
alces_alces_rast <- rasterize(vect_data, eea_10km_raster, "presence", fun = mean)
plot(alces_alces_rast, main = "Alces alces Distribution - 1890 to 2020")

# we append the raster to the list
alce_alce_rasters[[1]] <- alces_alces_rast


### Rasterize for thosethat the data is Missing 
# Filter occurrences where either yearIni, yearEnd, or both are NA
missing_year_data <- alces_alces_sf %>%
  filter(is.na(yearIni) | is.na(yearEnd))

View(missing_year_data)

# Check if there is any missing data
if (nrow(missing_year_data) > 0) {
  
  # Convert to SpatVector for rasterization
  vect_missing_data <- vect(missing_year_data)
  
  # Rasterize the data based on the "presence" field for missing year data
  alces_alces_rast_year_na <- rasterize(vect_missing_data, eea_10km_raster, "presence", fun = mean)
  
  # Append to the raster 
  alce_alce_rasters[[2]] <-alces_alces_rast_year_na 

  } else {
  print("No records with missing year information.")
}

# Combine all the alces alces year na and no na rasters into a single multilayer SpatRaster
multilayer_raster <- rast(alce_alce_rasters)

# Create the output folder if it doesn't exist
if (!dir.exists(file.path(output_file, subDir))) {
  dir.create(file.path(output_file, subDir), FALSE)
}

# Define full path for saving
output <- file.path(output_file, subDir)

# Save the multilayer raster as a single file with different layers
writeRaster(multilayer_raster, paste0(output, "/Alces_alces_1890_2020_wna.tif"), overwrite = TRUE)




## Rasterize everthing testing
# Create an empty list to store the rasters for each year
yearly_rasters <- list()

# Loop through each unique starting year and rasterize the occurrences
for (start_year in year_ranges) {
  
  # Filter data for the current time step
  current_data <- alces_alces_sf %>% 
    filter(yearIni == start_year)
  
  # Create an empty list to store the rasters for each year
  yearly_rasters <- list()
  
  # Rasterize for each year in the range yearIni to yearEnd
  for (i in 1:nrow(current_data)) {
    
    # Get the year range for the current row
    start_yr <- current_data$yearIni[i]
    end_yr <- current_data$yearEnd[i]
    
    # Loop through each year in the range yearIni to yearEnd
    for (yr in start_yr:end_yr) {
      
      # Filter occurrences for the current year
      current_year_data <- current_data %>% 
        filter(yearIni <= yr & yearEnd >= yr)
      
      # Rasterize the current year's data using the "presence" column for status
      rasterized <- terra::rasterize(vect(current_year_data), eea_10km_raster,  field = "presence", fun = mean)
      
      # Plot the rasterized map for the current year
      #plot(rasterized, main = paste("Alces alces Distribution - Year", yr))
      yearly_rasters[[as.character(yr)]] <- rasterized
      # # Create the output folder
      # if (!dir.exists(file.path(output_file, subDir))){
      #   
      #   dir.create(file.path(output_file, subDir), FALSE)
      # }
      # 
      # # define full path
      # output <- file.path(output_file, subDir)
      # 
      # # Optionally save the raster for the current year
      # writeRaster(rasterized, paste0(output, "/Alces_alces_", yr, ".tif"), overwrite = TRUE)
      
    }
  }
}

# Combine all the yearly rasters into a single multilayer SpatRaster
multilayer_raster <- rast(yearly_rasters)

# Assign layer names corresponding to each year
names(multilayer_raster) <- names(yearly_rasters)

# Plot the multilayer raster
plot(multilayer_raster)

# Save the multilayer raster as a single file with different layers
writeRaster(multilayer_raster, file.path(output_file, "Alces_alces_multilayer.tif"), overwrite = TRUE)


# Save the envirionment
save.image(file = 'mammals_dwc_16102024.RData')











