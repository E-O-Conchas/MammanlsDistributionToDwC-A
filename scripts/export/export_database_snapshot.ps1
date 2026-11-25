#requires -Version 7.0
<#
Inspect the project database without changing it.
Add -Snapshot to save a PostgreSQL custom-format export of the project schema.
Add -Dwca to save the snapshot, readable tables and a draft Darwin Core Archive.

From the project directory:
  & ./scripts/export/export_database_snapshot.ps1
  & ./scripts/export/export_database_snapshot.ps1 -Snapshot
  & ./scripts/export/export_database_snapshot.ps1 -Dwca

Credentials are read from database/connection.local.yml and passed only through each child
process environment. No credentials are copied into the export manifest.
#>
[CmdletBinding()]
param(
    [switch]$Snapshot,
    [switch]$Dwca,
    [string]$Schema = 'eu_mammals_darwin_core',
    [string]$ConfigPath,
    [string]$PostgresBin,
    [string]$PythonExe,
    [string]$QgisRoot = 'C:\Program Files\QGIS 3.40.10'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $ConfigPath) { $ConfigPath = Join-Path $projectRoot 'database/connection.local.yml' }
if ($Dwca) {
    $Snapshot = $true
    if (-not $PythonExe) {
        $PythonExe = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    }
    if (-not (Test-Path -LiteralPath $PythonExe)) { throw 'Supply -PythonExe pointing to Python 3.12 or later.' }
    if (-not (Test-Path -LiteralPath (Join-Path $QgisRoot 'bin/gdaltransform.exe'))) {
        throw 'Supply -QgisRoot pointing to an installed QGIS directory with GDAL.'
    }
}

function Read-DbSettings([string]$FilePath) {
    # This project's config uses a simple, indented mapping of scalar DB fields.
    # Reject unsupported syntax instead of interpreting or displaying credentials.
    $settings = @{}
    $inDb = $false
    foreach ($line in Get-Content -LiteralPath $FilePath -Encoding utf8) {
        if ($line -match '^db:\s*(?:#.*)?$') { $inDb = $true; continue }
        if ($line -match '^\S' -and $line -notmatch '^#') { $inDb = $false }
        if (-not $inDb -or $line -notmatch '^\s+(name|host|port|user|password):\s*(.*?)\s*$') { continue }
        $key = $Matches[1]
        $value = $Matches[2]
        if ($value.StartsWith('"')) {
            try { $value = ConvertFrom-Json -InputObject $value -ErrorAction Stop }
            catch { throw "Unsupported quoted value in database setting '$key'." }
        } elseif ($value.StartsWith("'")) {
            if (-not $value.EndsWith("'") -or $value.Length -lt 2) {
                throw "Unsupported quoted value in database setting '$key'."
            }
            $value = $value.Substring(1, $value.Length - 2).Replace("''", "'")
        } else {
            $value = ($value -replace '\s+#.*$', '').Trim()
        }
        $settings[$key] = [string]$value
    }
    foreach ($key in @('name', 'host', 'port', 'user', 'password')) {
        if (-not $settings.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($settings[$key])) {
            throw "Missing database setting '$key' in the project configuration."
        }
    }
    return $settings
}

function Find-PostgresBin([string]$RequestedPath) {
    if ($RequestedPath) { return $RequestedPath }
    $command = Get-Command psql.exe -ErrorAction SilentlyContinue
    if ($command) { return Split-Path -Parent $command.Source }
    $installRoot = Join-Path $env:ProgramFiles 'PostgreSQL'
    if (Test-Path -LiteralPath $installRoot) {
        $versions = Get-ChildItem -LiteralPath $installRoot -Directory |
            Where-Object { $_.Name -match '^\d+(\.\d+){0,3}$' } |
            Sort-Object { [version]($_.Name -replace '^(\d+)$', '$1.0') } -Descending
        foreach ($directory in $versions) {
            $candidate = Join-Path $directory.FullName 'bin'
            if (Test-Path -LiteralPath (Join-Path $candidate 'psql.exe')) { return $candidate }
        }
    }
    throw 'PostgreSQL client tools were not found. Supply -PostgresBin with their bin directory.'
}

