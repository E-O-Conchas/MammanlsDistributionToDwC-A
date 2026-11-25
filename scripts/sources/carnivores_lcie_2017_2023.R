# Source-specific LCIE fields. Brown bear is the reviewed layer currently enabled.
# Other LCIE layers require their own field review, then reuse the grids processor.
source_config <- list(
  input_type = "grids", country = "Europe", event_id = "LCIE2024_URSARC",
  record_fields = c(record_fields, "scientificName", "verbatimScientificName",
                     "verbatimEventDate", "yearStart", "yearEnd", "presenceCategory",
                     "dataQuality", "categoryNeedsReview", "sourceReference", "population",
                     "compiledBy", "datasetCompilers", "yearCompiled", "sourceDOI"),
  references = data.frame(
    eventID = "LCIE2024_URSARC", specieCode = "URSARC", country = "Europe", Region = "",
    dataType = "DISTRIBUTION_MAP",
    DATA_SOURCES = "Large carnivore distribution maps for Europe 2017 - 2022/23",
    pathway = "https://doi.org/10.5061/dryad.3xsj3txrc",
    bibliographicCitation = paste(
      "Kaczensky, P., Ranc, N., Hatlauf, J., Payne, J. C., et al. (2024).",
      "Large carnivore distribution maps for Europe 2017 - 2022/23 [Dataset].",
      "Dryad. https://doi.org/10.5061/dryad.3xsj3txrc"
    ), check.names = FALSE
  ),
  read_input = function() {
    file <- list.files("sources/carnivores_lcie_2017_2023/input",
                        "^Bear_2017-2022_LCIE[.]shp$", recursive = TRUE, full.names = TRUE)
    stopifnot(length(file) == 1L)
    data <- st_read(file, options = "ENCODING=UTF-8", quiet = TRUE)
    attributes <- names(data) != attr(data, "sf_column")
    names(data)[attributes] <- toupper(names(data)[attributes])
    required <- c("CELLCODE", "SPECIES", "COUNTRY", "YEAR", "PRESENCE", "DATAQUAL",
                  "DATASOURCE", "POPULATION", "PERSON", "COMPILERS", "YRCOMPILED")
    stopifnot(all(required %in% names(data)), !anyDuplicated(data$CELLCODE))
    data$verbatimScientificName <- data$SPECIES
    data$scientificName <- trimws(data$SPECIES)
    data$scientificName[data$scientificName %in% "Ursus arctors"] <- "Ursus arctos"
    stopifnot(all(data$scientificName %in% "Ursus arctos"),
              all(data$PRESENCE %in% c("Permanent", "Sporadic", "Undefined")),
              all(!is.na(data$YEAR) & nzchar(trimws(data$YEAR))))
    period <- trimws(data$YEAR)
    tokens <- regmatches(period, gregexpr("[12][0-9]{3}", period))
    stopifnot(all(lengths(tokens) > 0L))
    first <- vapply(tokens, function(x) min(as.integer(x)), integer(1))
    last <- vapply(tokens, function(x) max(as.integer(x)), integer(1))
    short_end <- grepl("/[0-9]{2}$", period)
    last[short_end] <- (last[short_end] %/% 100L) * 100L +
      as.integer(sub("^.*/([0-9]{2})$", "\\1", period[short_end]))
    stopifnot(all(first <= last))
    data$cellcode <- data$CELLCODE
    data$taxonID <- "ursarc"
    data$year <- ifelse(first == last, first, NA_integer_)
    data$eventID <- "LCIE2024_URSARC"
    data$country <- data$COUNTRY
    # LCIE describes supplied cells as occupied; category and evidence quality
    # stay separate. An Undefined category is not an absence observation.
    data$presence <- 1L
    data$verbatimEventDate <- data$YEAR
    data$yearStart <- first
    data$yearEnd <- last
    data$presenceCategory <- data$PRESENCE
    data$dataQuality <- data$DATAQUAL
    data$categoryNeedsReview <- data$PRESENCE %in% "Undefined"
    data$sourceReference <- data$DATASOURCE
    data$population <- data$POPULATION
    data$compiledBy <- data$PERSON
    data$datasetCompilers <- data$COMPILERS
    data$yearCompiled <- data$YRCOMPILED
    data$sourceDOI <- "10.5061/dryad.3xsj3txrc"
    data$sourceFile <- file
    data$sourceRow <- seq_len(nrow(data))
    report <- data.frame(metric = c("input_features", "corrected_species_names", "undefined_categories"),
                          value = as.character(c(nrow(data), sum(data$scientificName != data$verbatimScientificName),
                                                 sum(data$categoryNeedsReview))))
    list(data = data, report = report)
  }
)
source_config$references[["DOI, ISBN, ISSN"]] <- "10.5061/dryad.3xsj3txrc"
