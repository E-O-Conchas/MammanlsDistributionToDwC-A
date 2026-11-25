# France-specific fields and species codes; the polygon algorithm is shared.
source_config <- list(
  input_type = "polygons", country = "France", event_id = "RESFR30700",
  reference_grid = "reference/grids/FR/national_grid/fr_10km.shp",
  record_fields = c(record_fields, "scientificName"),
  read_input = function() {
    file <- "sources/france_ofb/input/eco_met_reseau_os_repartition_ongules_pol_2154.shp"
    data <- st_read(file, quiet = TRUE)
    stopifnot(all(c("espece", "code") %in% names(data)))
    taxa <- c(CEE = "cerela", CHA = "ruprup", ISA = "ruppyr", DAI = "damdam",
              MOM = "ovimus", MOC = "ovimus", BOQ = "capibe", BOI = "cappyr",
              CSI = "cernip", MAM = "ammler", MUN = "munree")
    names_by_taxon <- c(cerela = "Cervus elaphus", ruprup = "Rupicapra rupicapra",
                        ruppyr = "Rupicapra pyrenaica", damdam = "Dama dama",
                        ovimus = "Ovis musimon", capibe = "Capra ibex",
                        cappyr = "Capra pyrenaica", cernip = "Cervus nippon",
                        ammler = "Ammotragus lervia", munree = "Muntiacus reevesi")
    year_text <- sub("^.*([0-9]{4})$", "\\1", as.character(data$code))
    data$taxonID <- unname(taxa[as.character(data$espece)])
    stopifnot(!anyNA(data$taxonID), all(grepl("^[0-9]{4}$", year_text)))
    data$year <- as.integer(year_text)
    data$eventID <- "RESFR30700"
    data$country <- "France"
    data$presence <- 1L
    data$scientificName <- unname(names_by_taxon[data$taxonID])
    data$sourceRow <- seq_len(nrow(data))
    data$sourceFile <- file
    list(data = data, report = data.frame(metric = "input_features", value = as.character(nrow(data))))
  }
)
