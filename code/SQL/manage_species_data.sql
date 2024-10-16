-- Delete all the entries
TRUNCATE TABLE eu_mammals_darwin_core.species_distribution_atlas_thuringen;

-- Function to automatically update the timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the update_timestamp function on insert
CREATE TRIGGER point_insert_trigger
BEFORE INSERT OR UPDATE ON eu_mammals_darwin_core.species_distribution_atlas_thuringen 
EXECUTE FUNCTION update_timestamp();

-- Function to standardize the 'status' field
CREATE OR REPLACE FUNCTION standardize_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.status = INITCAP(NEW.status);  -- Capitalizes the first letter of each word in status
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to standardize the 'status' field before insert or update
CREATE TRIGGER standardize_status_trigger
BEFORE INSERT OR UPDATE ON eu_mammals_darwin_core.species_distribution_atlas_thuringen
FOR EACH ROW
EXECUTE FUNCTION standardize_status();


-- function that will determine the value of source before inserting the row.
CREATE OR REPLACE FUNCTION set_default_source()
RETURNS TRIGGER AS $$
BEGIN
    -- If the source is not provided, set it to a default value
    IF NEW.source IS NULL THEN
        -- Assign the first available non-NULL source from the existing data
        SELECT source INTO NEW.source
        FROM eu_mammals_darwin_core.species_distribution_atlas_thuringen
        WHERE source IS NOT NULL
        LIMIT 1;

        -- Optionally, set a default value if no existing source is found
        IF NEW.source IS NULL THEN
            NEW.source := 'Görner, M. (Ed.). (2009). Atlas der Säugetiere Thüringens: Biologie, Lebensräume, Verbreitung, Gefährdung, Schutz. Arbeitsgruppe Artenschutz Thüringen.';
        END IF;
    END IF;

    -- Continue with the insert operation
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- trigger that will call this function before each insert
CREATE TRIGGER before_insert_set_source
BEFORE INSERT ON eu_mammals_darwin_core.species_distribution_atlas_thuringen
FOR EACH ROW
EXECUTE FUNCTION set_default_source();

''' Insert data to main mammals dataset dataset'''
---------------- Ungulates
SELECT *
FROM eu_mammals_darwin_core.species_distribution_atlas_thuringen eu_mammals_darwin_core.ovimus_th

-- Temporary Disable Triggers
ALTER TABLE eu_mammals_darwin_core.species_distribution_atlas_thuringen DISABLE TRIGGER ALL;

------ Ovis musimon
INSERT INTO eu_mammals_darwin_core.species_distribution_atlas_thuringen (species, status, year_start, year_end, source, geom)
SELECT species, INITCAP(status), year_start, year_end, 
       COALESCE(source, 'Görner, M. (Ed.). (2009). Atlas der Säugetiere Thüringens: Biologie, Lebensräume, Verbreitung, Gefährdung, Schutz. Arbeitsgruppe Artenschutz Thüringen.'),
       geom
FROM eu_mammals_darwin_core.ovimus_th

------ Cervus dama
INSERT INTO eu_mammals_darwin_core.species_distribution_atlas_thuringen (species, status, year_start, year_end, source, geom)
SELECT species, INITCAP(status), year_start, year_end, 
       COALESCE(source, 'Görner, M. (Ed.). (2009). Atlas der Säugetiere Thüringens: Biologie, Lebensräume, Verbreitung, Gefährdung, Schutz. Arbeitsgruppe Artenschutz Thüringen.'),
       geom
FROM eu_mammals_darwin_core.cerdam_th

-- Activate Triggers 
ALTER TABLE eu_mammals_darwin_core.species_distribution_atlas_thuringen ENABLE TRIGGER ALL;

-- Verify the insertion
SELECT *
FROM eu_mammals_darwin_core.species_distribution_atlas_thuringen
WHERE species = 'Cervus dama'

-- Verify the unique values
SELECT DISTINCT species
FROM eu_mammals_darwin_core.species_distribution_atlas_thuringen

''' We map the specie code '''
ALTER TABLE eu_mammals_darwin_core.species_distribution_atlas_thuringen
ADD COLUMN species_code VARCHAR(10);

UPDATE eu_mammals_darwin_core.species_distribution_atlas_thuringen
SET species_code = CASE
    WHEN species = 'Cervus dama' THEN 'CERDAM'
    WHEN species = 'Ovis musimon' THEN 'OVIMUS'
	ELSE NULL
END;

SELECT DISTINCT species, species_code
FROM eu_mammals_darwin_core.species_distribution_atlas_thuringen;




