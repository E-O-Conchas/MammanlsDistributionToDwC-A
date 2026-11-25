# European Mammal Distribution Database

This project builds and maintains a database on the distribution of mammals in Europe. It brings together data from different countries so readers can explore where each species has been documented and, when known, the period those records cover.

The current phase focuses on expanding the collection, organising new records in a common structure and preparing the dataset for sharing in **Darwin Core**, a standard for exchanging biodiversity data.

## Geographic and temporal coverage

The database snapshot of 24 November 2026 contains **778,393 distribution records across 33 countries**. For a species whose range crosses a national border, readers can bring together records from both sides and see which areas are represented in each country. Where dates are available, they can also see whether the records describe the same period. Some collections report a single year, while others describe a distribution over several years.

New datasets can extend coverage to another region, add a species or document a different period in an area already represented. Each addition is checked alongside the existing records before the database is updated. The Darwin Core Archive is currently a draft under review.

## Explore the project

| Component | What you can find |
|----|----|
| [Dataset catalogue](sources/catalogue.csv) | The collections included in the project, their geographic scope and their processing status. |
| [Source registry](reference/source_registry.csv) | Bibliographic references for the distribution data. |
| [Processing workflow](docs/workflow.md) | How new records are prepared, combined and checked. The [R guide](scripts/README.md) explains how to run the workflow. |
| [Database](database/README.md) | Documentation of the working database and its [latest recorded snapshot](database/CURRENT.json). |
| [Darwin Core Archive](exports/README.md) | The status of the draft prepared for publication. |

This repository contains the code, catalogue, reference tables and documentation. The spatial data and archive files are stored separately.
