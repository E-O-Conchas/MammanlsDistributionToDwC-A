
# Workflow for Updating and Incorporating Databases into the European Mammals Project

This workflow outlines the process of updating and integrating new mammal species data into the European Mammals Database. The steps below ensure consistency, accuracy, and proper alignment with existing records.
### Steps

#Georeferencing

If there are any associated images (e.g., scans, maps), georeference these using ArcGIS to ensure accurate spatial alignment.

### Step 1: Digitization of Occurrence Points

Digitize occurrence points to create a shapefile that includes all relevant records. The shapefile should contain the following columns:
- `id`: Unique identifier for each record.
- `species`: Scientific name of the species.
- `status`: Status of the species (e.g., presence, extinct, sporadic).
- `year_start`: The starting year of the record.
- `year_end`: The ending year of the record.
- `source`: Reference source for the record (initially left empty).

It is important to include the `source` column because the source will be used to create `eventID`, which will be assigned to each occurrence.

### Step 2: Uploading and Aggregating Species Data in PostgreSQL

Push the species point shapefile to PostgreSQL using the provided connection parameters. This centralizes all occurrence points for each species into the main database, making them accessible for further processing.

Use the `manage_species_data.SQL` script to aggregate the uploaded point data:
- This script consolidates the occurrence data for each species, merging them into a unified dataset within the database.
- The aggregation ensures that species records are efficiently managed, whether at the country, state, or regional level, allowing for streamlined analysis and further updates.

### Step 4: Updating the Event Database

Use the SQL script `update_dwc_events.SQL` to update the `eventID` and ensure that new sources are included in the event database:
- **Updating EventIDs**: If you need to update an existing `eventID`, run the function `update_eventid_in_related_tables()` found in `eventID_trigger_function.SQL` before executing `update_dwc_events.SQL`. This ensures that all related tables are automatically updated with the new `eventID`.
- **Adding a New Source**: If you are adding a new event (source):
  - First, update the Excel table stored here: `data/csv/datasources_ungulates_full_biblio.xlsx`. This will generate the new `eventID`.
  - Then, update the event database in PostgreSQL using `update_dwc_events.SQL`.
  - Note: The new `eventID` will not automatically update related tables until it is added to the main occurrence databases: `mammals_ungulates_dwc_occ` (non-spatial) and `mammals_ungulates_dwc_occ_sf` (spatial).

### Step 5: Integrating Occurrence Data into the EEA Grid 

Run the script `04_add_data_in_grid.R` to integrate species occurrence data into the EEA grid:
- This script retrieves aggregated species occurrence data from the PostgreSQL database and maps it onto the specified EEA grid (e.g., 10km resolution).
- The mapping process involves setting the initial species presence values to `0` (absence) across the grid cells.
- Species statuses are then applied:
  - **Presence (`1`)** is assigned to grid cells where species occurrences are detected.
  - **Extinct (`5`)** status is assigned to grid cells where species are known to have disappeared.
  - **Sporadic (`9`)** status is assigned to grid cells where species are known to be sporadic.
- A final check ensures that extinct status (`5`) is not overwritten by presence values.

**Export the Results**:
- The script saves each species' data as a separate shapefile, named according to the species and country and/or state. For example, a species like *Ovis musimon* in Thuringia would be saved as `M_TH_OVIMUS.shp`.
- This step helps to maintain organized data storage, with each species’ spatial data stored in its respective country folder.

**EventIDs**:
- Make sure that any new `eventID`s are updated in both the Excel table and the PostgreSQL event table before running this integration step to ensure consistency.

### Step 6: Verification of Data

After saving the species data to the respective country folder, verify the following:
- **EventID Association**: Confirm that each species record has an `eventID` that matches the corresponding source in the event table.
- **Geographic Accuracy**: Verify that the species data aligns correctly with the corresponding country’s EEA grid, ensuring spatial accuracy.

### Step 7: Updating the Main Databases

Run the `05_process_mammals_distribution_data_clean.R` script to refresh the primary datasets:
- This script scans the folders for each country or region, identifying new or updated species shapefiles.
- It imports the latest data from these shapefiles, ensuring all changes are captured.
- The data is cleaned, standardized, and transformed into the Darwin Core format to ensure consistency across the entire dataset.

**Data Aggregation and Merging**:
- The script consolidates species data from all countries into a unified dataset.
- It merges spatial and non-spatial data, ensuring that both versions (`mammals_ungulates_dwc_occ` and `mammals_ungulates_dwc_occ_sf`) are synchronized.
- This process guarantees that all updated records are included, whether they come from newly digitized data or modifications to existing records.

**Export and Database Update**:
- The script exports the merged data back into the PostgreSQL database, replacing the previous versions of the tables.

**Usage**:
- To incorporate new or updated species records, simply place the updated shapefiles into the appropriate country or region folder.
- Run the script, and it will automatically detect, process, and integrate these updates into the main database.

### Step 8: Updating Species Names

If there are changes to species names, use the SQL script `Update_species_name.SQL`:
- This script updates the species names in the main databases.
- (Note: Consider creating a function to trigger updates in related tables.)

### Step 9: Rasterization of Species Data

In the final step, run the `06_rasterize_data.R` script to create raster maps of each species' distribution at a European scale. This script accesses species occurrence data from the PostgreSQL database and integrates it with a standardized EEA grid.

- The script processes both complete time ranges (e.g., *Alces alces* from 1890 to 2020) and occurrences with missing time information (for now).
- It generates raster layers representing species' presence, absence, or other statuses, using values like `1` for presence and `5` for extinct.
- All raster layers, including those with missing year data, are combined into a multilayer file for ease of analysis.
- The final raster file is saved to the designated output folder, providing a ready-to-use spatial representation of species distributions across Europe.

This streamlined approach allows for easy application to different species or regions, ensuring consistent data preparation for further spatial analysis.
