# European Mammals Ungulates Distribution Workflow  <img align="right" width="20%" src="fig/logo.jpg"> 

## Introduction

This project aims to create a comprehensive dataset of the distribution of ungulate species across Europe. 
The dataset adheres to Darwin Core standards, ensuring compatibility and ease of integration with other biodiversity datasets globally.
The workflow involves extracting species occurrence data, creating a shapefile database, adding event IDs, processing the distribution data, and generating absence data for certain species.

## Workflow Steps

### 1. Extract Species by Countries

**Script:** `01_extract_spp_by_countries.R`

**Description:**
- This script extracts species occurrence data for different countries from a larger dataset.
- It processes the data to ensure it is specific to each country, filtering by species and geographic location.

**Key Steps:**
- Load the occurrence dataset.
- Filter the data by country and species.
- Save the filtered data for each country.

### 2. Create Shapefile Database

**Script:** `02_create_shp_database.R`

**Description:**
- This script compiles all the shapefiles from different countries into a single database.
- It lists all the species distribution layers and organizes them by country.

**Key Steps:**
- List all shapefiles in the specified directory.
- Organize the shapefiles by country.
- Create a database of shapefiles with metadata.

### 3. Generate Event IDs by Bibliography

**Description:**
- After extracting and copilated the data by country, this step verifies that the distribution of each species corresponds to the bibliographic sources by country.
- An event ID is created for each data source and country, allowing the identification of which distribution corresponds to which bibliography.
- This step involves manually corroborating the data to ensure it matches the bibliographic sources, as the dataset was previously compiled without proper Darwin Core formatting.

**Key Steps:**
- Cross-reference the distribution data with the bibliographic sources.
- Assign unique event IDs to each dataset entry based on the source and country.
- Ensure that each distribution record is correctly linked to its bibliographic source.

### 4. Add Event ID to Distribution Shapefiles

**Script:** `03_add_eventID_to_distribution_shp.R`

**Description:**
- This script adds the verified event IDs to each distribution shapefile.
- The event ID links the occurrence data with specific bibliographic sources, ensuring data consistency.

**Key Steps:**
- Load the shapefile database.
- Assign the corroborated event IDs to each shapefile.
- Save the updated shapefiles with event IDs.

### 5. Process Mammals Distribution Data

**Script:** `04_process_mammals_distribution_data.R`

**Description:**
- This script processes the compiled shapefile database.
- It aggregates, cleans, and reformats the data into a standardized format suitable for further analysis and publication.
- **Absence Data Generation:** This step also includes the creation of absence data. 
	Absence was inferred by identifying grid cells within the species' known geographic range that lacked confirmed presence records.

**Key Steps:**
- Load the shapefile database with event IDs.
- Aggregate the data by species and country.
- Clean and reformat the data.
- **Generate Absence Data:** Identify grid cells within the species' known geographic range that lack confirmed presence records and mark them as absences.
- Save the processed data in a standardized format.

## Data Quality and Standards

The dataset follows the Darwin Core standards for biodiversity data, ensuring that it is well-structured and interoperable with other datasets. 
Several quality control measures are implemented to minimize errors and inconsistencies, including validation of species identifications, georeferencing of location data, and removal of duplicate records.

## Usage Notes

This dataset is publicly available and can be accessed for research, conservation planning, and educational purposes. 
Users are encouraged to cite the dataset appropriately when using it in publications and to notify the data providers of any significant findings or errors discovered during use.

## Citation

When using this dataset, please cite as follows:
European Mammals Ungulates Distribution, [Year]. Compiled by Emmanuel Oceguera and collaborators. Available at: [URL]

## Contact

For more information, please contact Emmanuel Oceguera at e.oceguera@idiv.de
