SELECT
    APPROX_QUANTILES(trip_distance, 100)[OFFSET(50)] AS approx_median_distance,
    APPROX_QUANTILES(trip_distance, 100)[OFFSET(95)] AS approx_95th_percentile_distance
FROM
    `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2019`
WHERE
    EXTRACT(MONTH FROM pickup_datetime) = 1;



SELECT
    EXTRACT(MONTH FROM pickup_datetime) AS trip_month,
    STDDEV_SAMP(trip_distance) AS std_dev_distance,
    COVAR_SAMP(total_amount, trip_distance) AS covariance_amount_distance
FROM
    `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2019`
WHERE
    EXTRACT(MONTH FROM pickup_datetime) IN (1, 2)
GROUP BY
    trip_month
ORDER BY
    trip_month;



SELECT
    country,
    ARRAY_AGG(
        STRUCT(year_2000 AS population_2000, year_2010 AS population_2010)
        ORDER BY year_2000 DESC
    ) AS population_details
FROM
    `bigquery-public-data.world_bank_global_population.population_by_country`
WHERE
    country IN ('China', 'India', 'United States')
GROUP BY
    country;



-- Create the reusable UDAF
CREATE OR REPLACE AGGREGATE FUNCTION project.dataset.ScaledSum(
    dividend FLOAT64,
    divisor FLOAT64 NOT AGGREGATE -- 'NOT AGGREGATE' marks the parameter as a scalar for the group
) RETURNS FLOAT64
AS (
    SUM(dividend * divisor) / SUM(divisor) -- An example calculation; can be any valid aggregate expression
);

-- Example usage with a dummy table structure
-- This query assumes a table `project.dataset.sales` with columns `Price` and `Quantity`.
SELECT
    project.dataset.ScaledSum(Price, Quantity) AS weighted_average_price
FROM
    `project.dataset.sales`;


CREATE OR REPLACE TABLE `{work_project}.{work_dataset_tmp}.train_ann_income`
AS
WITH raw AS(
  SELECT
    tgt.r_uid,
    tgt.label,
    features.* EXCEPT (
      r_uid,
      num_pt
      )
  FROM
    `{work_project}.{work_dataset_tmp}.target_ann_income` AS tgt
  INNER JOIN
    `{work_project}.{work_dataset_tmp}.features` AS features
  ON
    tgt.r_uid = features.r_uid
  WHERE
    tgt.label >= 0
    AND tgt.label <= 15
    AND tgt._PARTITIONTIME = (select max(_PARTITIONTIME) from `{work_project}.{work_dataset_tmp}.target_ann_income`)
)
SELECT
  * EXCEPT(cnt)
FROM (
  SELECT
    *
  FROM
    raw AS a
CROSS JOIN (
  SELECT
    COUNT(*) AS cnt
  FROM
    raw) AS b
)
WHERE
  MOD(ABS(FARM_FINGERPRINT(r_uid)), CAST(FLOOR(cnt / (1 * {train_sample_number})*10) AS int64))in UNNEST(GENERATE_ARRAY(0,9))
;

CREATE TABLE `r-data-1stparty.dwh_hpb.ct_reserve_survey`
(
  reserve_survey_no INT64 OPTIONS(description="NUMBER, 22, 10, 0"),
  cap_member_id STRING OPTIONS(description="VARCHAR2, 12, 0, 0"),
  system_kbn STRING OPTIONS(description="CHAR, 2, 0, 0"),
  reserve_id STRING OPTIONS(description="CHAR, 10, 0, 0"),
  answer_marriage STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_child STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger1 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger2 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger3 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger4 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger5 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger6 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger7 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger8 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger9 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger10 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger11 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger12 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger13 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger14 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger15 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger16 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_trigger17 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_most_trigger STRING OPTIONS(description="CHAR, 2, 0, 0"),
  answer_salon_reserve_cnt STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_hpb_awareness STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason1 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason2 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason3 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason4 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason5 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason6 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason7 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason8 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason9 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason10 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_reason11 STRING OPTIONS(description="CHAR, 1, 0, 0"),
  answer_reserve_most_reason STRING OPTIONS(description="CHAR, 2, 0, 0"),
  toroku_date DATETIME OPTIONS(description="DATE, 7, 0, 0"),
  toroku_module_id STRING OPTIONS(description="VARCHAR2, 10, 0, 0")
)
OPTIONS(
  description=""
);

drop table users_test;
CREATE TABLE users_test (
    user_id STRING,
    first_name STRING,
    last_name STRING,
    contact_info STRUCT<email STRING, phone STRING>,
    addresses ARRAY<STRUCT<status STRING, street STRING, city STRING, zip_code STRING>>
);


INSERT INTO mydataset.users (user_id, first_name, last_name, contact_info, addresses)
VALUES (
    'u1001',
    'John',
    'Doe',
    STRUCT('john.doe@example.com', '555-1234'),
    [STRUCT('primary', '123 Main St', 'Anytown', '12345'),
     STRUCT('secondary', '456 Oak Ave', 'Otherville', '67890')]
);

SELECT
    t1.first_name,
    t1.contact_info.email,
    -- UNNEST the addresses array to query individual addresses
    address.city AS city
FROM
    users_test AS t1,
    UNNEST(t1.addresses) AS address
WHERE
    address.status = 'primary';
