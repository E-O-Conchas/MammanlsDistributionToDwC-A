# Consolidate prepared sources and the linked baseline in the local rebuild.
# All three input types arrive here in the same format. No PostgreSQL writes.
source("scripts/02_prepare_source.R")

rebuild_dir <- "database/rebuild"
rebuild_db <- file.path(rebuild_dir, "mammals_rebuild.gpkg")
registry_file <- "reference/source_registry.csv"
links_file <- "reference/source_file_links.csv"
stopifnot(file.exists(rebuild_db),
          "baseline_distributions" %in% st_layers(rebuild_db)$name)
prepared_files <- list.files("sources", "^records[.]gpkg$", recursive = TRUE, full.names = TRUE)
prepared_files <- prepared_files[basename(dirname(prepared_files)) == "prepared"]
if (!length(prepared_files)) {
  stop("No standard prepared sources. Load scripts/02_prepare_source.R and call prepare_source(\"dataset_key\").")
}

registry <- read_registry(registry_file)
links <- read_registry(links_file)
stopifnot(!anyDuplicated(registry$eventID))
packages <- lapply(prepared_files, function(file) {
  stopifnot(all(c("records", "sources", "source_files", "record_links") %in% st_layers(file)$name))
  records <- st_read(file, layer = "records", quiet = TRUE)
  validate_records(records)
  refs <- st_read(file, layer = "sources", optional = TRUE, quiet = TRUE)
  file_links <- st_read(file, layer = "source_files", optional = TRUE, quiet = TRUE)
  stopifnot(all(records$eventID %in% refs$eventID),
            all(file_links$eventID %in% refs$eventID),
            all(!is.na(refs$bibliographicCitation) & nzchar(refs$bibliographicCitation)),
            !anyDuplicated(record_key(records)))
  list(records = records, sources = refs, source_files = file_links)
})

# Keep the existing Estonia/Poland grids until their standard preparation has
# been run. A standard package replaces this fallback for the whole dataset.
included_keys <- unique(unlist(lapply(packages, function(x) x$records$sourceDataset)))
profiles <- list.files("scripts/sources", "[.]R$", full.names = FALSE)
profile_keys <- sub("[.]R$", "", profiles)
for (key in setdiff(profile_keys, included_keys)) {
  config <- load_source_config(key)
  if (!isTRUE(config$reuse_existing)) next
  legacy_files <- list.files(file.path("sources", key, "prepared", "species_grids_by_year"),
                             "[.]shp$", recursive = TRUE, ignore.case = TRUE)
  if (!length(legacy_files)) next
  data <- read_existing_grids(key, config)
  files <- unique(data.frame(Country = config$country, eventID = data$eventID,
                             BaseName = basename(data$sourceFile)))
  records <- st_sf(st_drop_geometry(data)[record_fields], geometry = st_geometry(data))
  records <- records[!duplicated(st_drop_geometry(records)), ]
  records$sourceDataset <- key
  records$inputType <- "grids"
  records$inputMode <- "reused_prepared_grids"
  validate_records(records)
  packages[[length(packages) + 1L]] <- list(records = records,
    sources = source_references(records), source_files = files)
}

baseline <- st_read(rebuild_db, layer = "baseline_distributions", quiet = TRUE)
unlinked_baseline <- sum(is.na(baseline$eventID) | !nzchar(baseline$eventID))
baseline <- baseline[!is.na(baseline$eventID) & nzchar(baseline$eventID), ]
if (!nrow(baseline)) stop("No linked baseline records. Review shapefile_event_links.csv.")
baseline <- st_transform(baseline, 3035)
baseline <- st_sf(st_drop_geometry(baseline)[record_fields], geometry = st_geometry(baseline))
baseline$sourceDataset <- "initial_compilation"
baseline$inputType <- "grids"
baseline$inputMode <- "linked_baseline"
records <- bind_records(c(list(baseline), lapply(packages, `[[`, "records")))
records <- records[!duplicated(st_drop_geometry(records)), ]
validate_records(records)
if (anyDuplicated(record_key(records))) {
  stop("The baseline and prepared sources contain overlapping records under the same eventID. Review their scope.")
}
records$recordKey <- record_key(records)

# Register bibliography and file links using stable keys. Preserve existing IDs.
merge_references <- function(existing, incoming, keys, id_columns) {
  stopifnot(all(names(incoming) %in% names(existing)))
  for (i in seq_len(nrow(incoming))) {
    matched <- Reduce(`&`, lapply(keys, function(key) existing[[key]] %in% incoming[[key]][i]))
    index <- which(matched)
    if (length(index) > 1L) stop("Duplicate reference key; review ", paste(keys, collapse = ", "))
    if (!length(index)) {
      entry <- existing[NA_integer_, , drop = FALSE]
      for (column in id_columns) {
        entry[[column]] <- as.character(max(as.integer(existing[[column]]), 0L, na.rm = TRUE) + 1L)
      }
      existing <- rbind(existing, entry)
      index <- nrow(existing)
    } else if ("DOI, ISBN, ISSN" %in% names(incoming)) {
      check_source_doi(existing[["DOI, ISBN, ISSN"]][index], incoming[["DOI, ISBN, ISSN"]][i])
    }
    columns <- setdiff(names(incoming), id_columns)
    existing[index, columns] <- incoming[i, columns, drop = FALSE]
  }
  existing
}
incoming_sources <- do.call(rbind, lapply(packages, `[[`, "sources"))
if (anyDuplicated(incoming_sources$eventID)) {
  stop("Two prepared datasets use the same eventID. Review their source scope before combining.")
}
registry <- merge_references(registry, incoming_sources, "eventID", "id")
incoming_files <- unique(do.call(rbind, lapply(packages, `[[`, "source_files")))
links <- merge_references(links, incoming_files, c("Country", "eventID", "BaseName"), c("id", "ID"))
stopifnot(all(records$eventID %in% registry$eventID))

