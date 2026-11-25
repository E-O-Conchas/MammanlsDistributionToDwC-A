# Attach the historical event IDs and process the baseline distributions.
# Based on 03_add_eventID_to_distribution_shp.R and the long-format step of
# 05_process_mammals_distribution_data_clean.R in the original project.

library(sf)

output_dir <- "database/rebuild"
inventory_file <- file.path(output_dir, "shapefile_inventory.csv")
links_file <- "reference/source_file_links.csv"
registry_file <- "reference/source_registry.csv"
rebuild_db <- file.path(output_dir, "mammals_rebuild.gpkg")

inventory <- read.csv(inventory_file, fileEncoding = "UTF-8")
links <- read.csv(links_file, fileEncoding = "UTF-8")
registry <- read.csv(registry_file, fileEncoding = "UTF-8")
stopifnot(nrow(inventory) > 0, all(file.exists(inventory$path)))

# Historical country spellings used in the file-to-source mapping.
country_codes <- setNames(inventory$country_code, tolower(inventory$country))
aliases <- c(czech_republic = "CZ", denemark = "DK", espana = "ES",
             grecee = "GR", irland = "IE", luxenbourg = "LU",
             macedonia = "MK", suiza = "CH", united_kingdom = "GB",
             norway = "NO")
country_codes[names(aliases)] <- aliases
links$country_code <- unname(country_codes[tolower(trimws(links$Country))])
links$BaseName <- trimws(links$BaseName)
links$taxonID <- tolower(sub("^.*_([[:alnum:]]+)[.]shp$", "\\1",
                             links$BaseName, ignore.case = TRUE))
registry$country[registry$country %in% "BU"] <- "BG"

# Match country AND filename, as intended in the original script.
# Other files for the same species are review candidates. Their spatial
# coverage can differ from the generated national layer.
inventory$eventID <- NA_character_
inventory$historic_country <- inventory$country
inventory$review <- NA_character_
inventory$candidate_files <- ""
inventory$candidate_eventIDs <- ""
for (i in seq_len(nrow(inventory))) {
  code <- inventory$country_code[i]
  candidates <- links[links$country_code %in% code &
                        links$taxonID %in% inventory$taxonID[i], ]
  exact <- candidates[toupper(candidates$BaseName) %in%
                        toupper(inventory$shapefile_name[i]), ]
  inventory$candidate_files[i] <- paste(unique(candidates$BaseName), collapse = " | ")
  inventory$candidate_eventIDs[i] <- paste(unique(candidates$eventID), collapse = " | ")
  ids <- unique(exact$eventID[!is.na(exact$eventID) & nzchar(exact$eventID)])
  registered <- registry[registry$eventID %in% ids, ]

  if (!nrow(exact)) {
    inventory$review[i] <- if (nrow(candidates)) "different_historical_filename" else "no_source_link"
  } else if (length(ids) != 1L || nrow(registered) > 1L) {
    inventory$review[i] <- "ambiguous_event_id"
  } else if (!nrow(registered) || !isTRUE(registered$country == code)) {
    inventory$review[i] <- "event_id_or_country_needs_review"
  } else {
    inventory$eventID[i] <- ids
    inventory$historic_country[i] <- trimws(exact$Country[match(ids, exact$eventID)])
    inventory$review[i] <- "linked_by_country_and_filename"
  }
}

# Make one record per country, species and grid cell, retaining eventID,
# including missing IDs that still need review. The starting grid has no year.
distributions <- lapply(seq_len(nrow(inventory)), function(i) {
  entry <- inventory[i, ]
  layer <- st_read(entry$path, quiet = TRUE)
  status <- layer[[paste0("m_", entry$taxonID)]]
  stopifnot(nrow(layer) == entry$grid_cells, length(status) == nrow(layer))
  st_sf(
    cellcode = layer$cellcode, taxonID = rep(entry$taxonID, nrow(layer)),
    year = rep(NA_integer_, nrow(layer)), eventID = rep(entry$eventID, nrow(layer)),
    country = rep(entry$historic_country, nrow(layer)), presence = as.integer(status),
    geometry = st_geometry(layer)
  )
})
distributions <- do.call(rbind, distributions)
st_write(distributions, rebuild_db, layer = "baseline_distributions",
         delete_layer = TRUE, quiet = TRUE)

write.csv(inventory, file.path(output_dir, "shapefile_event_links.csv"),
          row.names = FALSE, fileEncoding = "UTF-8", na = "")
print(table(inventory$review))
cat(nrow(distributions), "baseline records saved. Shapefile event links:",
    file.path(output_dir, "shapefile_event_links.csv"), "\n")