function Invoke-PgTool([string]$Executable, [string[]]$ToolArguments, [hashtable]$Settings) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    foreach ($argument in $ToolArguments) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.Environment['PGHOST'] = $Settings.host
    $startInfo.Environment['PGPORT'] = $Settings.port
    $startInfo.Environment['PGDATABASE'] = $Settings.name
    $startInfo.Environment['PGUSER'] = $Settings.user
    $startInfo.Environment['PGPASSWORD'] = $Settings.password
    $startInfo.Environment['PGCONNECT_TIMEOUT'] = '10'
    $startInfo.Environment['PGCLIENTENCODING'] = 'UTF8'
    $startInfo.Environment['PGAPPNAME'] = 'mammals_snapshot_export'
    $startInfo.Environment['PGOPTIONS'] = '-c default_transaction_read_only=on -c lock_timeout=10000'
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $result = @{
            ExitCode = $process.ExitCode
            Stdout = $stdout.Replace($Settings.password, '[redacted]')
            Stderr = $stderr.Replace($Settings.password, '[redacted]')
        }
    } finally { $process.Dispose() }
    if ($result.ExitCode -ne 0) { throw "PostgreSQL tool failed: $($result.Stderr.Trim())" }
    return $result
}

$dbSettings = Read-DbSettings $ConfigPath
$bin = Find-PostgresBin $PostgresBin
$psqlPath = Join-Path $bin 'psql.exe'
$schemaLiteral = $Schema.Replace("'", "''")

# reltuples is an estimate, not an exact row count or a modification timestamp.
# No row data or credentials are returned by this inventory.
$inventorySql = @"
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '60s';
SELECT json_build_object(
  'inventory_time_utc', to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'database', current_database(),
  'server_version', current_setting('server_version'),
  'schema', '$schemaLiteral',
  'schema_exists', EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = '$schemaLiteral'),
  'other_mammal_schemas', (SELECT coalesce(json_agg(nspname), '[]'::json) FROM pg_namespace WHERE nspname ILIKE '%mammal%'),
  'tables', (
    SELECT coalesce(json_agg(t ORDER BY t.table_name), '[]'::json)
    FROM (
      SELECT c.relname AS table_name,
             c.relkind AS relation_kind,
             c.reltuples::bigint AS estimated_rows,
             has_table_privilege(c.oid, 'SELECT') AS can_read,
             (SELECT json_agg(json_build_object(
                 'name', a.attname,
                 'type', format_type(a.atttypid, a.atttypmod)
              ) ORDER BY a.attnum)
              FROM pg_attribute a
              WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS columns
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = '$schemaLiteral' AND c.relkind IN ('r','p','v','m','f')
    ) t
  )
);
COMMIT;
"@

Write-Host 'Inspecting the project database in read-only mode...'
$response = Invoke-PgTool $psqlPath @('-X', '-w', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-c', $inventorySql) $dbSettings
$inventory = ConvertFrom-Json -InputObject $response.Stdout
if (-not $inventory.schema_exists) {
    throw "The configured project schema was not found. Mammal schemas visible: $($inventory.other_mammal_schemas -join ', ')."
}
if (@($inventory.tables).Count -eq 0) { throw 'The project schema has no visible tables or views.' }

$stamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')
$exportRoot = Join-Path $projectRoot 'database/snapshots'
$runDirectory = Join-Path $exportRoot $stamp
[void](New-Item -ItemType Directory -Path $runDirectory)
$inventory | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $runDirectory 'inventory.json') -Encoding utf8

