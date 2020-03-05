CREATE TABLE misp2.org_name 
( 
   id serial,
   description varchar(256) NOT NULL,
   lang varchar(10)  NOT NULL,
   org_id integer NOT NULL,
   created timestamp not null default current_timestamp,
   last_modified timestamp not null default current_timestamp,
   username varchar(20) not null default 'admin'
);

ALTER TABLE misp2.org_name ADD CONSTRAINT pk_org_name
PRIMARY KEY(id);

CREATE UNIQUE INDEX in_on_oid_lang ON misp2.org_name (org_id, lang);

ALTER TABLE misp2.org_name ADD CONSTRAINT fk_org_name
  FOREIGN KEY (org_id) REFERENCES misp2.org (id)
ON DELETE CASCADE ON UPDATE CASCADE
;

grant all on misp2.org_name to misp2;
grant all on misp2.org_name_id_seq to misp2;

insert into misp2.org_name (description, lang, org_id ) 
select name, 'et', id from misp2.org; 
insert into misp2.org_name (description, lang, org_id ) 
select name, 'ru', id from misp2.org; 
insert into misp2.org_name (description, lang, org_id ) 
select name, 'en', id from misp2.org;

ALTER TABLE misp2.org DROP COLUMN name CASCADE;