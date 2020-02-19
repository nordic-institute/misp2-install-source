-- Set query.name NOT NULL 
DO $$
    BEGIN
        RAISE NOTICE '--- Running alter-script v 2.2.3: add query.name NOT NULL constraint ---';

        RAISE NOTICE 'Removing nameless queries.';
        DELETE FROM <misp2_schema>.query WHERE name IS NULL;

        RAISE NOTICE 'Adding the constraint';
        ALTER TABLE <misp2_schema>.query ALTER COLUMN name SET NOT NULL;

        RAISE NOTICE 'Adding comment on column';
        COMMENT ON COLUMN <misp2_schema>.query.name
            IS 'Teenuse lühinimi, X-tee v6 korral serviceCode ja serviceVersion punktiga eraldatuna. REST teenuste puhul operationId.'
        ;
        RAISE NOTICE '--- Alter-script v 2.2.3 finished successfully ---';
END $$;
