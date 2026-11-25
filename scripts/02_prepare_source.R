# Load this file once in RStudio, then call prepare_source("dataset_key").
# Source rules live in scripts/sources; spatial algorithms live in processors.
library(sf)

record_fields <- c("cellcode", "taxonID", "year", "eventID", "country", "presence")

load_source_config <- function(source_key) {
  stopifnot(length(source_key) == 1L, grepl("^[a-z0-9_]+$", source_key))
  profile <- file.path("scripts/sources", paste0(source_key, ".R"))
  if (!file.exists(profile)) stop("No source rules found: ", profile)
  settings <- new.env(parent = environment(prepare_source))
  sys.source(profile, envir = settings)
  settings$source_config
}

# Bind spatial tables with different optional metadata, retaining column types.
bind_records <- function(tables) {
  columns <- unique(unlist(lapply(tables, function(x) names(st_drop_geometry(x)))))
  for (column in columns) {
    example <- tables[[which(vapply(tables, function(x) column %in% names(x), logical(1)))[1]]][[column]]
    tables <- lapply(tables, function(x) {
      if (!column %in% names(x)) x[[column]] <- example[rep(NA_integer_, nrow(x))]
      x
    })
  }
  tables <- lapply(tables, function(x) {
    st_sf(st_drop_geometry(x)[columns], geometry = st_geometry(x))
  })
  do.call(rbind, tables)
}

# Compare dated records by year; use the verbatim period for undated intervals.
record_key <- function(x) {
  period <- if ("verbatimEventDate" %in% names(x)) x$verbatimEventDate else rep("", nrow(x))
  period[is.na(period) | !is.na(x$year)] <- ""
  paste(x$eventID, x$country, x$cellcode, x$taxonID, x$year, x$presence, period, sep = "|")
}

read_registry <- function(path) {
  read.csv(path, fileEncoding = "UTF-8", colClasses = "character", check.names = FALSE)
}

