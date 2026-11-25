# Shared references

- `source_registry.csv`: the local source/event registry, initially copied from
  the captured database. Script 3 registers prepared references without duplicate
  event IDs and retains existing row IDs.
- `source_file_links.csv`: the source/event links to input or reused grid files.
  Script 3 registers the file links supplied by each prepared package.
- `grids/`: national and regional reference grids.
- `boundaries/`: shared country boundaries.
- `bibliography/`: earlier reference workbooks. The starting workbook remains
  with `sources/initial_compilation/input`.
- `file_index.csv`: the original inventory of local source/reference paths and
  hashes; it is not an automatically refreshed processing manifest.

Each source's preparation rules are in `scripts/sources/`. A source profile
reuses a registered bibliographic reference or supplies a new reference once.
Its prepared package carries that reference alongside the records. New event
IDs must be stable; they should not depend on a changing record count.

The local rebuild includes `sources` and `source_files` tables. Updating local
CSV files or these tables does not update PostgreSQL. The captured snapshot
retains the original database values for comparison.
