-- NYC 311 DATA CLEANING SCRIPT
-- Purpose:
-- This script cleans the raw NYC 311 service-request data.
--
-- Database: SQLite
-- Raw table required: raw_311
-- Clean table created: clean_data
--
-- Source:
-- NYC Open Data - 311 Service Requests from 2020 to Present
-- https://data.cityofnewyork.us/Social-Services/311-Service-Requests-from-2020-to-Present/erm2-nwe9
--
-- Before running this script:
-- 1. Create a SQLite database.
-- 2. Import the raw data into a table named raw_311.
-- 3. Keep raw_311 unchanged. This is the original source table.
--
-- The Excel file can be saved as CSV before importing into SQLite.
-- Example import commands:
--   .mode csv
--   .import raw_data.csv raw_311


-- STEP 1: Remove the old clean table
-- This allows the script to be run again without an error.

DROP TABLE IF EXISTS clean_data;


-- STEP 2: Create a standardized staging table
--
-- This step prepares the values before the final table is created.
--
-- TRIM removes spaces at the beginning and end of text.
-- NULLIF changes an empty value into NULL.
-- UPPER changes category text to uppercase so categories match.
-- date(substr(...)) keeps only the date from a date-time value.
--
-- Example:
--   "  closed  " becomes "CLOSED"
--   "" becomes NULL
--   "2026-09-12T02:06:02.000" becomes "2026-09-12"

DROP TABLE IF EXISTS cleaned_stage;

CREATE TABLE cleaned_stage AS
SELECT
    -- Rename unique_key to a clearer name for analysis.
    NULLIF(TRIM(unique_key), '') AS request_id,

    -- Keep only the date part of the creation value.
    date(substr(NULLIF(TRIM(created_date), ''), 1, 10))
        AS created_date,

    -- Keep only the date part of the closing value.
    -- If the request is still open, this remains NULL.
    date(substr(NULLIF(TRIM(closed_date), ''), 1, 10))
        AS closed_date,

    UPPER(NULLIF(TRIM(agency), '')) AS agency_code,
    NULLIF(TRIM(agency_name), '') AS agency_name,
    NULLIF(TRIM(complaint_type), '') AS complaint_type,
    NULLIF(TRIM(descriptor), '') AS descriptor,
    NULLIF(TRIM(location_type), '') AS location_type,

    -- Keep only ZIP codes that contain exactly five digits.
    -- Invalid or incomplete ZIP codes become NULL.
    CASE
        WHEN TRIM(incident_zip) GLOB '[0-9][0-9][0-9][0-9][0-9]'
        THEN CAST(TRIM(incident_zip) AS INTEGER)
        ELSE NULL
    END AS incident_zip,

    UPPER(NULLIF(TRIM(city), '')) AS city,
    UPPER(NULLIF(TRIM(status), '')) AS status,
    UPPER(NULLIF(TRIM(borough), '')) AS borough,
    NULLIF(TRIM(community_board), '') AS community_board,
    NULLIF(TRIM(open_data_channel_type), '') AS channel,

    -- Convert valid coordinate values from text to numbers.
    CASE
        WHEN TRIM(latitude) GLOB '-[0-9]*.[0-9]*'
          OR TRIM(latitude) GLOB '[0-9]*.[0-9]*'
        THEN CAST(latitude AS REAL)
        ELSE NULL
    END AS latitude,

    CASE
        WHEN TRIM(longitude) GLOB '-[0-9]*.[0-9]*'
          OR TRIM(longitude) GLOB '[0-9]*.[0-9]*'
        THEN CAST(longitude AS REAL)
        ELSE NULL
    END AS longitude

FROM raw_311;


-- STEP 3: Remove records without essential information

-- A request needs both of these fields for this project:
--   request_id: identifies the request
--   created_date: tells us when the request was created
--
-- Rows without either field cannot be used reliably in the dashboard.

DELETE FROM cleaned_stage
WHERE request_id IS NULL
   OR created_date IS NULL;


-- STEP 4: Remove duplicate requests

-- A request ID should appear only once in the final data.
--
-- ROW_NUMBER gives each repeated request ID a number:
--   1 = first record to keep
--   2, 3, and so on = duplicate records to remove
--
-- The newest record is kept when duplicates exist.
-- This prevents duplicate rows from increasing the KPI values.

DROP TABLE IF EXISTS numbered_stage;

CREATE TABLE numbered_stage AS
SELECT
    cleaned_stage.*,
    ROW_NUMBER() OVER (
        PARTITION BY request_id
        ORDER BY created_date DESC
    ) AS duplicate_number
FROM cleaned_stage;


-- STEP 5: Create the final clean table

-- Only duplicate_number = 1 is kept.
-- The helper column duplicate_number is not included in the final data.
--
-- Two new analysis fields are also created:
--   response_hours: time from creation to closing, in hours
--   closed_same_day: 1 when opened and closed on the same date

CREATE TABLE clean_data AS
SELECT
    request_id,
    created_date,
    closed_date,
    agency_code,
    agency_name,
    complaint_type,
    descriptor,
    location_type,
    incident_zip,
    city,
    status,
    borough,
    community_board,
    channel,
    latitude,
    longitude,

    -- Difference between the two dates, converted from days to hours.
    -- Open requests have no closed_date, so their result is NULL.
    ROUND(
        (julianday(closed_date) - julianday(created_date)) * 24.0,
        2
    ) AS response_hours,

    -- 1 means closed on the same date.
    -- 0 means it was closed later or is still open.
    CASE
        WHEN closed_date IS NOT NULL
         AND created_date = closed_date
        THEN 1
        ELSE 0
    END AS closed_same_day

FROM numbered_stage
WHERE duplicate_number = 1;


-- STEP 6: Create helpful indexes

-- Indexes make common searches and filters faster.
-- They do not change the data.

CREATE INDEX idx_clean_data_created_date
    ON clean_data(created_date);

CREATE INDEX idx_clean_data_complaint_type
    ON clean_data(complaint_type);

CREATE INDEX idx_clean_data_borough
    ON clean_data(borough);


-- STEP 7: Check the cleaning result

-- These queries are validation checks. They do not modify the data.

-- Check the number of rows in the clean table.
SELECT COUNT(*) AS clean_row_count
FROM clean_data;

-- This should return 0.
-- It confirms that every clean row has a request ID.
SELECT COUNT(*) AS missing_request_ids
FROM clean_data
WHERE request_id IS NULL;

-- This should return 0.
-- It confirms that request IDs are unique in the clean table.
SELECT COUNT(*) AS duplicate_request_ids
FROM (
    SELECT request_id
    FROM clean_data
    GROUP BY request_id
    HAVING COUNT(*) > 1
);

-- Preview the first ten clean records.
SELECT *
FROM clean_data
LIMIT 10;


-- CLEANING SUMMARY
-- The raw data is kept in raw_311.
-- The cleaned data is stored in clean_data.
--
-- The script:
-- 1. Standardizes text and missing values.
-- 2. Converts dates into a consistent format.
-- 3. Checks ZIP codes and coordinates.
-- 4. Removes rows without a request ID or creation date.
-- 5. Removes duplicate request IDs.
-- 6. Calculates response_hours and closed_same_day.
-- 7. Checks the final result with validation queries.
