# NYC 311 Data Cleaning and Operations Dashboard

## 1. Project overview

This repository demonstrates a complete data-cleaning and dashboard project using public NYC 311 service-request data.

The project starts with an original raw dataset. The raw dataset is preserved without overwriting it. SQL is then used to clean, standardize, validate, and prepare a second dataset for analysis. The cleaned data is used to define operational KPIs and create a dashboard showing demand, complaint types, request status, response time, and borough activity.

The project follows this workflow:

```text
Official NYC Open Data source
            ↓
Raw uncleaned data
            ↓
SQL cleaning and transformation
            ↓
Clean analysis-ready data
            ↓
KPI calculations
            ↓
Dashboard charts and PNG output
```

The data-cleaning stage of this project was performed using **SQL only**. The SQL queries are included in this repository and are commented for an intermediate reader.

## 2. Data source

The source is the official NYC Open Data dataset:

**311 Service Requests from 2020 to Present**

Source page: <https://data.cityofnewyork.us/Social-Services/311-Service-Requests-from-2020-to-Present/erm2-nwe9>

The project uses a recent sample of 20,000 service-request records from the official public dataset. The source contains requests submitted by the public and routed to city agencies for action.

The original source includes information such as unique request IDs, creation and closing dates, agency and agency name, complaint type and descriptor, location type, ZIP code and city, borough and community board, request status, submission channel, latitude and longitude, address and intersection information, resolution information, and district and precinct information.

## 3. Repository structure

```text
nyc-311-data-cleaning-dashboard/
│
├── raw_data.xlsx
├── clean_data.xlsx
├── cleaning_queries.sql
├── nyc_311_dashboard.png
└── README.md
```

| File | Purpose |
|---|---|
| `raw_data.xlsx` | The original uncleaned dataset. |
| `clean_data.xlsx` | The cleaned and analysis-ready dataset. |
| `cleaning_queries.sql` | All SQL queries used to clean, transform, and validate the data. |
| `nyc_311_dashboard.png` | The final dashboard generated from the cleaned data. |
| `README.md` | Complete project documentation. |

## 4. Why the raw and clean files do not have identical columns

The raw and clean files are related, but they do not need to contain the same number of columns.

The raw file contains the original source schema with 44 columns. It includes every field supplied by the data source, including fields that were not necessary for the selected dashboard analysis.

The clean file contains 18 selected and transformed columns. It is narrower because it focuses on the fields needed for the project’s KPIs and charts.

The clean file also contains new fields that did not exist in the raw source. These fields were calculated during SQL cleaning.

This process is called **column selection and schema reduction**. It makes the final dataset easier to understand and analyze.

## 5. Relationship between raw and clean columns

The most important relationship between the two files is the request identifier:

```text
raw_data.xlsx:  unique_key
clean_data.xlsx: request_id
```

The clean file renames `unique_key` to `request_id` because the name is clearer for analysis.

| Raw data column | Clean data column | Transformation |
|---|---|---|
| `unique_key` | `request_id` | Renamed, trimmed, and checked for missing values. |
| `created_date` | `created_date` | Converted from date-time text to a date. |
| `closed_date` | `closed_date` | Converted from date-time text to a date. |
| `agency` | `agency_code` | Renamed and converted to uppercase. |
| `agency_name` | `agency_name` | Trimmed. |
| `complaint_type` | `complaint_type` | Trimmed and preserved for grouping. |
| `descriptor` | `descriptor` | Trimmed. |
| `location_type` | `location_type` | Trimmed. |
| `incident_zip` | `incident_zip` | Validated and converted to a number when valid. |
| `city` | `city` | Trimmed and converted to uppercase. |
| `status` | `status` | Trimmed and converted to uppercase. |
| `borough` | `borough` | Trimmed and converted to uppercase. |
| `community_board` | `community_board` | Trimmed. |
| `open_data_channel_type` | `channel` | Renamed and trimmed. |
| `latitude` | `latitude` | Validated and converted to a numeric value. |
| `longitude` | `longitude` | Validated and converted to a numeric value. |
| No direct raw column | `response_hours` | New field calculated from creation and closing dates. |
| No direct raw column | `closed_same_day` | New field showing whether a request closed on its creation date. |

## 6. Raw columns not included in the clean file

The raw source includes additional columns such as `descriptor_2`, `incident_address`, `street_name`, `cross_street_1`, `cross_street_2`, `intersection_street_1`, `intersection_street_2`, `landmark`, `facility_type`, `due_date`, `resolution_description`, `council_district`, `police_precinct`, `bbl`, `vehicle_type`, `park_facility_name`, and `location`.

These columns were not included in the clean output because they were not required for the selected analysis. They may still be useful for another project, but they were outside the scope of this dashboard. The raw file remains available if a future analysis needs one of these fields.

## 7. Why values look different after cleaning

Cleaning can change how values are represented without changing what the record means.

### Standardized text

Raw value:

```text
agency = "nypd"
```

Clean value:

```text
agency_code = "NYPD"
```

The value was converted to uppercase so that filters and groupings would be consistent.

### Parsed date

Raw value:

```text
created_date = "2026-09-12T02:06:02.000"
```

Clean value:

```text
created_date = "2026-09-12"
```

The time portion was removed because this dashboard analyzes daily request volume rather than hourly request volume.

### Blank values

Raw value:

```text
borough = ""
```

Clean value:

```text
borough = NULL
```

`NULL` clearly means that the value is missing. An empty string can be confused with a real category.

### New calculated field

The raw file does not contain `response_hours`. The clean file calculates it using the difference between the closing date and creation date:

```sql
ROUND(
    (julianday(closed_date) - julianday(created_date)) * 24.0,
    2
) AS response_hours
```

