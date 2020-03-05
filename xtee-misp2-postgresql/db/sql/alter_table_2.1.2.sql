-- misp2.query_log table
ALTER TABLE misp2.query_log ALTER COLUMN query_size TYPE numeric(12, 3);
ALTER TABLE misp2.portal DROP COLUMN synapse_logging;
