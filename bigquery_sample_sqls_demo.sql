--Drop & Create table
drop table users_test;

CREATE TABLE users_test (
    user_id STRING,
    first_name STRING,
    last_name STRING,
    contact_info STRUCT<email STRING, phone STRING>,
    addresses ARRAY<STRUCT<status STRING, street STRING, city STRING, zip_code STRING>>
);

--Insert data
INSERT INTO users_test (user_id, first_name, last_name, contact_info, addresses)
VALUES (
    'u1001',
    'John',
    'Doe',
    STRUCT('john.doe@example.com', '555-1234'),
    [STRUCT('primary', '123 Main St', 'Anytown', '12345'),
     STRUCT('secondary', '456 Oak Ave', 'Otherville', '67890')]
);

--Table Query
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
