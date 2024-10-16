#######################################
# Author: Emmanuel Oceguera
# Date: July 2024
#  
# Work: This script processes mammal species distribution data, 
# integrating it into an EEA grid structure for spatial analysis and reporting. The goal is to 
# classify species presence, absence, and extinction across a 5km grid, ensuring data is prepared 
# for downstream analyses. The process involves importing necessary libraries and data, cleaning 
# and standardizing the species distribution information, assigning values based on species status, 
# and exporting the final integrated dataset to a PostgreSQL database for storage and further use. 
# This script also provides functionality for filtering out grid cells where no species are present.
#######################################


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
library(RPostgres)
library(DBI)
library(terra)

# Define your database connection parameters
dbname <- "naturaconnect"
host <- "postgis02.srv.idiv.de"
port <- 5432
user <- "no67wuwu@usr.idiv.de"
password <- "GinkoBiloba5294!"

# Establish the connection
con <- dbConnect(RPostgres::Postgres(),
                 dbname = dbname,
                 host = host,
                 port = port,
                 user = user,
                 password = password,
                 options = "-c client_encoding=UTF8")

# Define the output folder for each of the countries
output_germany <- "I:\\biocon\\Emmanuel_Oceguera\\projects\\Mammals_species_distribution_DarwingCore\\output\\raw_species_by_country\\Germany\\test"


####################### Sachsen #######################

# Load the species distribution data
species_dis_sachsen <- st_read(con, query = "SELECT * FROM eu_mammals_darwin_core.species_distribution_atlas_sachsen")
#View(species_distribution)

# Load the EEA grid at 5km resolution
eea_grid_sachsen <- st_read(con, query = "SELECT * FROM grids.sachsen_eeu_ref_grid_10km")

# Create a list of species codes
species_codes <- unique(species_dis_sachsen$species_code)

# insert data into the GRID
# step:1 Initialize the species columns in the EEA grid with 0 (absence)
for (code in species_codes) {
  eea_grid_sachsen[[code]] <- 0
}

# Step 2: Set grid cells to 5 where species are extinct
for (code in species_codes) {
  extinct_data <- species_dis_sachsen %>%
    filter(species_code == code & status == "Extinct")
  
  if (nrow(extinct_data) > 0) {
    intersects <- st_intersects(eea_grid_sachsen, extinct_data, sparse = FALSE)
    eea_grid_sachsen[[code]] <- ifelse(rowSums(intersects) > 0, 5, eea_grid_sachsen[[code]])
  }
}

# Step 3: Set grid cells to 1 where species are present
for (code in species_codes) {
  present_data <- species_dis_sachsen %>%
    filter(species_code == code & status == "Present")
  
  if (nrow(present_data) > 0) {
    intersects <- st_intersects(eea_grid_sachsen, present_data, sparse = FALSE)
    eea_grid_sachsen[[code]] <- ifelse(rowSums(intersects) > 0, 1, eea_grid_sachsen[[code]])
  }
}

View(eea_grid_sachsen)

# Step 4: Final pass to ensure extinct (5) is not overridden by presence (1)
for (code in species_codes) {
  eea_grid_sachsen[[code]] <- ifelse(eea_grid_sachsen[[code]] == 5, 5, eea_grid_sachsen[[code]])
}

# Check the distirbution of some species
plot(eea_grid_sachsen["LYNLYN"])
plot(eea_grid_sachsen["CANLUP"])
plot(eea_grid_sachsen["OVIAMM"])


# Define the speies to process
species_list <- unique(species_dis_sachsen$species_code)
unique(species_dis_sachsen$source)

# Loop
for (species_code in species_list){
  
  # dynamically create column name (e.g. m_damdam, m_ovimus)
  new_column_name <-  paste0("m_", tolower(species_code))
  
  # select and rename columns
  eea_grid_sn_species <- eea_grid_sachsen %>% 
    select(cellcode, eoforigin, noforigin, all_of(species_code), geom) %>% 
    rename(!!new_column_name := all_of(species_code)) %>% 
    mutate(eventID = "HAUDESN0659") # Add the eventID
  
  # Define the output file path for each each of the specie
  output_file_path <-  paste0(output_germany, "/M_SN_", species_code, ".shp")
  
  # Write 
  writeVector(vect(eea_grid_sn_species), output_file_path, overwrite=TRUE)
  
  # Print statement
  cat("Shapefile creted for: ", species_code, "\n")
  
}


####################### Thuringe #######################

# Load the species distribution data for Thuringen
species_distribution_th <- st_read(con, query = "SELECT * FROM eu_mammals_darwin_core.species_distribution_atlas_thuringen")
# # Update the specie code -> was wrong
# species_distribution_th$species_code[species_distribution_th$species_code == "CERDAM"] <- "DAMDAM"

# Load the EEA grid at 10km resolution for Thuringen
eea_grid_th <- st_read(con, query = "SELECT * FROM grids.thuringen_eeu_ref_grid_10km")
plot(eea_grid_th)

# Create a list of species codes from the Thuringen species distribution data
species_code <- unique(species_distribution_th$species_code)

# Step 1: Initialize the species columns in the EEA grid with 0 (absence)
for (code in species_code) {
  eea_grid_th[[code]] <- 0 # set 0 to all the species columns
}

# Step 2: Set grid cells to 1 where species are present
for (code in species_code) {
  present_data_thuringen <- species_distribution_th %>%
    filter(species_code == code & status == "Present")
  
  if (nrow(present_data_thuringen) > 0) {
    intersects_thuringen <- st_intersects(eea_grid_th, present_data_thuringen, sparse = FALSE)
    eea_grid_th[[code]] <- ifelse(rowSums(intersects_thuringen) > 0, 1, eea_grid_th[[code]])
  }
}

#check it
plot(eea_grid_th["DAMDAM"])
plot(eea_grid_th["OVIMUS"])


### Export shp excluding id to  the correponding country folder

# # Use the dynamically created column name in select()
# eea_grid_th_damdam <- eea_grid_th %>%
#   select(cellcode, eoforigin, noforigin, DAMDAM, geom) %>% 
#   rename(m_damdam = DAMDAM) %>% 
#   mutate(eventID = "GÖRDETH0507") # in case the species was tacking from the same reosurce we set it here
# # write it
# writeVector(vect(eea_grid_th_damdam), paste0(output_germany, "/M_TH_DAMDAM.shp"))

# Define the speies to process
species_list <- c('OVIMUS', 'DAMDAM')

# Loop
for (species_code in species_list){
  
  # dynamically create column name (e.g. m_damdam, m_ovimus)
  new_column_name <-  paste0("m_", tolower(species_code))
  
  # select and rename columns
  eea_grid_th_species <- eea_grid_th %>% 
    select(cellcode, eoforigin, noforigin, all_of(species_code), geom) %>% 
    rename(!!new_column_name := all_of(species_code)) %>% 
    mutate(eventID = "GÖRDETH0507") # Add the eventID
  
  # Define the output file path for each each of the specie
  output_file_path <-  paste0(output_germany, "/M_TH_", species_code, ".shp")
  
  # Write 
  writeVector(vect(eea_grid_th_species), output_file_path)
  
  # Print statement
  cat("Shapefile creted for: ", species_code, "\n")
  
}










