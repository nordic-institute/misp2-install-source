DELETE FROM misp2.query WHERE query.producer_id IN (SELECT id FROM misp2.producer WHERE in_use IS FALSE AND is_complex IS NOT TRUE); --Delete queries of non-active non-complex producers

DELETE FROM misp2.group_person WHERE org_id NOT IN (SELECT id FROM misp2.org); --Delete group_persons which reference non-existing org-s (preparation for foreign key)

ALTER TABLE misp2.group_person ADD CONSTRAINT fk_group_person_org FOREIGN KEY (org_id) REFERENCES misp2.org (id) ON DELETE CASCADE ON UPDATE CASCADE; --Add missing foreign key
CREATE INDEX in_group_person_org ON misp2.group_person (org_id);