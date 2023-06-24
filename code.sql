Create Table Statement:

TRI_Data:

CREATE TABLE ToxicReleaseInventory (
    year INTEGER,
    tri_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    street VARCHAR(255),
    city VARCHAR(255),
    county VARCHAR(255),
    state CHAR(2),
    zip CHAR(5),
    lat DOUBLE PRECISION,
    long DOUBLE PRECISION,
    Case_number VARCHAR(255),
    Chemical_name VARCHAR(255),
    Chemical_classification CHAR(3),
    Unit_measurement VARCHAR(255),
    total_waste DOUBLE PRECISION,
    );

City Boundary:

CREATE TABLE city_boundary (
    OBJECTID INTEGER PRIMARY KEY,
    NAME VARCHAR(50),
    Shape__Are NUMERIC(20, 6),
    Shape__Len NUMERIC(20, 10)
);


Air_quality:

CREATE TABLE air_quality (
    ObjectID INTEGER PRIMARY KEY,
    Date DATE,
    Sample_ID VARCHAR(10),
    Chemicals VARCHAR(50),
    Concentration NUMERIC(20, 15),
    Case_number VARCHAR(10),
    Facility_name VARCHAR(100),
    Facility_description VARCHAR(50),
    Address VARCHAR(50),
    City VARCHAR(50),
    State CHAR(2),
    Zip VARCHAR(10)
);

CREATE INDEX idx_air_quality_Facility_name ON air_quality (Facility_name);
CREATE INDEX idx_air_quality_Concentration ON air_quality (Concentration);
CREATE INDEX idx_air_quality_Case_number ON air_quality (Case_number);


Demographic:

CREATE TABLE demographics (
  gis_join VARCHAR(20) PRIMARY KEY,
  year VARCHAR(10),
  state_name VARCHAR(50),
  state_code INTEGER,
  county_name VARCHAR(50),
  county_code INTEGER,
  census_track_code INTEGER,
  block_group INTEGER,
  census_geographic_identifier VARCHAR(20),
  estimates_area_name VARCHAR(100),
  estimates_total INTEGER,
  total_population INTEGER,
  white_alone INTEGER,
  black_or_african_american_alone INTEGER,
  american_indian_and_alaskan_native_alone INTEGER,
  asian_alone INTEGER,
  native_hawaiian_and_other_pacific_islander_alone INTEGER,
  some_other_race_alone INTEGER,
  two_or_more_races INTEGER,
  two_or_more_races_including_some_other_race INTEGER,
  median_household_income INTEGER,
  nonwhite_pernectage DOUBLE PRECISION,
);

Code:

--A SQL query that involves only 1 table.

    --This code block retrieves information about facilities and the total count of chemicals associated with each facility.

SELECT 
  name AS facility_name, 
  long AS facility_longitude, 
  lat AS facility_latitude, 
  ST_SetSRID(
    ST_MakePoint(long, lat), 
    4326
  ) AS facility_geom, 
  COUNT(Chemical_name) AS total_chemical_count 
FROM 
  ToxicReleaseInventory 
GROUP BY 
  name, 
  long, 
  lat 
-- Order by total chemical count in descending order
ORDER BY 
  total_chemical_count DESC;
;




--A SQL query using a subquery or a common table expression

    --Calculate the top 10 facilities with the highest average non-white percentage within the Minneapolis city boundary

WITH facility_non_white AS (
  -- Select facility name, average non-white percentage and create a geometry point from lat and long
  SELECT 
    t.name AS facility_name, 
    AVG(nw.nonwhite_pernectage) AS average_non_white_percentage, 
    ST_SetSRID(
      ST_MakePoint(t.long, t.lat), 
      4326
    ) AS geom 
  FROM 
    ToxicReleaseInventory AS t 
    -- Filter records with distance between facility and racial data below the threshold (1000 meters or 1km)
    INNER JOIN Demographic AS nw ON ST_DWithin( 
      -- this one is hard to do the style guide with. Its not clear that this all belongs to the ST_DWithin function.
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ):: geography, 
      nw.geom :: geography, 
      1000
    ) 
    INNER JOIN city_boundary AS cb ON ST_Within(nw.geom, cb.geom) 
    -- Filter records within Minneapolis city boundary
    AND cb.name = 'Minneapolis' 
  GROUP BY 
    t.name, 
    t.long, 
    t.lat
) 
-- Select all records from facility_non_white view
SELECT 
  facility_name, 
  average_non_white_percentage, 
  geom 
FROM 
  facility_non_white 
-- Order by average non-white percentage in descending order
ORDER BY 
  average_non_white_percentage DESC 
