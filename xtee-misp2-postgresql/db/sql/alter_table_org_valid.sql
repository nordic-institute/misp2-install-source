alter table misp2.org_valid  ALTER COLUMN created TYPE timestamp using now();
alter table misp2.org_valid  ALTER COLUMN last_modified TYPE timestamp using now();
