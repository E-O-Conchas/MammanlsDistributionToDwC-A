@echo off
setlocal

REM Define the base output directory
set "base_dir=I:\biocon\Emmanuel_Oceguera\projects\Mammals_species_distribution_DarwingCore\output\raw_species_by_country"

REM Loop through each country directory
for /D %%C in ("%base_dir%\*") do (
    REM Check if the spp directory exists and delete it
    if exist "%%C\spp" (
        echo Deleting folder: %%C\spp
        rd /s /q "%%C\spp"
    )
)

echo All spp folders have been deleted.
endlocal