# Compare like-for-like records. Historical generated zeros are excluded unless
# the prepared source actually contains explicit absence records.
snapshot_files <- list.files("database/snapshots/20261124T1545482585117Z",
                              "^mammals_ungulates_dwc_occ[.]csv$", recursive = TRUE, full.names = TRUE)
stopifnot(length(snapshot_files) == 1L)
snapshot <- read.csv(snapshot_files, fileEncoding = "UTF-8")
scope_key <- function(x) paste(x$eventID, x$country, x$taxonID, sep = "|")
later_events <- unique(unlist(lapply(packages, function(x) x$records$eventID)))
in_scope <- snapshot$eventID %in% later_events |
  (is.na(snapshot$year) & scope_key(snapshot) %in% scope_key(baseline))
explicit_absence_events <- unique(records$eventID[records$presence %in% 0L])
included_status <- snapshot$presence %in% c(1, 5, 9) |
  (snapshot$presence %in% 0L & snapshot$eventID %in% explicit_absence_events)
if (!"verbatimEventDate" %in% names(snapshot)) snapshot$verbatimEventDate <- NA_character_
if (!"verbatimEventDate" %in% names(records)) records$verbatimEventDate <- NA_character_
comparison_fields <- c(record_fields, "verbatimEventDate")
rebuilt <- st_drop_geometry(records)[comparison_fields]
saved <- snapshot[in_scope & included_status, comparison_fields]
rebuilt_keys <- record_key(rebuilt)
saved_keys <- record_key(saved)
summary <- do.call(rbind, lapply(unique(c(rebuilt$eventID, saved$eventID)), function(id) {
  new <- unique(rebuilt_keys[rebuilt$eventID %in% id])
  old <- unique(saved_keys[saved$eventID %in% id])
  data.frame(eventID = id, matched = length(intersect(new, old)),
             only_in_rebuild = length(setdiff(new, old)), only_in_snapshot = length(setdiff(old, new)))
}))

catalogue <- read.csv("sources/catalogue.csv", fileEncoding = "UTF-8")
coverage <- catalogue[c("dataset", "status", "next_action")]
coverage$included_as <- "Not prepared or connected"
coverage$included_as[coverage$dataset == "initial_compilation"] <- "Linked baseline only"
for (package in packages) {
  key <- unique(package$records$sourceDataset)
  mode <- unique(package$records$inputMode)
  if (!key %in% coverage$dataset) {
    coverage <- rbind(coverage, data.frame(dataset = key, status = "Prepared",
      next_action = "Review processing and comparison reports", included_as = ""))
  }
  coverage$included_as[coverage$dataset %in% key] <- paste(mode, collapse = "; ")
  coverage$status[coverage$dataset %in% key] <- if (all(mode == "raw"))
    "Prepared from original input" else "Existing prepared grids reused"
  coverage$next_action[coverage$dataset %in% key] <- "Review processing and comparison reports"
}
coverage$next_action[coverage$dataset == "carnivores_lcie_2017_2023"] <-
  "Brown bear profile enabled; remaining LCIE layers require source review"

# Replace the local consolidated layers. Source-level record_links remain in
# each prepared package so original observation IDs and metadata stay available.
st_write(records, rebuild_db, layer = "rebuilt_source_records", delete_layer = TRUE, quiet = TRUE)
st_write(registry, rebuild_db, layer = "sources", delete_layer = TRUE, quiet = TRUE)
local_links <- links
names(local_links)[names(local_links) == "ID"] <- "legacyID"
st_write(local_links, rebuild_db, layer = "source_files", delete_layer = TRUE, quiet = TRUE)
write.csv(summary, file.path(rebuild_dir, "comparison.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(rebuilt[!rebuilt_keys %in% saved_keys, ], file.path(rebuild_dir, "only_in_rebuild.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(saved[!saved_keys %in% rebuilt_keys, ], file.path(rebuild_dir, "only_in_snapshot.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(coverage, file.path(rebuild_dir, "source_coverage.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(registry, registry_file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
write.csv(links, links_file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
print(summary, row.names = FALSE)
cat(nrow(records), "records consolidated from", length(packages), "prepared sources and the linked baseline\n")
cat(unlinked_baseline, "unlinked baseline rows remain outside the consolidated output\n")
cat("Bibliography and file links registered. PostgreSQL was not modified\n")