$manifest = [ordered]@{
    format = 'PostgreSQL project schema snapshot'
    dwca_created = $false
    status = 'inventory_only'
    schema = $Schema
    database = $inventory.database
    server_version = $inventory.server_version
    inventory_time_utc = $inventory.inventory_time_utc
    inventory_row_counts_are_estimates = $true
    latest_table_has_not_been_inferred = $true
    scope = 'Selected schema only. External schemas, PostGIS installation and database roles are not included.'
}
$manifestPath = Join-Path $runDirectory 'manifest.json'
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$inventory.tables | Select-Object table_name, estimated_rows, can_read | Format-Table -AutoSize

if ($Snapshot) {
    $dumpPath = Join-Path $bin 'pg_dump.exe'
    $restorePath = Join-Path $bin 'pg_restore.exe'
    foreach ($tool in @($dumpPath, $restorePath)) {
        if (-not (Test-Path -LiteralPath $tool)) { throw 'pg_dump and pg_restore must be installed alongside psql.' }
    }
    $manifest['status'] = 'export_in_progress'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    $archivePath = Join-Path $runDirectory 'project_schema.dump'
    try {
        Write-Host 'Saving a consistent export of the project schema...'
        $quotedSchema = '"' + $Schema.Replace('"', '""') + '"'
        $dumpResult = Invoke-PgTool $dumpPath @('-w', '--format=custom', '--no-owner', '--no-privileges', "--schema=$quotedSchema", '--strict-names', "--file=$archivePath") $dbSettings
        $archiveIndex = Invoke-PgTool $restorePath @('--list', $archivePath) $dbSettings
        $archiveIndex.Stdout | Set-Content -LiteralPath (Join-Path $runDirectory 'archive_contents.txt') -Encoding utf8
        $warnings = @($dumpResult.Stderr, $archiveIndex.Stderr) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($warnings) { $warnings | Set-Content -LiteralPath (Join-Path $runDirectory 'export_warnings.txt') -Encoding utf8 }
        $manifest['status'] = 'export_complete'
        $manifest['completed_at_utc'] = [DateTimeOffset]::UtcNow.ToString('o')
        $manifest['archive_file'] = 'project_schema.dump'
        $manifest['archive_bytes'] = (Get-Item -LiteralPath $archivePath).Length
        $manifest['archive_sha256'] = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifest['archive_index_readable'] = $true
        $manifest['restore_test_performed'] = $false
        $manifest['inventory_and_dump_use_separate_read_only_connections'] = $true
    } catch {
        $manifest['status'] = 'export_failed'
        $manifest['error'] = $_.Exception.Message.Replace($dbSettings.password, '[redacted]')
        throw
    } finally {
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    }
}

if ($Dwca) {
    Write-Host 'Exporting the saved snapshot to readable tables and a draft DwC-A...'
    & $PythonExe (Join-Path $PSScriptRoot 'export_dwca_from_snapshot.py') $runDirectory --pg-bin $bin --qgis-root $QgisRoot
    if ($LASTEXITCODE -ne 0) { throw "Draft DwC-A export failed. The database snapshot is preserved at $runDirectory." }
}
if ($Dwca) {
    $completedManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
    $savedArchive = Join-Path $runDirectory $completedManifest.dwca_file
    $draftDirectory = Join-Path $projectRoot "exports/drafts/$stamp"
    [void](New-Item -ItemType Directory -Path $draftDirectory)
    Copy-Item -LiteralPath $savedArchive -Destination $draftDirectory
    Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $savedArchive) 'export_report.json') -Destination $draftDirectory
    $latest = [ordered]@{
        snapshot = "database/snapshots/$stamp"
        archive = "exports/drafts/$stamp/$(Split-Path -Leaf $savedArchive)"
        publication_ready = $false
        archive_sha256 = $completedManifest.dwca_sha256
    }
    $latest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $projectRoot 'exports/LATEST.json') -Encoding utf8
}
Write-Host "Saved to: $runDirectory"
if (-not $Snapshot) { Write-Host 'To save the database schema and data as well, rerun with -Snapshot.' }
if ($Dwca) {
    Write-Host 'A draft DwC-A was created. Review export_report.json before publication.'
} else {
    Write-Host 'This is a database inventory/snapshot. It is not a Darwin Core Archive.'
}
