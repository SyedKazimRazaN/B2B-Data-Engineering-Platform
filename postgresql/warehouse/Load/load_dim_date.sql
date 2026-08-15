INSERT INTO warehouse.dim_date (
    date_key,
    full_date,
    day_of_month,
    day_of_week,
    day_name,
    week_of_year,
    month_num,
    month_name,
    quarter,
    year,
    is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT, -- converting full date to integer for key
    d::DATE, -- full date
    EXTRACT(DAY FROM d)::INT, -- extracting day no. of month from date
    EXTRACT(ISODOW FROM d)::INT, -- extracting day no. of week from date
    TO_CHAR(d, 'FMDay'), -- extracting and typecasting date into day name
    EXTRACT(WEEK FROM d)::INT, -- extracting week no. of current year from date
    EXTRACT(MONTH FROM d)::INT, -- extracting month no. from date
    TO_CHAR(d, 'FMMonth'),  -- extracting and typecasting month name from date
    EXTRACT(QUARTER FROM d)::INT,-- extracting quarter no. of current year
    EXTRACT(YEAR FROM d)::INT,-- extraxting year from date
    EXTRACT(ISODOW FROM d)::INT IN (6, 7) -- checking if current date is weekend (6th or 7th) day of week or not
FROM generate_series(
    DATE '2024-08-01',
    DATE '2026-08-31',
    INTERVAL '1 day'
) AS d
ON CONFLICT (date_key) DO NOTHING;
























