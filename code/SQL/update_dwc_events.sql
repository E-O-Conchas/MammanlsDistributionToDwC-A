'''This script is designed to update or insert an event into the database. 
If an eventID needs to be updated, this script will help to update the corresponding 
eventID in any related source datasets. Once the eventID is updated here, 
it will be automatically reflected in all related occurrence datasets, 
such as mammals_ungulates_dwc_occ and other datasets linked to mammals_dwc_event.
This script serves as the starting point for managing event updates across connected datasets.'''

-- Exaplme how to update the eventID
''' UPDATE eu_mammals_darwin_core.mammals_dwc_event
	SET eventID = 'new_event_id'
	WHERE eventID = 'old_event_id'; '''


-- Check the full events
SELECT * FROM eu_mammals_darwin_core.mammals_dwc_event

''' Dinamark '''
-- Check if the event for dinamark in updated; filter by countryCode
SELECT * FROM eu_mammals_darwin_core.mammals_dwc_event
WHERE country='DK'


''' Estonia '''
-- Update Estonia 'EE' information as well as the eventID
SELECT * FROM eu_mammals_darwin_core.mammals_dwc_event
WHERE country='EE'

UPDATE eu_mammals_darwin_core.mammals_dwc_event
SET
	"eventData" = '1890–2019',  -- Correct format for eventData if it's a string
    "yearIni" = 1890,
	"yearEnd" = 2019,  -- Update yearEnd to 2003
	"DATA_SOURCES" = 'Estonian Nature Observation database',
    "bibliographicCitation" = 'Roasto R (2019). Estonian Nature Observations Database. Version 87.15. Estonian Environment Information Centre. Occurrence dataset https://doi.org/10.15468/dlblir accessed via GBIF.org on 2023-09-04.',  -- New source information
    "DOI, ISBN, ISSN" = 'https://doi.org/10.15468/dlblir'  -- New DOI information
WHERE 
    "country" = 'EE';  -- Condition to match the rows for Denmark (DK)

-- Info to be insert
-- Name of the source: 'Estonian Nature Observation database'
-- citation: 'Roasto R (2019). Estonian Nature Observations Database. Version 87.15. Estonian Environment Information Centre. Occurrence dataset https://doi.org/10.15468/dlblir accessed via GBIF.org on 2023-09-04.'
-- DOI:  'https://doi.org/10.15468/dlblir'
-- Year range 1890–2019
-- eventID : ROAEE1485

-- Update the eventID
UPDATE eu_mammals_darwin_core.mammals_dwc_event
SET "eventID" = 'ROAEE1485' --New eventID
WHERE "eventID" = 'GBIFEE1485'; --Old eventID
-- After updating check whether the eventID as been also updated in spatial data using QGIS

update eu_mammals_darwin_core.mammals_dwc_event
set "bibliographicCitation" = 'Hauer, S., & Ansorge, H. U. Zöphel (2009): Atlas der Säugetiere Sachsens. Hrsg.: Sächsisches Landesamt für Umwelt, Landwirtschaft und Geologie. Dresden.'
where "bibliographicCitation" = 'Hauer, S., & Ansorge, H. U. ZÖPHEL (2009): Atlas der Säugetiere Sachsens. Hrsg.: Sächsisches Landesamt für Umwelt, Landwirtschaft und Geologie. Dresden.'

select *
from eu_mammals_darwin_core.mammals_dwc_event
where "bibliographicCitation" = 'Hauer, S., & Ansorge, H. U. Zöphel (2009): Atlas der Säugetiere Sachsens. Hrsg.: Sächsisches Landesamt für Umwelt, Landwirtschaft und Geologie. Dresden.'



'''This session is to update the specieColumn, including the additional species if needed'''
-- update the specieCode column for Sachsen
UPDATE eu_mammals_darwin_core.mammals_dwc_event
SET "specieCode" = "specieCode" || ',CERNIP, DAMDAM, CANLUP, LYNLYN, OVIAMM'
WHERE country = 'DE' AND "eventID" = 'HAUDESN0659' AND "Region" = 'SN';


-- update the specieCode column for Thuringen
UPDATE eu_mammals_darwin_core.mammals_dwc_event
SET "specieCode" = "specieCode" || ',DAMDAM, OVIMUS'
WHERE country = 'DE' AND "eventID" = 'GÖRDETH0507' AND "Region" = 'TH';



