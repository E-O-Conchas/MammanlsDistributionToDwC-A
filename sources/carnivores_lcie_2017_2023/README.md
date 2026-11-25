# LCIE large carnivore distributions

- Original files: `input/`.
- Source rules: `scripts/sources/carnivores_lcie_2017_2023.R`.
- Input type: `grids`; shared processor: `scripts/processors/grids.R`.
- Enabled layer: brown bear, eventID `LCIE2024_URSARC`.

From the project root, load `scripts/02_prepare_source.R` and call
`prepare_source("carnivores_lcie_2017_2023")`. The common output is
`prepared/records.gpkg`. Script 3 includes its records and registers the supplied
bibliography and file link. The original review GeoPackage is retained.

The source has 11,976 unique brown bear cells. The source spelling
`Ursus arctors` is normalized to `Ursus arctos`, with the original retained.
Presence categories, evidence quality, verbatim periods, underlying references
and compiler information are preserved. Multi-year periods remain intervals;
upper year bounds do not establish presence in every intervening year.

LCIE describes the supplied cells as occupied. `Undefined` is retained as a
category for review rather than converted to absence. Evidence quality remains
separate, including unconfirmed and extrapolated presence. Country and regional
labels remain as supplied.

The other LCIE layers are not enabled automatically. Their source fields need
review: for example, the wolf file contains 264 features labelled `Lynx lynx`.
This must be resolved before that layer can be attributed to a species. The
shared grids processor is already available for those layers once reviewed.

Reference: Kaczensky, P., Ranc, N., Hatlauf, J., Payne, J. C., et al. (2024).
*Large carnivore distribution maps for Europe 2017 - 2022/23* [Dataset]. Dryad.
https://doi.org/10.5061/dryad.3xsj3txrc
