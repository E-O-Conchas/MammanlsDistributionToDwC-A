# Keep supplied grid-cell geometry and identifiers. Do not intersect an
# already gridded source with another grid or create unreported cells.
process_grids <- function(data, grid = NULL) {
  stopifnot("cellcode" %in% names(data), !anyNA(data$cellcode),
            all(nzchar(data$cellcode)),
            all(st_geometry_type(data) %in% c("POLYGON", "MULTIPOLYGON")),
            isTRUE(st_crs(data) == st_crs(3035)),
            all(st_is_valid(data)), !any(st_is_empty(data)))
  list(grid = data, grid_rows = seq_len(nrow(data)), source_rows = seq_len(nrow(data)))
}
