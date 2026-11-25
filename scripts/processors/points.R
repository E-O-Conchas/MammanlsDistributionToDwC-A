# Assign observation points to the reference grid. Boundary points can match
# more than one cell, as in the historical st_intersects workflow.
process_points <- function(data, grid) {
  stopifnot(all(st_geometry_type(data) %in% c("POINT", "MULTIPOINT")))
  data <- st_transform(data, st_crs(grid))
  hits <- st_intersects(grid, data)
  list(grid = grid, grid_rows = rep(seq_len(nrow(grid)), lengths(hits)),
       source_rows = unlist(hits, use.names = FALSE))
}
