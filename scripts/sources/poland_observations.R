# Read the original GBIF tab-separated download, despite its .csv extension.
# Keep the same eight target species as the historical Poland script.
source_config <- list(
  input_type = "points", country = "Poland", event_id = "OKAPL10336",
  reference_grid = "reference/grids/PL/national_grid/pl_10km.shp",
  reuse_existing = TRUE,
  record_fields = c(record_fields, "scientificName"),
  read_input = function() {
    file <- "sources/poland_observations/input/0021372-250426092105405.csv"
    raw <- read.delim(file, quote = "", comment.char = "", fileEncoding = "UTF-8",
                      colClasses = "character", check.names = FALSE, na.strings = c("", "NA"))
    required <- c("species", "year", "countryCode", "occurrenceStatus",
                  "decimalLongitude", "decimalLatitude", "gbifID", "datasetKey")
    stopifnot(all(required %in% names(raw)))
    taxa <- c("Alces alces" = "alcalc", "Cervus elaphus" = "cerela",
              "Rupicapra rupicapra" = "ruprup", "Capreolus capreolus" = "capcap",
              "Dama dama" = "damdam", "Sus scrofa" = "susscr",
              "Cervus nippon" = "cernip", "Ovis ammon" = "oviamm")
    reason <- rep("", nrow(raw))
    reason[!raw$species %in% names(taxa)] <- "outside_target_species"
    reason[raw$species %in% names(taxa) & !raw$countryCode %in% "PL"] <- "outside_source_country"
    selected <- which(reason == "")
    if (any(!raw$datasetKey[selected] %in% "a5e3cd7e-6532-4fe6-aea9-044e92093830")) {
      stop("The selected Poland records include a different datasetKey. Review their source attribution.")
    }
    x <- suppressWarnings(as.numeric(raw$decimalLongitude))
    y <- suppressWarnings(as.numeric(raw$decimalLatitude))
    bad_coords <- !is.finite(x) | !is.finite(y) | x < -180 | x > 180 | y < -90 | y > 90
    reason[selected[bad_coords[selected]]] <- "missing_or_invalid_coordinates"
    selected <- which(reason == "")
    status <- c(PRESENT = 1L, ABSENT = 0L)
    if (any(!raw$occurrenceStatus[selected] %in% names(status))) {
      stop("Review unmapped occurrenceStatus values in the Poland source.")
    }
    year <- suppressWarnings(as.integer(raw$year))
    invalid_year <- !is.na(raw$year[selected]) &
      (!grepl("^[12][0-9]{3}$", raw$year[selected]) | is.na(year[selected]))
    if (any(invalid_year)) stop("Review unreadable years in the Poland source.")
    data <- raw[selected, , drop = FALSE]
    data$sourceScientificName <- data$scientificName
    data$scientificName <- data$species
    data$taxonID <- unname(taxa[data$species])
    data$year <- year[selected]
    data$country <- "Poland"
    data$eventID <- "OKAPL10336"
    data$presence <- unname(status[data$occurrenceStatus])
    data$sourceRow <- selected
    data$sourceFile <- file
    data$decimalLongitude <- x[selected]
    data$decimalLatitude <- y[selected]
    data <- st_as_sf(data, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326,
                     remove = FALSE)
    excluded <- data.frame(sourceRow = which(reason != ""),
                            gbifID = raw$gbifID[reason != ""], reason = reason[reason != ""])
    report <- data.frame(metric = c("input_rows", "excluded_rows"),
                          value = as.character(c(nrow(raw), nrow(excluded))))
    list(data = data, excluded = excluded, report = report)
  }
)
