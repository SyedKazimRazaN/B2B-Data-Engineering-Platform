/*
===============================================================================
WAREHOUSE PARTITIONS
===============================================================================

Creates monthly partitions for all warehouse fact tables.

Partition key:
    date_key = YYYYMMDD

Coverage:
    August 2024 through August 2026

Why 2026-09-01?
    The upper boundary is exclusive, so:
        FROM 20260801 TO 20260901
    covers the entire August 2026 partition.

===============================================================================
*/

DO $$
DECLARE

    -- First day of the current month being created
    month_start DATE;

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

    -- Start with August 2024
    month_start := DATE '2024-08-01';


    /*
    ---------------------------------------------------------------------------
    Outer loop:
        Move through the months one at a time.
    ---------------------------------------------------------------------------
    */
    WHILE month_start < DATE '2026-09-01' LOOP
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



