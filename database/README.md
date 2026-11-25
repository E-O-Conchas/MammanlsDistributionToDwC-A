# Database state

PostgreSQL holds the working database. `snapshots/` contains dated captured states, including native dumps and complete export manifests. `CURRENT.json` identifies the existing captured reference; it does not claim to track later changes on the server.

`connection.local.yml` contains local credentials and is ignored by Git. A fresh clone needs its own local file based on `connection.example.yml`. Do not run historical replacement SQL to obtain an export.
