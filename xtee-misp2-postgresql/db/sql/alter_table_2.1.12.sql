-- Remove undesirable string-length constraints in query_error_log 
-- by replacing varchar(x) type with text
ALTER TABLE <misp2_schema>.query_error_log ALTER COLUMN description TYPE text;
ALTER TABLE <misp2_schema>.query_name ALTER COLUMN query_note TYPE text;
