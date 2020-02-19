-- Replace index in_uq_query_producer_id_name
DO $$
    BEGIN
        RAISE NOTICE '--- Running alter-script v 2.2.5: add openapi_service_code to query (producer_id, name) unique constraint ---';
        RAISE NOTICE 'Removing index "in_uq_query_producer_id_name".';
        DROP INDEX IF EXISTS misp2.in_uq_query_producer_id_name;
        RAISE NOTICE 'Adding unique index "in_uq_query_producer_id_name_openapi_service_code".';
        CREATE UNIQUE INDEX IF NOT EXISTS in_uq_query_producer_id_name_openapi_service_code
		ON <misp2_schema>.query (producer_id, name, COALESCE(openapi_service_code, ''));
        RAISE NOTICE '--- Alter-script v 2.2.5 finished successfully ---';
END $$;
