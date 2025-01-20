
-- This is a functon that triggers the event ID in the spatial data (point data),
-- So if there is any change in the mammals_dwc_event.eventID the other layers will be updated automatically 
CREATE OR REPLACE FUNCTION update_eventid_in_related_tables()
RETURNS TRIGGER AS $$
BEGIN
    -- Update eventID in mammals_ungulates_dwc_occ
    UPDATE eu_mammals_darwin_core.mammals_ungulates_dwc_occ
    SET "eventID" = NEW."eventID"  -- Correct case for "eventID"
    WHERE "eventID" = OLD."eventID";  -- Correct case for "eventID"

    -- Update eventID in mammals_ungulates_dwc_occ_merged
    UPDATE eu_mammals_darwin_core." mammals_ungulates_dwc_occ_merged"
    SET "eventID" = NEW."eventID"  -- Correct case for "eventID"
    WHERE "eventID" = OLD."eventID";  -- Correct case for "eventID"

    -- Update eventID in mammals_ungulates_dwc_occ_sf
    UPDATE eu_mammals_darwin_core.mammals_ungulates_dwc_occ_sf
    SET "eventID" = NEW."eventID"  -- Correct case for "eventID"
    WHERE "eventID" = OLD."eventID";  -- Correct case for "eventID"

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_update_eventid
AFTER UPDATE OF "eventID" ON eu_mammals_darwin_core.mammals_dwc_event
FOR EACH ROW
EXECUTE FUNCTION update_eventid_in_related_tables();

-- Delete trigger if exist 
DROP TRIGGER IF EXISTS trigger_update_eventid ON eu_mammals_darwin_core.mammals_dwc_event;
