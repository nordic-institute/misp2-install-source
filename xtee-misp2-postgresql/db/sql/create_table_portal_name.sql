CREATE TABLE misp2.portal_name 
( 
  id serial,
  description varchar(256) NOT NULL,
  lang varchar(10)  NOT NULL,
  portal_id integer NOT NULL,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
);

ALTER TABLE misp2.portal_name ADD CONSTRAINT pk_portal_name
PRIMARY KEY(id);

CREATE UNIQUE INDEX in_pn_pid_lang ON misp2.portal_name (portal_id, lang);

grant all on misp2.portal_name_id_seq to misp2;
grant all on misp2.portal_name to misp2;

ALTER TABLE misp2.portal DROP COLUMN name CASCADE;