"""Export an existing project database snapshot; never connect to a database.

Uses PostgreSQL pg_restore to read a local dump and GDAL to transform coordinates.
Only Python's standard library is required. The Event-core design follows the
provided Germany test; its Germany-only EML and CC0 claim are not copied.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import struct
import tempfile
from collections import Counter, defaultdict
from datetime import datetime, timezone
import xml.etree.ElementTree as ET
from zipfile import ZipFile, ZIP_DEFLATED


CONTROL = {"b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v"}
ESCAPE = re.compile(r"\\([0-7]{1,3}|x[0-9a-fA-F]{1,2}|.)")
DWCT = "http://rs.tdwg.org/dwc/terms/"
TEXTNS = "http://rs.tdwg.org/dwc/text/"
DC = "http://purl.org/dc/terms/"


def decode_copy(value):
    if value == r"\N":
        return None
    def convert(match):
        token = match[1]
        if token[0] in "01234567":
            return chr(int(token, 8))
        if token.startswith("x") and len(token) > 1:
            return chr(int(token[1:], 16))
        return CONTROL.get(token, token)
    return ESCAPE.sub(convert, value)


def extract_table(pg_restore, archive, table, target):
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as errors:
        process = subprocess.Popen(
            [str(pg_restore), "--data-only", "--file=-", "--table=" + table, str(archive)],
            stdout=subprocess.PIPE, stderr=errors, text=True, encoding="utf-8",
        )
        active = False
        found = False
        ended = False
        rows = 0
        columns = []
        try:
            with target.open("x", encoding="utf-8", newline="") as output:
                # Quoted empty text and unquoted nulls remain distinct on disk.
                writer = csv.writer(output, quoting=csv.QUOTE_NOTNULL, lineterminator="\n")
                for raw_line in process.stdout:
                    line = raw_line.removesuffix("\n").removesuffix("\r")
                    if line.startswith("COPY ") and line.endswith(") FROM stdin;"):
                        if found:
                            raise ValueError("Multiple COPY sections for " + table)
                        columns = next(csv.reader([line.split(" (", 1)[1][:-13]], skipinitialspace=True))
                        writer.writerow(columns)
                        found = active = True
                    elif active and line == r"\.":
                        active = False
                        ended = True
                    elif active:
                        values = [decode_copy(value) for value in line.split("\t")]
                        if len(values) != len(columns):
                            raise ValueError("Column mismatch in " + table)
                        writer.writerow(values)
                        rows += 1
            code = process.wait()
            errors.seek(0)
            if code:
                raise RuntimeError(errors.read())
            if not found or not ended:
                raise ValueError("No complete COPY section for " + table)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()
    return {"rows": rows, "columns": columns, "file": target.name}


def read_csv(path):
    with path.open(encoding="utf-8", newline="") as stream:
        yield from csv.DictReader(stream)


def transform_points(points, gdal, proj_data):
    env = os.environ.copy()
    env["PROJ_DATA"] = str(proj_data)
    env["PROJ_LIB"] = str(proj_data)
    result = subprocess.run(
        [str(gdal), "-s_srs", "EPSG:3035", "-t_srs", "EPSG:4326"],
        input="".join(f"{x:.15g} {y:.15g}\n" for x, y in points),
        capture_output=True, text=True, encoding="utf-8", env=env, check=True,
    )
    lines = result.stdout.splitlines()
    if len(lines) != len(points):
        raise ValueError("Coordinate transformation returned an unexpected number of points")
    transformed = {}
    for original, line in zip(points, lines):
        longitude, latitude, *_ = map(float, line.split())
        if not math.isfinite(longitude) or not math.isfinite(latitude) or not (-180 <= longitude <= 180 and -90 <= latitude <= 90):
            raise ValueError("Invalid transformed coordinates")
        transformed[original] = (longitude, latitude)
    return transformed


def inspect_spatial_table(pg_restore, archive):
    """Check the actual EWKB SRIDs, including tables with generic geometry type."""
    points = set()
    rows = 0
    active = False
    ended = False
    srids = set()
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as errors:
        process = subprocess.Popen(
            [str(pg_restore), "--data-only", "--file=-", "--table=mammals_ungulates_dwc_occ_sf", str(archive)],
            stdout=subprocess.PIPE, stderr=errors, text=True, encoding="utf-8",
        )
        try:
            for raw_line in process.stdout:
                line = raw_line.removesuffix("\n").removesuffix("\r")
                if line.startswith("COPY ") and line.endswith(") FROM stdin;"):
                    columns = next(csv.reader([line.split(" (", 1)[1][:-13]], skipinitialspace=True))
                    geometry_index = columns.index("geometry")
                    active = True
                elif active and line == r"\.":
                    active = False
                    ended = True
                elif active:
                    raw = bytes.fromhex(line.split("\t")[geometry_index])
                    endian = "<" if raw[0] == 1 else ">"
                    geometry_type = struct.unpack_from(endian + "I", raw, 1)[0]
                    if not geometry_type & 0x20000000 or geometry_type & 0x1FFFFFFF != 1:
                        raise ValueError("Expected point EWKB with explicit SRID")
                    srids.add(struct.unpack_from(endian + "I", raw, 5)[0])
                    points.add(struct.unpack_from(endian + "dd", raw, 9))
                    rows += 1
            code = process.wait()
            errors.seek(0)
            if code:
                raise RuntimeError(errors.read())
            if not ended or not rows or srids != {3035}:
                raise ValueError("Spatial table contains missing records or an unexpected coordinate system")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()
    return points, rows, sorted(srids)


def write_tsv(path, columns, rows):
    with path.open("x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        writer.writerow(columns)
        writer.writerows(rows)


def year_value(value):
    return value if value and re.fullmatch(r"[12][0-9]{3}", value) else ""


def build_meta(path, event_columns, occurrence_columns):
    ET.register_namespace("", TEXTNS)
    root = ET.Element("{" + TEXTNS + "}archive")
    for tag, rowtype, columns, filename in [
        ("core", "Event", event_columns, "event.txt"),
        ("extension", "Occurrence", occurrence_columns, "occurrence.txt"),
    ]:
        section = ET.SubElement(root, "{" + TEXTNS + "}" + tag, {
            "encoding": "UTF-8", "fieldsTerminatedBy": r"\t", "linesTerminatedBy": r"\n",
            "fieldsEnclosedBy": '"', "ignoreHeaderLines": "1", "rowType": DWCT + rowtype,
        })
        files = ET.SubElement(section, "{" + TEXTNS + "}files")
        ET.SubElement(files, "{" + TEXTNS + "}location").text = filename
        ET.SubElement(section, "{" + TEXTNS + "}" + ("id" if tag == "core" else "coreid"), index="0")
        for index, column in enumerate(columns[1:], 1):
            term = DC + column if column in {"bibliographicCitation", "references"} else DWCT + column
            ET.SubElement(section, "{" + TEXTNS + "}field", index=str(index), term=term)
    ET.indent(root)
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--pg-bin", type=Path, default=Path("C:/Program Files/PostgreSQL/17/bin"))
    parser.add_argument("--qgis-root", type=Path, default=Path("C:/Program Files/QGIS 3.40.10"))
    args = parser.parse_args()
    folder = args.snapshot.resolve()
    archive = folder / "project_schema.dump"
    manifest_path = folder / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if manifest.get("status") != "export_complete":
        raise ValueError("A completed database snapshot is required")
    actual_hash = hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual_hash != manifest["archive_sha256"]:
        raise ValueError("Snapshot checksum mismatch")
    destination = folder / "readable_export"
    if destination.exists():
        destination = folder / ("readable_export_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    destination.mkdir()  # An existing export is never overwritten.
    profile = {}
    for table in ["mammals_dwc_event", "mammals_ungulates_dwc_occ", "shapefiles_database"]:
        profile[table] = extract_table(args.pg_bin / "pg_restore.exe", archive, table, destination / (table + ".csv"))
        print(table, profile[table]["rows"], flush=True)

    sources = list(read_csv(destination / "mammals_dwc_event.csv"))
    source_ids = {row["eventID"] for row in sources}
    if len(source_ids) != len(sources) or "" in source_ids:
        raise ValueError("Source event IDs must be unique and nonempty")
    occurrences_path = destination / "mammals_ungulates_dwc_occ.csv"
    points = set()
    statuses = Counter()
    source_counts = Counter()
    countries = set()
    taxa = set()
    keys = Counter()
    conflicts = defaultdict(set)
    missing_years = 0
    for row in read_csv(occurrences_path):
        source_counts[row["eventID"]] += 1
        statuses[row["presence"]] += 1
        countries.add(row["country"])
        taxa.add(row["scientificName"])
        missing_years += not bool(year_value(row["year"]))
        point = (float(row["decimalLongitude"]), float(row["decimalLatitude"]))
        if not all(math.isfinite(value) for value in point):
            raise ValueError("Missing or nonfinite source coordinates")
        points.add(point)
        key = tuple(row[column] for column in ["cellcode", "taxonID", "country", "eventID", "year"])
        keys[key] += 1
        conflicts[key].add(row["presence"])
    orphans = sorted(set(source_counts) - source_ids)
    if orphans:
        raise ValueError("Occurrence sources missing from the source table: " + ", ".join(orphans))

    spatial_points, spatial_rows, srids = inspect_spatial_table(args.pg_bin / "pg_restore.exe", archive)
    if spatial_points != points or spatial_rows != sum(source_counts.values()):
        raise ValueError("Spatial and nonspatial tables disagree on coordinate coverage or row count")
    projected = transform_points(sorted(points), args.qgis_root / "bin/gdaltransform.exe", args.qgis_root / "share/proj")
    dwca = destination / "dwca_draft"
    dwca.mkdir()
    event_columns = ["id", "eventID", "bibliographicCitation", "references", "eventDate", "country", "countryCode", "stateProvince", "eventRemarks"]
    events = []
    for row in sources:
        start, end = year_value(row["yearIni"]), year_value(row["yearEnd"])
        date = start if start and start == end else (start + "/" + end if start and end else "")
        region = row.get("Region", "")
        if region == "NULL":
            region = ""
        events.append([row["eventID"], row["eventID"], row["bibliographicCitation"], row.get("pathway", ""), date,
                       row["country"], row["country"] if re.fullmatch("[A-Z]{2}", row["country"]) else "", region,
                       "Source compilation grouping inherited from the project database; sampling-event interpretation requires review."])
    write_tsv(dwca / "event.txt", event_columns, events)
    occurrence_columns = ["id", "eventID", "basisOfRecord", "occurrenceStatus", "country", "decimalLatitude", "decimalLongitude",
                          "geodeticDatum", "locationID", "taxonID", "scientificName", "kingdom", "year", "eventDate", "occurrenceRemarks", "dynamicProperties"]
    mapped_status = {"0": "absent", "1": "present", "9": "present"}
    def occurrence_rows():
        for row in read_csv(occurrences_path):
            longitude, latitude = projected[(float(row["decimalLongitude"]), float(row["decimalLatitude"]))]
            year = year_value(row["year"])
            yield [row["eventID"], row["eventID"], row["basisOfRecord"], mapped_status.get(row["presence"], ""), row["country"],
                   format(latitude, ".9f"), format(longitude, ".9f"), "EPSG:4326", row["cellcode"], row["taxonID"],
                   row["scientificName"], "Animalia", year, year, row["occurrenceRemarks"],
                   json.dumps({"sourcePresenceCode": row["presence"]}, separators=(",", ":"))]
    write_tsv(dwca / "occurrence.txt", occurrence_columns, occurrence_rows())
    build_meta(dwca / "meta.xml", event_columns, occurrence_columns)
    issues = [
        "Dataset-level EML, full geographic/temporal coverage, creator details and reuse license need review; Germany-only test metadata is not reused.",
        "Zero-to-absence semantics are inherited from the current database and have not been scientifically validated per source.",
        "Event records remain source-compilation groupings, matching the manual test design; survey-event granularity needs review.",
        "Codes 5 (extinct) and any unknown codes retain their original remarks/code and leave occurrenceStatus empty rather than inferring a time-specific absence.",
        "Coordinate uncertainty and the original grid-cell footprint are not yet encoded; centroids are not precise animal locations.",
    ]
    report = {
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "publication_ready": False, "source_snapshot_sha256": actual_hash,
        "tables": profile, "countries": len(countries), "scientific_names": len(taxa),
        "occurrence_rows": sum(source_counts.values()), "event_rows": len(sources),
        "source_presence_codes": dict(statuses), "occurrences_without_valid_year": missing_years,
        "orphan_event_ids": orphans, "duplicate_candidate_groups": sum(n > 1 for n in keys.values()),
        "conflicting_candidate_groups": sum(len(values) > 1 for values in conflicts.values()),
        "coordinates": "Export only: EPSG:3035 to EPSG:4326 using GDAL/PROJ; original CSV and database remain unchanged.",
        "verified_spatial_table": {"rows": spatial_rows, "srids": srids, "unique_points": len(spatial_points)},
        "status_mapping": {**mapped_status, "other": "empty; original code retained in dynamicProperties"},
        "publication_review_items": issues,
        "csv_null_encoding": "Null is unquoted empty; non-null strings, including empty strings, are quoted.",
    }
    (destination / "export_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    readme = "DRAFT DARWIN CORE DATA ARCHIVE\n\nCurrent database data exported from the accompanying immutable PostgreSQL snapshot.\nNo database records were changed. No records were removed or deduplicated.\nThe Event core retains the project's source-compilation IDs.\nProjected centroids are converted to geographic degrees in occurrence.txt only.\nOriginal fields and values remain in the CSVs and database dump.\n\nNOT READY FOR PUBLICATION\n" + "\n".join("- " + issue for issue in issues) + "\n\nReview export_report.json before use or publication.\n"
    (dwca / "README.txt").write_text(readme, encoding="utf-8")
    archive_path = destination / "mammals_current_database_dwca_DRAFT.zip"
    with ZipFile(archive_path, "x", compression=ZIP_DEFLATED) as output:
        for filename in ["event.txt", "occurrence.txt", "meta.xml", "README.txt"]:
            output.write(dwca / filename, arcname=filename)
    with ZipFile(archive_path) as check:
        if check.testzip() is not None:
            raise ValueError("ZIP integrity check failed")
        ET.fromstring(check.read("meta.xml"))
    manifest["dwca_created"] = True
    manifest["dwca_is_publication_ready"] = False
    manifest["dwca_file"] = str(archive_path.relative_to(folder)).replace("\\", "/")
    manifest["dwca_sha256"] = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    manifest["exact_exported_rows"] = {table: entry["rows"] for table, entry in profile.items()}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Draft DwC-A:", archive_path)
    print("Publication review items remain; see export_report.json.")


if __name__ == "__main__":
    main()
