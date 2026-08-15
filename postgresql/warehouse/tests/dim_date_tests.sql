

--check for duplicate dates:
SELECT full_date, COUNT(*)
FROM warehouse.dim_date
GROUP BY full_date
HAVING COUNT(*) > 1;



-- check that every date is present
SELECT
    MIN(full_date) AS min_date,
    MAX(full_date) AS max_date,
    COUNT(DISTINCT full_date) AS distinct_dates,
    COUNT(*) AS total_rows
FROM warehouse.dim_date;
