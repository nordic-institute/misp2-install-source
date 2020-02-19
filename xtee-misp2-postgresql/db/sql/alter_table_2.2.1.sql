-- Add used protocol to producer table
DO $$
BEGIN
  RAISE NOTICE '--- Running alter-script v 2.2.1: REST support ---';

  RAISE NOTICE 'Adding column ''protocol'' to ''producer''.';
  RAISE NOTICE 'Setting initial value of ''WSDL'' for current producers.';
  ALTER TABLE <misp2_schema>.producer ADD COLUMN protocol varchar(16) NOT NULL DEFAULT 'WSDL';
  COMMENT ON COLUMN <misp2_schema>.producer.protocol
  IS 'Protokoll, mida produceri querid kasutavad sõnumivahetuses.';

  RAISE NOTICE '--- Alter-script v 2.2.1 finished successfully ---';
END $$;
