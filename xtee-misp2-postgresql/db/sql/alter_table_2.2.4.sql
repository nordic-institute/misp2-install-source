-- Add unique index in_uq_query_producer_id_name
DO $$
    DECLARE
        count_deleted INTEGER;
    BEGIN
        RAISE NOTICE '--- Running alter-script v 2.2.4: add unique constraint on query producer_id and name ---';
        RAISE NOTICE 'Deleting non-unique entries.';
        WITH deleted_rows AS (
            DELETE FROM <misp2_schema>.query WHERE id IN (
                SELECT q2.id FROM <misp2_schema>.query q1
                    INNER JOIN <misp2_schema>.query q2 ON
                        q1.id < q2.id AND
                        q1.producer_id = q2.producer_id AND
                        q1.name = q2.name
                ) RETURNING *
	) SELECT count(*) FROM deleted_rows INTO count_deleted;
        RAISE NOTICE 'Deleted % non-unique entries.', count_deleted;
        RAISE NOTICE 'Adding unique index "in_uq_query_producer_id_name".';
        CREATE UNIQUE INDEX IF NOT EXISTS in_uq_query_producer_id_name ON <misp2_schema>.query (producer_id, name);
        RAISE NOTICE '--- Alter-script v 2.2.4 finished successfully ---';
END $$;