## 8. SQL cleaning process

The file `cleaning_queries.sql` contains the complete cleaning pipeline.

### Step 1: Load the raw table

The original source is loaded into a table called `raw_311`. This table is kept unchanged. The SQL script expects the original source column names to be available, including `unique_key`, `created_date`, `closed_date`, `agency`, `complaint_type`, `incident_zip`, `city`, `status`, `borough`, `latitude`, and `longitude`.

### Step 2: Remove spaces and standardize missing values

The SQL function `TRIM()` removes spaces before and after text. The expression below changes blank values into `NULL`:

```sql
NULLIF(TRIM(unique_key), '') AS request_id
```

This removes extra spaces, returns `NULL` when the result is empty, and otherwise keeps the cleaned value.

### Step 3: Standardize category labels

The SQL function `UPPER()` converts category values to uppercase:

```sql
UPPER(NULLIF(TRIM(status), '')) AS status
```

This helps prevent values such as `closed`, `Closed`, and `CLOSED` from being treated as separate categories.

### Step 4: Parse dates

The source provides date-time values as text. The SQL expression keeps the first ten characters, which represent the date:

```sql
date(substr(NULLIF(TRIM(created_date), ''), 1, 10)) AS created_date
```

### Step 5: Validate ZIP codes

The SQL checks whether a ZIP-code value contains exactly five digits. Valid ZIP codes become numbers. Invalid values become `NULL` instead of remaining as unreliable text.

### Step 6: Validate coordinates

Latitude and longitude values are converted to numeric values only when they look like valid numbers. Invalid or blank coordinate values become `NULL`.

### Step 7: Remove unusable records

A request must have a request ID and a creation date to be useful for this analysis:

```sql
WHERE request_id IS NOT NULL
  AND created_date IS NOT NULL
```

Rows without those essential fields are excluded from the clean table.

### Step 8: Identify duplicate requests

The SQL window function `ROW_NUMBER()` assigns a number to each record within the same request ID:

```sql
ROW_NUMBER() OVER (
    PARTITION BY request_id
    ORDER BY created_date DESC
) AS duplicate_number
```

The final query keeps only `duplicate_number = 1`, which keeps one record per request and prevents duplicates from inflating the KPIs.

### Step 9: Calculate response time

SQLite’s `julianday()` function calculates the difference between creation and closure. The difference is multiplied by 24 to convert days into hours. If a request is still open, `closed_date` is `NULL`, so `response_hours` also remains `NULL`.

### Step 10: Calculate same-day closure

The SQL creates `closed_same_day = 1` when a request was created and closed on the same date. Otherwise, it returns `0`.

### Step 11: Validate the clean table

The SQL file includes checks for the cleaned row count, null request IDs, duplicate request IDs, and a preview of cleaned rows.

| Validation check | Result |
|---|---:|
| Raw rows | 20,000 |
| Clean rows | 20,000 |
| Null request IDs after cleaning | 0 |
| Duplicate request IDs after cleaning | 0 |

The clean file has the same number of rows as the raw file because this sample did not contain records that needed to be removed after validation. The clean file has fewer columns because only analysis-relevant fields were selected.

## 9. Why open requests remain in the clean data

Open requests are not deleted. They represent current workload and are needed for status analysis. However, open requests cannot be assigned a final response time because they do not have a closing date.

Therefore, open requests remain in the clean dataset, appear in the status chart, and are excluded from average response-time calculations.

## 10. KPIs selected before dashboard creation

The dashboard was planned around five KPIs:

| KPI | Definition | Result |
|---|---|---:|
| Total requests | Number of records in the clean dataset. | 20,000 |
| Closure rate | Closed requests divided by all clean requests. | 53.7% |
| Average response time | Average hours between creation and closure for valid closed requests. | 3.9 hours |
| Same-day closure rate | Same-day closures divided by all closed requests. | 83.6% |
| Top complaint share | Most common complaint count divided by all clean requests. | 17.1% |

These KPIs were defined before the dashboard charts were selected. This kept the dashboard focused on operational questions instead of adding charts without a clear purpose.

## 11. Dashboard charts

The dashboard contains five charts:

1. **Top Complaint Types** ranks the most frequent complaint categories. A horizontal bar chart was selected because complaint names can be long.
2. **Requests by Response Time** groups requests by response-time bands, including fast closures, multi-day closures, and requests not yet closed.
3. **Requests by Borough** shows the geographic composition of the request sample.
4. **Requests by Status** shows the workflow state of requests, including closed, in progress, open, and assigned.
5. **Daily Request Volume** shows how the number of created requests changed during the sample period.

## 12. Dashboard design

The dashboard uses a light visual style with a white background, deep navy text, teal primary charts, sage green supporting accents, warm gold and coral comparison colors, pale mint borders and gridlines, KPI cards across the top, three charts in the first row, and two larger charts in the second row.

The dashboard has no dark background panels and no unnecessary footer section. The visual hierarchy is designed to make the data easy to scan.

## 13. Important interpretation note

This project uses a recent 20,000-record snapshot. It does not represent the complete historical NYC 311 dataset. The results should be interpreted as a recent operational snapshot rather than a permanent citywide performance benchmark.

The average response-time KPI applies only to requests with a closing date. The status analysis includes open requests because they are important for understanding active workload.

## 14. Final project summary

The raw file shows the original source structure. The clean file shows a narrower and more consistent analytical structure. The SQL file explains every transformation between them. The dashboard presents the main results in a visual format.

The central principle is:

> The raw data is preserved for transparency, the SQL file documents the transformation, the clean data supports analysis, and the dashboard communicates the results.