-- Limit the number of records to 10
LIMIT 
  10;


-- 3. A SQL query that involves 2 or more tables.

--This code block creates three views (facility_population, facility_income, and facility_nonwhite) and retrieves facility names, their geometries, total population, average income, and average nonwhite percentage within a 1 km radius within each facility.

WITH facility_population AS (
  SELECT 
    t.name AS facility_name, 
    ST_SetSRID(
      ST_MakePoint(t.long, t.lat), 
      4326
    ) AS facility_geom, -- I'm more concerned about why you never corrected this to make them geoms.
    SUM(r.Total_population) AS total_population 
  FROM 
    ToxicReleaseInventory AS t 
-- Join with the Demographic table using a 1 km (1000 meters) buffer
    INNER JOIN Demographic AS r ON ST_DWithin(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ):: geography, 
      r.geom :: geography, 
      1000
    ) 
-- Filter facilities within Minneapolis city boundary
    INNER JOIN city_boundary AS cb ON ST_Within(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ), 
      cb.geom
    ) 
    AND cb.name = 'Minneapolis' 
  GROUP BY 
    t.name, 
    facility_geom
), 
facility_income AS (
  SELECT 
    t.name AS facility_name, 
    ST_SetSRID(
      ST_MakePoint(t.long, t.lat), 
      4326
    ) AS facility_geom, 
    AVG(i.median_household_income) AS average_income 
  FROM 
    ToxicReleaseInventory AS t 
-- Join with the Demographic table using a 1 km (1000 meters) buffer
    INNER JOIN Demographic AS i ON ST_DWithin(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ):: geography, 
      i.geom :: geography, 
      1000
    ) 
-- Filter facilities within Minneapolis city boundary
    INNER JOIN city_boundary AS cb ON ST_Within(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ), 
      cb.geom
    ) 
    AND cb.name = 'Minneapolis' 
  GROUP BY 
    t.name, 
    facility_geom
), 
facility_nonwhite AS (
  SELECT 
    t.name AS facility_name, 
    ST_SetSRID(
      ST_MakePoint(t.long, t.lat), 
      4326
    ) AS facility_geom, 
    AVG(d.nonwhite_pernectage) AS average_nonwhite_percentage 
  FROM 
    ToxicReleaseInventory AS t 
-- Join with the demographic table using 1km buffer
    INNER JOIN Demographic AS d ON ST_DWithin(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ):: geography, 
      d.geom :: geography, 
      1000
    ) 
-- Filter facilities within Minneapolis city boundary
    INNER JOIN city_boundary AS cb ON ST_Within(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ), 
      cb.geom
    ) 
    AND cb.name = 'Minneapolis' 
  GROUP BY 
    t.name, 
    facility_geom
) 
SELECT 
  fp.facility_name, 
  fp.facility_geom, 
  fp.total_population, 
  fi.average_income, 
  fn.average_nonwhite_percentage 
FROM 
  facility_population AS fp 
  INNER JOIN facility_income AS fi ON fp.facility_name = fi.facility_name 
  AND fp.facility_geom = fi.facility_geom 
  INNER JOIN facility_nonwhite AS fn ON fp.facility_name = fn.facility_name 
  AND fp.facility_geom = fn.facility_geom 
ORDER BY 
  total_population DESC;


-- 4.  Spatial query
        --Calculate the average concentration of each chemical within a 1 km radius of each facility in Minneapolis.

WITH facility_chemicals AS (
  SELECT 
    t.name AS facility_name, 
    t.geom AS facility_geom, 
    a."Chemicals" AS chemical, 
    AVG(a."Concentration") AS average_concentration 
  FROM 
    ToxicReleaseInventory AS t, 
    air_quality AS a, 
    city_boundary AS cb 
  WHERE 
-- Filter records within 1km (1000 meters) buffer from the facility
    ST_DWithin(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ):: geography, 
      a.geom :: geography, 
      1000
    ) 
-- Filter facilities within Minneapolis city boundary
    AND ST_Within(
      ST_SetSRID(
        ST_MakePoint(t.long, t.lat), 
        4326
      ), 
      cb.geom
    ) 
    AND cb.name = 'Minneapolis' 
  GROUP BY 
    t.name, 
    t.geom, 
    a."Chemicals"
) 
-- Select results from facility_chemical CTE
SELECT 
  facility_name, 
  facility_geom, 
  chemical, 
  average_concentration 
FROM 
  facility_chemicals 
-- Order results by facility name and average concentration in descending order
ORDER BY 
  facility_name, 
  average_concentration DESC;