# Reuse the historical prepared Estonia/Poland layers when requested. Their
# generated zero rows are omitted; they do not establish observed absence.
read_existing_grids <- function(source_key, config) {
  files <- list.files(file.path("sources", source_key, "prepared", "species_grids_by_year"),
                      "[.]shp$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (!length(files)) stop("No existing species/year grids found for ", source_key)
  layers <- lapply(files, function(file) {
    data <- st_read(file, quiet = TRUE)
    columns <- names(data) != attr(data, "sf_column")
    names(data)[columns] <- tolower(names(data)[columns])
    taxon <- tolower(sub("^M_(.*)[.]shp$", "\\1", basename(file), ignore.case = TRUE))
    field <- paste0("m_", taxon)
    stopifnot(all(c("cellcode", "year", "eventid", field) %in% names(data)),
              all(data$eventid %in% config$event_id))
    data$source_row <- seq_len(nrow(data))
    data <- data[data[[field]] %in% c(1, 5, 9), ]
    st_sf(cellcode = data$cellcode, taxonID = rep(taxon, nrow(data)),
          year = as.integer(as.character(data$year)), eventID = data$eventid,
          country = rep(config$country, nrow(data)), presence = as.integer(data[[field]]),
          sourceFile = rep(file, nrow(data)), sourceRow = data$source_row,
          geometry = st_geometry(st_transform(data, 3035)))
  })
  do.call(rbind, layers)
}

# A source supplies its bibliography once, or reuses its registered reference.
source_references <- function(records, supplied = NULL) {
  registry <- read_registry("reference/source_registry.csv")
  if (!is.null(supplied)) {
    stopifnot(!anyDuplicated(supplied$eventID), all(names(supplied) %in% names(registry)))
  }
  rows <- lapply(unique(records$eventID), function(id) {
    old <- registry[registry$eventID %in% id, , drop = FALSE]
    if (nrow(old) > 1L) stop("Duplicate source eventID in registry: ", id)
    if (nrow(old)) row <- old else row <- registry[NA_integer_, , drop = FALSE]
    if (!is.null(supplied)) {
      entry <- supplied[supplied$eventID %in% id, , drop = FALSE]
      if (nrow(entry)) {
        if (nrow(old)) check_source_doi(old[["DOI, ISBN, ISSN"]], entry[["DOI, ISBN, ISSN"]])
        row[1L, names(entry)] <- entry[1L, ]
      }
    }
    if (is.na(row$eventID) || is.na(row$bibliographicCitation) || !nzchar(row$bibliographicCitation)) {
      stop("Provide the source reference and bibliographicCitation for ", id)
    }
    data <- records[records$eventID %in% id, ]
    row$cellCount <- as.character(nrow(data))
    row$specieCode <- paste(sort(unique(toupper(data$taxonID))), collapse = ", ")
    first <- if ("yearStart" %in% names(data)) data$yearStart else data$year
    last <- if ("yearEnd" %in% names(data)) data$yearEnd else data$year
    first[is.na(first)] <- data$year[is.na(first)]
    last[is.na(last)] <- data$year[is.na(last)]
    if (any(!is.na(first)) && any(!is.na(last))) {
      row$yearIni <- as.character(min(first, na.rm = TRUE))
      row$yearEnd <- as.character(max(last, na.rm = TRUE))
      row$eventData <- paste(row$yearIni, row$yearEnd, sep = "/")
    }
    row
  })
  do.call(rbind, rows)
}

check_source_doi <- function(old, new) {
  clean <- function(x) tolower(sub("^https?://(dx[.])?doi[.]org/", "", trimws(x), ignore.case = TRUE))
  if (length(old) && length(new) && !is.na(old) && !is.na(new) &&
      nzchar(old) && nzchar(new) && clean(old) != clean(new)) {
    stop("An eventID is registered with a different DOI. Review the source reference.")
  }
}

validate_records <- function(records) {
  stopifnot(nrow(records) > 0L, all(record_fields %in% names(records)),
            !anyNA(st_drop_geometry(records)[setdiff(record_fields, "year")]),
            all(nzchar(records$cellcode)), all(nzchar(records$eventID)),
            all(nzchar(records$taxonID)), all(nzchar(records$country)),
            all(records$presence %in% c(0L, 1L, 5L, 9L)),
            isTRUE(st_crs(records) == st_crs(3035)))
}

prepare_source <- function(source_key, use_existing = FALSE) {
  config <- load_source_config(source_key)
  type <- if (use_existing) "grids" else config$input_type
  if (!type %in% c("points", "polygons", "grids")) stop("Unknown input type: ", type)
  if (use_existing) {
    input <- list(data = read_existing_grids(source_key, config),
                  report = data.frame(metric = "input_mode", value = "reused_prepared_grids"))
    keep_fields <- record_fields
  } else {
    input <- config$read_input()
    keep_fields <- config$record_fields
  }
  data <- input$data
  if (!nrow(data)) stop("No usable input records for ", source_key)
  stopifnot(!is.na(st_crs(data)), all(c("sourceRow", "sourceFile") %in% names(data)))
  grid <- NULL
  if (type != "grids") {
    grid <- st_read(config$reference_grid, quiet = TRUE)
    columns <- names(grid) != attr(grid, "sf_column")
    names(grid)[columns] <- tolower(names(grid)[columns])
    stopifnot("cellcode" %in% names(grid), !anyNA(grid$cellcode),
              !anyDuplicated(grid$cellcode), isTRUE(st_crs(grid) == st_crs(3035)))
  }
  processor <- new.env(parent = environment(prepare_source))
  sys.source(file.path("scripts/processors", paste0(type, ".R")), envir = processor)
  matched <- processor[[paste0("process_", type)]](data, grid)
  if (!length(matched$source_rows)) stop("No input features matched the reference grid.")
  attributes <- st_drop_geometry(data)[matched$source_rows, , drop = FALSE]
  attributes$cellcode <- matched$grid$cellcode[matched$grid_rows]
  records <- st_sf(attributes[keep_fields],
                    geometry = st_geometry(matched$grid)[matched$grid_rows])
  records <- records[!duplicated(st_drop_geometry(records)), ]
  if (anyDuplicated(record_key(records))) {
    stop("Conflicting metadata for the same source/cell/taxon/period. Review the source rules.")
  }
  records$sourceDataset <- source_key
  records$inputType <- type
  records$inputMode <- if (use_existing) "reused_prepared_grids" else "raw"
  records$recordKey <- record_key(records)
  validate_records(records)
  attributes$recordKey <- record_key(attributes)
  sources <- source_references(records, if (use_existing) NULL else config$references)
  source_files <- unique(data.frame(
    Country = config$country, eventID = attributes$eventID,
    BaseName = basename(attributes$sourceFile)
  ))
  unmatched <- st_drop_geometry(data)[setdiff(seq_len(nrow(data)), matched$source_rows), , drop = FALSE]
  report <- rbind(input$report, data.frame(
    metric = c("usable_input_features", "matched_input_features", "unmatched_input_features", "prepared_records"),
    value = as.character(c(nrow(data), length(unique(matched$source_rows)), nrow(unmatched), nrow(records)))
  ))
  output_dir <- file.path("sources", source_key, "prepared")
  output_file <- file.path(output_dir, "records.gpkg")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  st_write(records, output_file, layer = "records", delete_layer = TRUE, quiet = TRUE)
  st_write(sources, output_file, layer = "sources", delete_layer = TRUE, quiet = TRUE)
  st_write(source_files, output_file, layer = "source_files", delete_layer = TRUE, quiet = TRUE)
  # Preserve both original uppercase and normalized fields in SQLite, which
  # treats names such as YEAR and year as identical.
  original_names <- duplicated(tolower(names(attributes)), fromLast = TRUE)
  names(attributes)[original_names] <- paste0("original_", names(attributes)[original_names])
  st_write(attributes, output_file, layer = "record_links", delete_layer = TRUE, quiet = TRUE)
  write.csv(report, file.path(output_dir, "processing_report.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
  write.csv(unmatched, file.path(output_dir, "unmatched_input.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
  excluded <- input$excluded
  if (is.null(excluded)) excluded <- data.frame(sourceRow = integer(), reason = character())
  write.csv(excluded, file.path(output_dir, "excluded_input.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
  cat(source_key, ":", nrow(records), "records prepared from", type, "in", output_file, "\n")
  cat(nrow(unmatched), "unmatched input features; see processing_report.csv\n")
  cat("Next: source(\"scripts/03_add_sources_and_compare.R\")\n")
  invisible(output_file)
}
