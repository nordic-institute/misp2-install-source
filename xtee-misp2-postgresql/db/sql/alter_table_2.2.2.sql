-- Add used protocol to producer table
DO $$
    BEGIN
        RAISE NOTICE '--- Running alter-script v 2.2.2: REST support ---';

        RAISE NOTICE 'Removing default value of producer table protocol column.';
        ALTER TABLE <misp2_schema>.producer
            ALTER COLUMN protocol DROP DEFAULT;


        RAISE NOTICE 'Changing producer table protocol values from WSDL&NONE&ALL to SOAP and OPENAPI to REST.';
        UPDATE <misp2_schema>.producer
        SET protocol = 'SOAP'
        WHERE protocol in ('WSDL', 'NONE', 'ALL');

        UPDATE <misp2_schema>.producer
        SET protocol = 'REST'
        WHERE protocol = 'OPENAPI';


        RAISE NOTICE 'Adding column openapi_service_code to query table';
        ALTER TABLE <misp2_schema>.query
            ADD COLUMN openapi_service_code varchar(256);
        COMMENT ON COLUMN <misp2_schema>.query.openapi_service_code
            IS 'Teenuse nimi, mis on vajalik xroad rest teenuste kasutamiseks.';


        RAISE NOTICE 'Changing producer unique constraint to contain protocol';
        DROP INDEX IF EXISTS <misp2_schema>.in_producer_portal_id_name;
        CREATE UNIQUE INDEX in_producer_portal_id_name_protocol
            on <misp2_schema>.producer (portal_id, short_name, xroad_instance, member_class, subsystem_code, protocol);

        RAISE NOTICE 'Changing query unique constraint to contain openapi_service_code';
        DROP INDEX IF EXISTS <misp2_schema>.in_query;
        CREATE UNIQUE INDEX in_query_partial_producer_name
            ON <misp2_schema>.query (producer_id, name)
            WHERE openapi_service_code IS NULL;

        CREATE UNIQUE INDEX in_query_partial_producer_name_service_code
            on <misp2_schema>.query (producer_id, name, openapi_service_code)
            WHERE openapi_service_code IS NOT NULL;

        RAISE NOTICE '--- Alter-script v 2.2.2 finished successfully ---';
END $$;
