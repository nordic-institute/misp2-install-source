-- remove all x-road v6 producers that are not in use and are actually x-road clients, not producers
DELETE FROM misp2.producer WHERE in_use = FALSE AND member_class IS NOT NULL AND 
	(subsystem_code = 'generic-consumer' OR subsystem_code IS null);

-- change all x-road v4 portals to x-road v5 (v5 now also supports v4 queries)
UPDATE misp2.portal SET xroad_protocol_ver = '3.1' WHERE xroad_protocol_ver = '2.0';

-- update member code of all x-road v6 units where member code is null to 'COM'
UPDATE misp2.org SET member_class = 'COM' WHERE id IN
	(SELECT org_unit.id FROM misp2.org AS org_unit 
		JOIN misp2.org AS org_sup ON org_sup.id = org_unit.sup_org_id 
		JOIN misp2.portal ON portal.org_id = org_sup.id
		WHERE org_unit.sup_org_id IS NOT NULL AND portal.xroad_protocol_ver = '4.0' AND org_unit.member_class IS NULL);

-- Add new field: query.sub_query_names
-- Extract complex query subquery names from xforms.form (XML strings) and add them to query.sub_query_names.
-- sub_query_names are migrated only in x-road v5 portals, since x-road v6 portals do not exist at this point.
-- After initial migration, MISP2 application keeps the field value up to date after every time user saves xforms content.
DO $$ 
	DECLARE current_xforms_id INTEGER;
	DECLARE current_query_id INTEGER;
	DECLARE current_form TEXT;
	DECLARE current_sub_query_names TEXT;
	DECLARE current_sub_query_name TEXT;
	DECLARE current_query_name TEXT;
	DECLARE current_producer_short_name TEXT;
	DECLARE current_portal_name TEXT;
	DECLARE xrd_v6_service_path TEXT;
	DECLARE portal_xroad_protocol_ver TEXT;
	DECLARE xrd_v6_service_xml_ar XML[];
	DECLARE xml_namespace_map TEXT[][];
	DECLARE xrd_v6_service_xml_element XML; -- loop variable
