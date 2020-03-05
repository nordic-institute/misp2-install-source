-- misp2.portal table
ALTER TABLE misp2.portal ADD COLUMN xroad_instance VARCHAR(64);
ALTER TABLE misp2.portal ADD COLUMN xroad_protocol_ver VARCHAR(5) NOT NULL DEFAULT '3.1';

ALTER TABLE misp2.portal ADD COLUMN misp2_xroad_service_member_class VARCHAR(16);
ALTER TABLE misp2.portal ADD COLUMN misp2_xroad_service_member_code VARCHAR(20);
ALTER TABLE misp2.portal ADD COLUMN misp2_xroad_service_subsystem_code VARCHAR(64);

-- misp2.org table
ALTER TABLE misp2.org ADD COLUMN member_class VARCHAR(16);
ALTER TABLE misp2.org ADD COLUMN subsystem_code VARCHAR(64);

-- misp2.producer table
ALTER TABLE misp2.producer ADD COLUMN member_class VARCHAR(16);
ALTER TABLE misp2.producer ADD COLUMN subsystem_code VARCHAR(64);
-- xroad_ver varchar(5), -- ? v5/v6 

-- misp2.t3_sec table: make query ID colmun larger
ALTER TABLE misp2.t3_sec ALTER COLUMN query_id TYPE VARCHAR(100);

-- remove misp2.portal column encrypted
ALTER TABLE misp2.portal DROP COLUMN encrypted;