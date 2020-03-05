-- misp2.portal table
ALTER TABLE misp2.classifier ADD COLUMN query_id integer null;
ALTER TABLE misp2.classifier ADD CONSTRAINT fk_classifier_query FOREIGN KEY (query_id) REFERENCES misp2.query (id) ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX in_classifier_query ON misp2.classifier (query_id);

-- misp2.query table
ALTER TABLE misp2.query ADD COLUMN xroad_request_namespace varchar(256) null;

-- misp2.classifier table
DROP INDEX misp2.in_classifier_name_idx;
CREATE UNIQUE INDEX in_classifier_name_idx ON misp2.classifier(query_id, name);

-- misp2.log_query table
ALTER TABLE misp2.query_log ALTER COLUMN org_code TYPE varchar(256);
ALTER TABLE misp2.query_log ALTER COLUMN unit_code TYPE varchar(256);

-- change from trusty branch ver 1.0.52
ALTER TABLE misp2.topic DROP CONSTRAINT IF EXISTS uniq_topics_portal;
ALTER TABLE misp2.topic ADD CONSTRAINT uniq_topics_portal UNIQUE(name, portal_id);
