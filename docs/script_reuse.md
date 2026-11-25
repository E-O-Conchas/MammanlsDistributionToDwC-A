# Reusing existing processing code

The new import process has not been implemented. The previous working scripts
are retained under `archive/processing_scripts/` and remain versioned in Git.
They are references for refactoring, not a safe sequence to execute in full.

| Processing need | Existing reference | Review needed |
| --- | --- | --- |
| Starting compilation and attribution | `01_extract_spp_by_countries.R`, `02_create_shp_database.R`, `03_add_eventID_to_distribution_shp.R` | Retain original grid values and source mappings; prevent duplicate import |
| France | `preprocessing/france_database_prepro.R` | Reuse species/date handling; review polygon overlap and zero-filling |
| Estonia | `preprocessing/estonia_database_prepro.R` | Recover original input; preserve individual years and missing information |
| Poland | `preprocessing/poland_database_prepro.R` | Reuse point/species preparation; document manual CSV corrections |
| Digitized German atlases | `04_add_data_in_grid.R` | Separate digitization, gridding and status interpretation from database writes |
| Combining data | `05_process_mammals_distribution_data_clean.R` | Combine long tables; remove blanket missing-to-zero conversion and numeric conflict resolution |
| Database changes | Relevant `SQL/` sections | Replace broad destructive examples with scoped, validated transactions |
| Rasters | `06_rasterize_data.R` | Explicit categorical-state and temporal rules; an optional product |

The earlier three placeholder R files are preserved under archive/layout_v1/code.
They are not maintained entry points. New runnable commands should be introduced
only as each stage is implemented and tested.
