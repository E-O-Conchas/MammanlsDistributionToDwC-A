# Original point files are missing locally. Existing species/year grids can be
# reused explicitly with prepare_source("estonia_observations", use_existing = TRUE).
source_config <- list(
  input_type = "points", country = "Estonia", event_id = "ROAEE1485",
  reference_grid = "reference/grids/EE/national_grid/ee_10km.shp",
  reuse_existing = TRUE,
  read_input = function() {
    stop(paste("Original Estonia point files are missing locally.",
               "Use prepare_source(\"estonia_observations\", use_existing = TRUE)",
               "to retain the existing grids. Raw reconstruction needs the original files."))
  }
)