BEGIN
    BEGIN
	    -- Adding field query.sub_query_names
		ALTER TABLE misp2.query ADD COLUMN sub_query_names TEXT NULL;
		COMMENT ON COLUMN misp2.query.sub_query_names
		    IS 'Kasutatakse kompleksteenuse puhul alampäringute nimistu hoidmiseks.'
		;
		-- Adding is wrapped with exception handler so that the extraction script could be executed later too if needed
    EXCEPTION
        WHEN duplicate_column THEN RAISE NOTICE 'column sub_query_names already exists in misp2.query so not adding.';
    END;
    
    xml_namespace_map := ARRAY[
		ARRAY['SOAP-ENV', 'http://schemas.xmlsoap.org/soap/envelope/'],
		ARRAY['xhtml', 'http://www.w3.org/1999/xhtml'],
		ARRAY['xforms', 'http://www.w3.org/2002/xforms'],
		ARRAY['xrd6', 'http://x-road.eu/xsd/xroad.xsd'],
		ARRAY['iden', 'http://x-road.eu/xsd/identifiers']
	];
    
    -- Migrating classifiers that were previously performing queries with x-road v5
    FOR current_xforms_id IN SELECT xforms.id FROM misp2.xforms 
      JOIN misp2.query ON xforms.query_id = query.id 
      JOIN misp2.producer ON query.producer_id = producer.id
      JOIN misp2.portal ON producer.portal_id = portal.id
      WHERE  query."type" = 2 
      ORDER BY xforms.id LOOP
      	-- Run loop
      	SELECT INTO current_query_id, current_query_name, current_producer_short_name, current_portal_name, portal_xroad_protocol_ver
      		xforms.query_id, query.name, producer.short_name, portal.short_name, portal.xroad_protocol_ver
      		FROM misp2.xforms 
      		JOIN misp2.query ON xforms.query_id = query.id 
      		JOIN misp2.producer ON query.producer_id = producer.id
      		JOIN misp2.portal ON producer.portal_id = portal.id WHERE xforms.id = current_xforms_id;
    	SELECT xforms.form FROM misp2.xforms INTO current_form WHERE xforms.id = current_xforms_id;
    	
    	IF xml_is_well_formed_document(trim(from current_form)) THEN
    		IF portal_xroad_protocol_ver = '4.0' THEN -- xroad v6
    			
    			current_sub_query_names := '';
    			current_sub_query_name := '';
    			
				xrd_v6_service_path := '/xhtml:html/xhtml:head/xforms:model/xforms:instance' || 
				    '/SOAP-ENV:Envelope/SOAP-ENV:Header/xrd6:service';
				-- query xrd6:service elements
    			SELECT xpath(xrd_v6_service_path, current_form::xml, xml_namespace_map) INTO xrd_v6_service_xml_ar;
    			
    			-- loop over each service xml-element returned by previous xpath query
    			FOREACH xrd_v6_service_xml_element IN ARRAY xrd_v6_service_xml_ar LOOP
    				-- xpath to get service name in the form of ee-dev:COM:1245678:subs-code:testService:v1
				    xrd_v6_service_path := 'concat(' ||
			    		'/xrd6:service/iden:'	|| 'xRoadInstance'	|| '/text(),' 	|| ''':'',' ||
			    		'/xrd6:service/iden:'	|| 'memberClass' 	|| '/text(),' 	|| ''':'',' ||
			    		'/xrd6:service/iden:'	|| 'memberCode' 	|| '/text(),' 	|| ''':'',' ||
			    		'/xrd6:service/iden:'	|| 'subsystemCode'	|| '/text(),' 	|| ''':'',' ||
			    		'/xrd6:service/iden:'	|| 'serviceCode' 	|| '/text(),' 	|| ''':'',' ||
			    		'/xrd6:service/iden:'	|| 'serviceVersion'	|| '/text()' 	|| 
		    		')';
		    		-- evaluate xpath for current service element and convert it to text (only one element is returned)
		    		SELECT array_to_string(xpath(xrd_v6_service_path, xrd_v6_service_xml_element::xml, xml_namespace_map), ' ') INTO current_sub_query_name;
		    		
		    		-- concat current subquery name to current_sub_query_names
		    		IF current_sub_query_names = '' THEN
						--RAISE NOTICE 'X-road v6 service (1) count: %', count;	
			    		current_sub_query_names := current_sub_query_name;
			    	ELSE
						-- RAISE NOTICE 'X-road v6 service (2) count: %', count;	
			    		current_sub_query_names := current_sub_query_names || ', ' || current_sub_query_name;
			    	END IF;
				END LOOP;
		    	
		    ELSE -- xroad v5, v4
		    	-- get all header elements with name or nimi (does not take namespaces into account)
		    	SELECT array_to_string(xpath(
		    		'/xhtml:html/xhtml:head/xforms:model/xforms:instance/SOAP-ENV:Envelope/SOAP-ENV:Header/*[local-name() = ''service'' or local-name() = ''nimi'']/text()', 
		    		current_form::xml, 
		    		xml_namespace_map), ', ') INTO current_sub_query_names;
		    END IF;
	    		
			UPDATE misp2.query  
				SET sub_query_names = current_sub_query_names 
				WHERE id = current_query_id;
			
			RAISE NOTICE 'Updated v% query [%] %.% , set subqueries to ''%'' in portal ''%''', 
				portal_xroad_protocol_ver, current_query_id, current_producer_short_name, current_query_name, current_sub_query_names, current_portal_name;
		ELSE
			RAISE NOTICE 'Not updating query [%] %.%', current_query_id, current_producer_short_name, current_query_name;
		END IF;
    END LOOP;
END $$;