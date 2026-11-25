# Assign distribution polygons to the reference grid. Keep the intersection
# rule verified for France, including boundary intersections.
process_polygons <- function(data, grid) {
  stopifnot(all(st_geometry_type(data) %in% c("POLYGON", "MULTIPOLYGON")))
  data <- st_make_valid(st_transform(data, st_crs(grid)))
  hits <- st_intersects(grid, data)
  list(grid = grid, grid_rows = rep(seq_len(nrow(grid)), lengths(hits)),
       source_rows = unlist(hits, use.names = FALSE))
}
