-- Add EULA tables and alter respective fields
DO $$ 
BEGIN
    RAISE NOTICE '--- Running alter-script v 2.1.13: EULA support ---';
    
    -- Add 'eula_in_use' column to table 'portal'
    RAISE NOTICE 'Adding table ''portal'' column ''eula_in_use''.';
    ALTER TABLE <misp2_schema>.portal ADD COLUMN eula_in_use boolean default false;
    COMMENT ON COLUMN <misp2_schema>.portal.eula_in_use
        IS 'tõene, kui portaalis on EULA kasutusel ja kasutajatelt küsitakse sellega nõustumist'
    ;

    -- Create end user license agreement content table.
    -- Each portal could have EULA content in multiple languages, represented by rows of this table).
    RAISE NOTICE 'Creating table ''portal_eula''.';
    CREATE TABLE <misp2_schema>.portal_eula (
        id serial,
        portal_id INTEGER NOT NULL,
        lang VARCHAR(2) NOT NULL,
        content text NOT NULL, -- *.MD file format
        created TIMESTAMP NOT NULL DEFAULT current_timestamp,
        last_modified TIMESTAMP NOT NULL DEFAULT current_timestamp,
        username VARCHAR(20) NOT NULL DEFAULT 'admin'
    );
    
    -- Add primary key constraint
    RAISE NOTICE 'Adding primary key constraint to ''portal_eula'' table.';
    ALTER TABLE <misp2_schema>.portal_eula ADD CONSTRAINT 
        portal_eula_pk PRIMARY KEY(id);
    
    -- Add foreign key contstraint
    RAISE NOTICE 'Adding foreign key constraint to ''portal_eula'' table.';
    ALTER TABLE <misp2_schema>.portal_eula ADD CONSTRAINT 
        fk_portal_eula_portal FOREIGN KEY (portal_id) REFERENCES 
        <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
    -- Index in_uq_eula_portal_id_lang applies to foreign key fk_portal_eula_portal   
    -- Add unique index for portal ID and language code so that each portal would have EULA content entries in unique languages
    RAISE NOTICE 'Adding unique index to ''portal_eula'' table.';
    CREATE UNIQUE INDEX in_uq_eula_portal_id_lang ON <misp2_schema>.portal_eula (portal_id, lang);

    -- Table and sequence access permission grants
    RAISE NOTICE 'Granting access permissions for ''portal_eula'' table.';
    GRANT ALL ON <misp2_schema>.portal_eula TO <misp2_schema>;
    GRANT ALL ON <misp2_schema>.portal_eula_id_seq TO <misp2_schema>;
    
    RAISE NOTICE 'Inserting comments for ''portal_eula'' table.';
    COMMENT ON TABLE <misp2_schema>.portal_eula
        IS 'Tabel sisaldab kasutajalitsentside tekste,
            mis kasutajale esimesel portaali sisselogimisel kuvatakse.
            Ühel portaalil saab olla mitu kasutajalitsensi teksti,
            sellisel juhul iga kanne sisaldab sama litsensi teksti erinevas keeles.
            Tabelisse tehakse kirjeid rakenduse administraatori rollis
            portaali loomise/muutmise vormilt administreerimisliideses.
            Tabeli kirjeid loetakse kasutaja esmasel sisenemisel portaali, et
            kasutajale litsensi sisu nõustumiseks kuvada.'
    ;
    COMMENT ON COLUMN <misp2_schema>.portal_eula.id
        IS 'tabeli primaarvõti'
    ;
    COMMENT ON COLUMN <misp2_schema>.portal_eula.portal_id
        IS 'viide portaalile ''portal'' tabelis, millega käesolev EULA sisu seotud on'
    ;
    COMMENT ON COLUMN <misp2_schema>.portal_eula.lang
        IS 'EULA sisu kahetäheline keelekood'
    ;
    COMMENT ON COLUMN <misp2_schema>.portal_eula.content
        IS 'EULA sisu tekst MD formaadis'
    ;
    COMMENT ON COLUMN <misp2_schema>.portal_eula.created
        IS 'sissekande loomisaeg'
    ;
    COMMENT ON COLUMN <misp2_schema>.portal_eula.last_modified
        IS 'sissekande viimase muutmise aeg'
    ;
    COMMENT ON COLUMN <misp2_schema>.portal_eula.username
        IS 'sissekande looja kasutajanimi'
    ;


    -- Create table that stores associations between user and user's license agreements acceptions and rejections
    RAISE NOTICE 'Creating table ''person_eula''.';
    CREATE TABLE <misp2_schema>.person_eula (
        id serial,
        person_id INTEGER NOT NULL,
        portal_id INTEGER NOT NULL,
        accepted BOOLEAN NOT NULL,
        auth_method VARCHAR(64),
        src_addr VARCHAR(64),
        created TIMESTAMP NOT NULL DEFAULT current_timestamp,
        last_modified TIMESTAMP NOT NULL DEFAULT current_timestamp,
        username VARCHAR(20) NOT NULL DEFAULT 'admin'
    );
    
    -- Add primary key constraint
    RAISE NOTICE 'Adding primary key constraint to ''person_eula'' table.';
    ALTER TABLE <misp2_schema>.person_eula ADD CONSTRAINT 
        person_eula_pk PRIMARY KEY(id);
    
    -- Add foreign key contstraint
    RAISE NOTICE 'Adding foreign key constraints to ''person_eula'' table.';
    ALTER TABLE <misp2_schema>.person_eula ADD CONSTRAINT 
        fk_person_eula_person FOREIGN KEY (person_id) REFERENCES 
        <misp2_schema>.person (id) ON DELETE CASCADE ON UPDATE CASCADE;
    -- Index in_uq_person_eula_person_id_portal_id applies to foreign key fk_person_eula_person   
    
    ALTER TABLE <misp2_schema>.person_eula ADD CONSTRAINT 
        fk_person_eula_portal FOREIGN KEY (portal_id) REFERENCES 
        <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
    CREATE INDEX in_person_eula_portal ON <misp2_schema>.person_eula (portal_id);

    -- Add unique index for person and portal combination: each person can accept EULA once per portal.
    RAISE NOTICE 'Adding unique index to ''person_eula'' table.';
    CREATE UNIQUE INDEX in_uq_person_eula_person_id_portal_id ON <misp2_schema>.person_eula (person_id, portal_id);

    -- Table and sequence access permission grants
    RAISE NOTICE 'Granting access permissions for ''person_eula'' table.';
    GRANT ALL ON <misp2_schema>.person_eula TO <misp2_schema>;
    GRANT ALL ON <misp2_schema>.person_eula_id_seq TO <misp2_schema>;
    
    RAISE NOTICE 'Inserting comments for ''person_eula'' table.';
    COMMENT ON TABLE <misp2_schema>.person_eula
        IS 'Tabel sisaldab kasutajate portaali kasutajalitsensi tingimustega nõustumise tulemusi.
            Kui portaali sisseloginud kasutaja on litsensi tingimustega nõustunud, tehakse käesolevasse
            tabelisse kirje ja järgmisel sisselogimisel litsensiga nõustumise ekraani enam ei näidata.
            
            Tabeli kirje määrab ennekõike seose kasutajate tabeli ''person'' ja portaali tabeli ''portal''
            vahel koos nõustumise olekuga tõeväärtuse tüüpi veerus ''accepted''. Lisaks sellele salvestatakse
            nõustumise juurde metaandmed nagu nõustumise aeg ja autentimismeetod.
           ';
    COMMENT ON COLUMN <misp2_schema>.person_eula.id
        IS 'tabeli primaarvõti'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.portal_id
        IS 'viide portaalile ''portal'' tabelis, millega EULA seotud on'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.person_id
        IS 'viide isikule, kes portaali EULA-ga on nõustunud (või nõustumise tagasi lükanud)'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.accepted
        IS 'tõeväärtus, mis näitab nõustumise olekut. Välja väärtus on
             - tõene, kui kasutaja on EULA-ga nõustunud;
             - väär, kui kasutaja on nõustumise tagasi lükanud;'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.auth_method 
        IS 'kasutaja autentimismeetodi metainfo'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.src_addr 
        IS 'kasutaja (IP) aadress'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.created
        IS 'sissekande loomisaeg'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.last_modified
        IS 'sissekande viimase muutmise aeg'
    ;
    COMMENT ON COLUMN <misp2_schema>.person_eula.username
        IS 'sissekande looja kasutajanimi'
    ;
      
    RAISE NOTICE '--- Alter-script v 2.1.13 finished successfully ---';
END $$;

