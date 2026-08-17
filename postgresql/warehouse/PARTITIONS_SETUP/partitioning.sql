/*
===============================================================================
WAREHOUSE PARTITIONS
===============================================================================

Creates monthly partitions for all warehouse fact tables.

Partition key:
    date_key = YYYYMMDD

Coverage:
    Rolling window: 2 years back through 6 months ahead of CURRENT_DATE,
    computed dynamically each run so partitions never age out of range
    (matches the same rolling window config.py uses for data generation).

===============================================================================
*/

DO $$
DECLARE

    -- First day of the current month being created
    month_start DATE;

    -- First day of the month after the last month we want covered
    range_end DATE;

    -- Name of the partition we are going to create
    table_name TEXT;

    -- Name of the parent fact table
    parent_table TEXT;

    -- All fact tables that need monthly partitions
    parent_tables TEXT[] := ARRAY[
        'fact_orders',
        'fact_order_items',
        'fact_web_logs',
        'fact_leads'
    ];

BEGIN

    -- First day of the month, 2 years back from today
    month_start := date_trunc('month', CURRENT_DATE - INTERVAL '2 years')::DATE;

    -- First day of the month after the month 6 months ahead of today
    range_end := (date_trunc('month', CURRENT_DATE + INTERVAL '6 months') + INTERVAL '1 month')::DATE;


    /*
    ---------------------------------------------------------------------------
    Outer loop:
        Move through the months one at a time.
    ---------------------------------------------------------------------------
    */
    WHILE month_start < range_end LOOP
        /*
        -----------------------------------------------------------------------
        Inner loop:
            For each month, create a partition for each fact table.
        -----------------------------------------------------------------------
        */
        FOREACH parent_table IN ARRAY parent_tables LOOP

            table_name :=
                parent_table || '_' || TO_CHAR(month_start, 'YYYY_MM');


            /*
            -------------------------------------------------------------------
            this will generate:
			
            CREATE TABLE warehouse.fact_orders_2024_08
            PARTITION OF warehouse.fact_orders
            FOR VALUES FROM (20240801) TO (20240901);
			
            %I = SQL identifier (table name)
            %s = value/string
            -------------------------------------------------------------------
            */
            EXECUTE format(
                'CREATE TABLE IF NOT EXISTS warehouse.%I
                 PARTITION OF warehouse.%I
                 FOR VALUES FROM (%s) TO (%s)',
                table_name,
                parent_table,
                TO_CHAR(month_start, 'YYYYMMDD'), -- (start) Partition starting boundary
                TO_CHAR(month_start + INTERVAL '1 month','YYYYMMDD')-- (end) Partition ending boundary
            );
        END LOOP;

        -- Move to the next month
        month_start := (month_start + INTERVAL '1 month')::DATE;

    END LOOP;

END $$;



