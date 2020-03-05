DROP TABLE misp2.admin
;

CREATE TABLE misp2.admin 
( 
   id serial,
   created timestamp not null default current_timestamp,
   last_modified timestamp not null default current_timestamp,
   username varchar(20) not null default 'admin',
   password varchar(50) NOT NULL,
   login_username varchar(50) NOT NULL,
   salt varchar(50) NOT NULL
);

ALTER TABLE misp2.admin ADD CONSTRAINT admin_pk 
PRIMARY KEY(id)
;

CREATE UNIQUE INDEX in_admin_login_username
ON misp2.admin (login_username)
;

grant all on misp2.admin to misp2;

grant all on misp2.admin_id_seq to misp2;