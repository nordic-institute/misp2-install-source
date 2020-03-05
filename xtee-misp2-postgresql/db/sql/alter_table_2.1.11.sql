-- Add support for multiple X-Road instances per portal
DO $$ 
BEGIN
  	RAISE NOTICE '--- Running alter-script v 2.1.11: Support for multiple X-Road instances ---';
	-- portal.xroad_instance is going to be interpreted as _Client_ instance from now on.
	-- Service instances are added to a separate table and added to each X-Road v6 producer.
  	RAISE NOTICE 'Renaming table ''portal'' column ''xroad_instance'' to ''client_xroad_instance''.';
	ALTER TABLE <misp2_schema>.portal RENAME COLUMN xroad_instance TO client_xroad_instance;
	COMMENT ON COLUMN <misp2_schema>.portal.client_xroad_instance
		IS 'X-Tee v6 kliendi instants'
	;
	
	-- Create table of portal xroad-instances. Each portal could have many instances.
	-- Producer list and services can be reloaded for each X-Road instance that has
	-- xroad_instance.in_use = TRUE. Admin can pick which instances are in use from
	-- all the xroad_instance entries for given portal.
  	RAISE NOTICE 'Creating table ''xroad_instance''.';
	CREATE TABLE <misp2_schema>.xroad_instance (
		id serial,
		portal_id INTEGER NOT NULL,
		code VARCHAR(64) NOT NULL,
		in_use BOOLEAN,
		selected BOOLEAN,
		created TIMESTAMP NOT NULL DEFAULT current_timestamp,
		last_modified TIMESTAMP NOT NULL DEFAULT current_timestamp,
  		username varchar(20) NOT NULL DEFAULT 'admin'
	);
	-- Add primary key constraint
	ALTER TABLE <misp2_schema>.xroad_instance ADD CONSTRAINT 
		xroad_instance_pk PRIMARY KEY(id);
	
	-- Add foreign key contstraint
	ALTER TABLE <misp2_schema>.xroad_instance ADD CONSTRAINT 
		fk_xroad_instance_portal FOREIGN KEY (portal_id) REFERENCES 
		<misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
	CREATE INDEX in_xroad_instance_portal ON <misp2_schema>.xroad_instance (portal_id);

	-- Unique constraint for portal and code: there can be one entry with given code per portal
  	RAISE NOTICE 'Creating unique index ''in_xroad_instance_code'' to ''xroad_instance'' table.';
	CREATE UNIQUE INDEX in_xroad_instance_code ON <misp2_schema>.xroad_instance (portal_id, code);

  	RAISE NOTICE 'Granting access permissions for ''xroad_instance'' table.';
	GRANT ALL ON <misp2_schema>.xroad_instance TO <misp2_schema>;
	GRANT ALL ON <misp2_schema>.xroad_instance_id_seq TO <misp2_schema>;
	
  	RAISE NOTICE 'Inserting comments for ''xroad_instance'' table.';
	COMMENT ON TABLE <misp2_schema>.xroad_instance
	    IS 'Tabel sisaldab portaali teenuste X-Tee instantse.
		Veerg ''in_use'' määrab, millised instantsid on portaalis parasjagu kasutusel.
		Kasutusel olevatest instantside jaoks on teenuste halduril võimalik värskendada
		teenuste nimekirja ja hallata vastavate andmekogude teenuseid.'
	;
	COMMENT ON COLUMN <misp2_schema>.xroad_instance.id
	    IS 'tabeli primaarvõti'
	;
	COMMENT ON COLUMN <misp2_schema>.xroad_instance.portal_id
	    IS 'viide portaalile ''portal'' tabelis, millega käesolev X-Tee instants seotud on'
	;
	COMMENT ON COLUMN <misp2_schema>.xroad_instance.code
	    IS 'X-Tee instantsi väärtus, mis X-Tee sõnumite päiseväljadele kirjutatakse'
	;
	COMMENT ON COLUMN <misp2_schema>.xroad_instance.in_use
	    IS 'tõene, kui käesolev X-Tee instants on portaalis aktiivne, st selle teenuseid saab laadida;
	    väär, kui käesolev X-Tee instants ei ole portaalis kasutusel'
	;
	COMMENT ON COLUMN <misp2_schema>.xroad_instance.selected
	    IS 'tõene, kui käesolev X-Tee instants on portaalis andmekogude päringul vaikimisi valitud;
	    väär, kui käesolev X-Tee instants ei ole vaikimisi valitud'
	;
	COMMENT ON COLUMN <misp2_schema>.xroad_instance.created
	    IS 'sissekande loomisaeg'
	;
	COMMENT ON COLUMN <misp2_schema>.xroad_instance.last_modified
	    IS 'sissekande viimase muutmise aeg'
	;
	
	-- Populate the newly created xroad_instance table with portal client xroad-instances.
	-- Previously the same instance was used for both - client and service.
  	RAISE NOTICE 'Populating table ''xroad_instance'' with data from ''portal.client_xroad_instance''.';
	INSERT INTO <misp2_schema>.xroad_instance (portal_id, code, in_use, selected) SELECT
		id, client_xroad_instance, TRUE, TRUE FROM <misp2_schema>.portal WHERE 
		client_xroad_instance IS NOT NULL AND client_xroad_instance != '';
	
	-- Add X-Road instance for producer. The column contains X-Road instance value as text 
	-- instead of reference to xroad_instance table row, to preserve producer configuration
	-- after xroad_instance table entries have been deleted or altered.
  	RAISE NOTICE 'Adding new column ''xroad_instance'' to ''producer'' table.';
	ALTER TABLE <misp2_schema>.producer ADD COLUMN xroad_instance VARCHAR(64) NULL;
	
  	RAISE NOTICE 'Redefining ''producer'' table unique index.';
	-- Drop uniqueness constraint from producer table if it exists
	ALTER TABLE <misp2_schema>.producer DROP CONSTRAINT IF EXISTS uniq_portal_id_short_name;
	-- Add unique index to producer table similar to dropped constraint, but also using new xroad_instance field
	CREATE UNIQUE INDEX in_producer_portal_id_name ON 
		<misp2_schema>.producer (portal_id, short_name, xroad_instance, member_class, subsystem_code);

	-- Copy X-Road instances from portal client configuration
  	RAISE NOTICE 'Populating ''producer.xroad_instance'' column with data from ''portal.client_xroad_instance''.';
	UPDATE <misp2_schema>.producer SET xroad_instance=portal.client_xroad_instance FROM
		<misp2_schema>.portal WHERE producer.portal_id = portal.id;
  	RAISE NOTICE '--- Alter-script finished successfully ---';
	
END $$;