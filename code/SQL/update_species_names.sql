'''This script is designed to update the species names into the database. 
If specie names has to be updated, this script will help to update the corresponding 
specie in any related source datasets.'''

-- check the unique species names
SELECT DISTINCT "scientificName"
FROM eu_mammals_darwin_core.mammals_ungulates_dwc_occ

----- Update Capra aegagrus to Capra hircus aegagrus
--- Update the mammals ungulates dwc occ
-- Check first the rows my be affected with the update
SELECT *
FROM eu_mammals_darwin_core.mammals_ungulates_dwc_occ
WHERE "scientificName" = 'Capra aegagrus'

-- We update the species in the database
UPDATE eu_mammals_darwin_core.mammals_ungulates_dwc_occ
SET "scientificName" = 'Capra hircus aegagrus'
WHERE "scientificName" = 'Capra aegagrus';

-- Check the output
SELECT *
FROM eu_mammals_darwin_core.mammals_ungulates_dwc_occ
WHERE "scientificName" = 'Capra hircus aegagrus'


--- Update the mammals ungulates dwc occ merged
-- Check first the rows my be affected with the update
SELECT *
FROM eu_mammals_darwin_core." mammals_ungulates_dwc_occ_merged"
WHERE "scientific" = 'Capra aegagrus'

-- We update the species in the database
UPDATE eu_mammals_darwin_core." mammals_ungulates_dwc_occ_merged"
SET "scientific" = 'Capra hircus aegagrus'
WHERE "scientific" = 'Capra aegagrus';

-- Check the output
SELECT *
FROM eu_mammals_darwin_core." mammals_ungulates_dwc_occ_merged"
WHERE "scientific" = 'Capra hircus aegagrus'


--- Update the mammals ungulates dwc occ sf
-- Check first the rows my be affected with the update
SELECT *
FROM eu_mammals_darwin_core.mammals_ungulates_dwc_occ_sf
WHERE "scientificName" = 'Capra aegagrus'

-- We update the species in the database
UPDATE eu_mammals_darwin_core.mammals_ungulates_dwc_occ_sf
SET "scientificName" = 'Capra hircus aegagrus'
WHERE "scientificName" = 'Capra aegagrus';

-- Check the output
SELECT *
FROM eu_mammals_darwin_core.mammals_ungulates_dwc_occ_sf
WHERE "scientificName" = 'Capra hircus aegagrus'

----- Update 
--- Update the species distribution 
-- Check unique values for species names






