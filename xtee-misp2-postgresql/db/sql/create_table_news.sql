CREATE TABLE misp2.news
( 
   id serial,
   created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   last_modified timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   username varchar(20) NOT NULL DEFAULT 'admin',
   lang varchar(10) NOT NULL,
   portal_id integer NOT NULL,
   news varchar(512)
);

ALTER TABLE misp2.news ADD CONSTRAINT PK_news
  PRIMARY KEY (id)
;
GRANT ALL ON misp2.news TO misp2;
GRANT ALL ON misp2.news_id_seq TO misp2;