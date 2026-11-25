# Estonia observations

The original point files are missing locally. The existing prepared species/year
grids are available and can be retained without claiming a reconstruction from
raw observations.

- Source rules: `scripts/sources/estonia_observations.R`.
- Original input type: `points`; current reuse uses the `grids` processor.
- Reference eventID: `ROAEE1485`; the registered bibliography is reused.

From the project root:

```r
source("scripts/02_prepare_source.R")
prepare_source("estonia_observations", use_existing = TRUE)
```

This creates the same `prepared/records.gpkg` package as the other sources and
marks its input mode as `reused_prepared_grids`. Generated historical zero rows
are not interpreted as observed absences. Script 3 uses the standard package
when present; otherwise it retains the existing-grid fallback as before.

Calling preparation without `use_existing = TRUE` stops with a message about
the missing input. Reconstructing Estonia from raw points requires recovering
those original files and completing their field mapping in the source profile.
