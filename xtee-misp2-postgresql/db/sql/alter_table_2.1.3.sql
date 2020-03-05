-- misp2.classifier table adding x-road query entries, removing query_id
DO $$ 
	DECLARE current_classifier_id INTEGER;
	DECLARE current_classifier_name VARCHAR(50);
	
	DECLARE portal_xroad_protocol_ver VARCHAR(5);
	DECLARE portal_xroad_instance VARCHAR(64);
	DECLARE producer_member_class VARCHAR(16);
	DECLARE producer_short_name VARCHAR(50);
	DECLARE producer_subsystem_code VARCHAR(64);
	DECLARE query_name VARCHAR(256);
	DECLARE query_xroad_request_namespace VARCHAR(256);
	-- the next two values are derived from query_name
	DECLARE service_code VARCHAR(256);
	DECLARE service_version VARCHAR(256);
BEGIN
    BEGIN
		ALTER TABLE misp2.classifier ADD COLUMN producer_name VARCHAR(50) NULL;
    EXCEPTION
        WHEN duplicate_column THEN RAISE NOTICE 'column producer_name already exists in misp2.classifier so not adding.';
    END;
    
    BEGIN
		ALTER TABLE misp2.classifier ALTER COLUMN producer_name DROP NOT NULL;
    EXCEPTION
        WHEN duplicate_column THEN RAISE NOTICE 'column producer_name is already nullable in misp2.classifier so not altering.';
    END;
    
    ALTER TABLE misp2.classifier ADD COLUMN xroad_query_xroad_protocol_ver VARCHAR(5) NULL;
    ALTER TABLE misp2.classifier ADD COLUMN xroad_query_xroad_instance VARCHAR(64) NULL;
    ALTER TABLE misp2.classifier ADD COLUMN xroad_query_member_class VARCHAR(16) NULL;
	ALTER TABLE misp2.classifier RENAME COLUMN producer_name TO xroad_query_member_code;
    ALTER TABLE misp2.classifier ADD COLUMN xroad_query_subsystem_code VARCHAR(64) NULL;
    
    ALTER TABLE misp2.classifier ADD COLUMN xroad_query_service_code VARCHAR(256) NULL;
    ALTER TABLE misp2.classifier ADD COLUMN xroad_query_service_version VARCHAR(256) NULL;
    ALTER TABLE misp2.classifier ADD COLUMN xroad_query_request_namespace VARCHAR(256) NULL;
    
    -- Migrating classifiers that were previously performing queries with x-road v5
    FOR current_classifier_id IN SELECT id FROM misp2.classifier 
    	WHERE xroad_query_member_code IS NOT NULL 
    		AND portal_xroad_protocol_ver IS NULL ORDER BY id LOOP
		UPDATE misp2.classifier 
			SET xroad_query_xroad_protocol_ver = '3.1' 
			WHERE id = current_classifier_id;
		
		RAISE NOTICE 'Setting classifier % query xroad protocol to 3.1 (x-road 5)...', current_classifier_id;
    END LOOP;
    
    -- Migrating classifiers from classifier.query_id
	FOR current_classifier_id IN SELECT id FROM misp2.classifier WHERE query_id IS NOT NULL ORDER BY id LOOP
		SELECT  classifier.name,
				portal.xroad_protocol_ver, 
				portal.xroad_instance, 
				producer.member_class, 
				producer.short_name, 
				producer.subsystem_code,
				query.name,
				query.xroad_request_namespace 
			INTO
				current_classifier_name,
				portal_xroad_protocol_ver, 
				portal_xroad_instance, 
				producer_member_class, 
				producer_short_name, 
				producer_subsystem_code,
				query_name,
				query_xroad_request_namespace
			FROM misp2.classifier 
				JOIN misp2.query ON classifier.query_id = query.id 
				JOIN misp2.producer ON query.producer_id = producer.id
				JOIN misp2.portal ON producer.portal_id = portal.id
			WHERE classifier.id = current_classifier_id;
	
		RAISE NOTICE 'Migrating classifier % query %...', current_classifier_name, query_name;
		service_code := split_part(query_name, '.', 1);
		service_version := split_part(query_name, '.', 2);
		UPDATE misp2.classifier SET 
				xroad_query_xroad_protocol_ver = portal_xroad_protocol_ver,
			    xroad_query_xroad_instance = portal_xroad_instance,
			    xroad_query_member_class = producer_member_class,
				xroad_query_member_code = producer_short_name,
			    xroad_query_subsystem_code = producer_subsystem_code,
			    
			    xroad_query_service_code = service_code,
			    xroad_query_service_version = service_version,
			    xroad_query_request_namespace = query_xroad_request_namespace
			WHERE id = current_classifier_id;
	END LOOP;
    
    -- end of migrating classifiers
	ALTER TABLE misp2.classifier DROP COLUMN IF EXISTS query_id;
	DROP INDEX IF EXISTS misp2.in_classifier_name_idx;
	CREATE UNIQUE INDEX in_classifier_name_idx ON misp2.classifier(name, xroad_query_member_code , xroad_query_xroad_protocol_ver , 
   		xroad_query_xroad_instance , xroad_query_member_class , xroad_query_subsystem_code , xroad_query_service_code , xroad_query_service_version);
    COMMENT ON COLUMN misp2.query.xroad_request_namespace
	    IS 'kasutatakse x-tee v6 klassifikaatorite päringul'
	;
    
END $$;

