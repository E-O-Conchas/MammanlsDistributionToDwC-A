# Extract the starting distribution by country and species and build the
# shapefile inventory. Based on 01_extract_spp_by_countries.R and
# 02_create_shp_database.R from the original workflow.

library(sf)

# Input and output paths. Run from the project root in RStudio.
baseline_file <- "sources/initial_compilation/input/distribution/sp_occu_20190829.shp"
boundary_file <- "reference/boundaries/eu_countries_boundary.shp"
output_dir <- "database/rebuild"
country_dir <- file.path(output_dir, "initial_by_country")
inventory_file <- file.path(output_dir, "shapefile_inventory.csv")

# Read the original distribution grid and the local country boundaries.
baseline <- st_read(baseline_file, quiet = TRUE)
countries <- st_read(boundary_file, quiet = TRUE)
names(baseline) <- tolower(names(baseline))
names(countries) <- tolower(names(countries))
species_columns <- grep("^m_", names(baseline), value = TRUE)
stopifnot(length(species_columns) > 0,
          all(c("cellcode", "eoforigin", "noforigin") %in% names(baseline)),
          all(c("country", "cntrycd") %in% names(countries)),
          !anyNA(baseline$cellcode), !anyDuplicated(baseline$cellcode),
          isTRUE(st_crs(baseline) == st_crs(3035)))
countries <- st_make_valid(st_transform(countries, st_crs(baseline)))

# The original script kept codes 1 and 9. Find which countries overlap the
# occupied cells. Border cells can belong to more than one country.
# We keep the full 10 km cells from the starting layer as the output grid.
attributes <- st_drop_geometry(baseline)
occupied <- Reduce(`|`, lapply(attributes[species_columns], function(x) x %in% c(1, 9)))
baseline <- baseline[occupied, ]
baseline <- st_make_valid(baseline)
hits <- st_intersects(countries, baseline)
touches <- st_touches(countries, baseline)

# Write one shapefile per country and species, with its original status code.
inventory <- list()
for (i in seq_len(nrow(countries))) {
  code <- countries$cntrycd[i]
  country <- countries$country[i]
  country_rows <- setdiff(hits[[i]], touches[[i]])
  for (column in species_columns) {
    rows <- country_rows[baseline[[column]][country_rows] %in% c(1, 9)]
    if (!length(rows)) next

    species <- sub("^m_", "", column)
    filename <- paste0(toupper(column), ".shp")
    folder <- file.path(country_dir, code)
    dir.create(folder, recursive = TRUE, showWarnings = FALSE)
    path <- file.path(folder, filename)
    layer <- baseline[rows, c("cellcode", "eoforigin", "noforigin", column)]
    st_write(layer, path, delete_layer = TRUE, quiet = TRUE)

    inventory[[length(inventory) + 1L]] <- data.frame(
      country_code = code, country = country, taxonID = species,
      shapefile_name = filename, path = path, grid_cells = nrow(layer)
    )
  }
  cat(country, "processed\n")
}

stopifnot(length(inventory) > 0)
inventory <- do.call(rbind, inventory)
write.csv(inventory, inventory_file, row.names = FALSE, fileEncoding = "UTF-8")
cat(nrow(inventory), "shapefiles in", length(unique(inventory$country_code)),
    "countries. Inventory:", inventory_file, "\n")
