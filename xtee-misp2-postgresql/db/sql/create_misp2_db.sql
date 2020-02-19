create schema <misp2_schema>;

--  Drop Tables, Stored Procedures and Views 
DROP TABLE IF EXISTS <misp2_schema>.classifier, <misp2_schema>.check_register_status, <misp2_schema>.group_, <misp2_schema>.group_item, <misp2_schema>.group_person, <misp2_schema>.manager_candidate, <misp2_schema>.news, 
<misp2_schema>.org, <misp2_schema>.org_name, <misp2_schema>.org_person, <misp2_schema>.org_query, <misp2_schema>.org_valid, <misp2_schema>.person, <misp2_schema>.producer_name, <misp2_schema>.producer, <misp2_schema>.query_name, <misp2_schema>.query_error_log, <misp2_schema>.query, <misp2_schema>.query_log, 
<misp2_schema>.t3_sec, <misp2_schema>.xforms, <misp2_schema>.xslt, <misp2_schema>.person_mail_org, <misp2_schema>.package, <misp2_schema>.topic_name, <misp2_schema>.portal_name, <misp2_schema>.query_topic, <misp2_schema>.topic, <misp2_schema>.portal, <misp2_schema>.admin, <misp2_schema>.xroad_instance, <misp2_schema>.portal_eula, <misp2_schema>.person_eula CASCADE;


CREATE TABLE <misp2_schema>.classifier ( 
  id serial,
  content text not null,    --  klassifikaatori sisu XML formaadis 
  name varchar(50) not null,         --  klassifikaatori nimetus
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  -- xtee päringu parameetrid, millest antud klassifikaatorit laeti baasi andmed ja kust seda saab uuendada hiljem, süsteemse klassifikaatori puhul (neid ei laeta andmekogust) on väärtus  null
  -- kas tegu on süsteemse parameetriga või mitte, saab kontrollida välja 'xroad_query_xroad_protocol_ver' järgi
  xroad_query_xroad_protocol_ver VARCHAR(5) NULL,
  xroad_query_xroad_instance VARCHAR(64) NULL,
  xroad_query_member_class VARCHAR(16) NULL,
  xroad_query_member_code VARCHAR(50) NULL,
  xroad_query_subsystem_code VARCHAR(64) NULL, 
  xroad_query_service_code VARCHAR(256) NULL,
  xroad_query_service_version VARCHAR(256) NULL, 
  xroad_query_request_namespace VARCHAR(256) NULL
)
;
CREATE TABLE <misp2_schema>.topic (
  id serial,
  name varchar(150) not null,
  priority integer,
  portal_id integer not null,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
)
;
CREATE TABLE <misp2_schema>.topic_name (
  id serial,
  description varchar(256) not null,
  lang varchar(10) not null,
  topic_id integer not null,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
)
;

CREATE TABLE <misp2_schema>.query_topic( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  query_id integer NOT NULL,    --  viide päringule
  topic_id integer NOT NULL    --  viide teemale,
)
;
COMMENT ON TABLE <misp2_schema>.classifier
    IS 'andmekogu klassifikaatorid, mis laetakse andmekogust MISPi baasi loadclassifier päringuga, kasutatakse XML - formaadis klassifikatoreid'
;
COMMENT ON COLUMN <misp2_schema>.classifier.content
    IS 'klassifikaatori sisu XML formaadis'
;

CREATE TABLE <misp2_schema>.group_ ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  org_id integer NOT NULL,    --  viide asutusele, mille juures see grupp on kasutatav (mingi asutuse gruppi saab kasutada ka tema allasutuste juures ) 
  portal_id integer NOT NULL,
  name varchar(150) NOT NULL    --  grupi nimi 
)
;
COMMENT ON TABLE <misp2_schema>.group_
    IS 'kasutajagrupid'
;
COMMENT ON COLUMN <misp2_schema>.group_.org_id
    IS 'viide asutusele, mille juures see grupp on kasutatav (mingi asutuse gruppi saab kasutada ka tema allasutuste juures )'
;
COMMENT ON COLUMN <misp2_schema>.group_.name
    IS 'grupi nimi'
;

CREATE TABLE <misp2_schema>.group_item ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  group_id integer NOT NULL,    --  viide grupile 
  invisible boolean,    --  varjatud teenuste menüüs 
  org_query_id integer NOT NULL    --  viide lubatud päringule,  
)
;
COMMENT ON TABLE <misp2_schema>.group_item
    IS 'grupi päringuõigused'
;
COMMENT ON COLUMN <misp2_schema>.group_item.group_id
    IS 'viide grupile'
;
COMMENT ON COLUMN <misp2_schema>.group_item.invisible
    IS 'varjatud teenuste menüüs'
;
COMMENT ON COLUMN <misp2_schema>.group_item.org_query_id
    IS 'viide lubatud päringule '
;

CREATE TABLE <misp2_schema>.group_person ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  group_id integer NOT NULL,    --  viide kasutajagrupile, kuhu kasutaja kuulub 
  person_id integer NOT NULL,    --  viide isikule, kes gruppi kuulub 
  org_id integer NOT NULL,    --  asutus, mille all kehtib see kirje (millise asutuse esindajana võib antud päringut sooritada) see võib olla sama asutus, mis group.org_id või ka viimase allasutus 
  validuntil date    --  aegumiskuupäev, mis ajani gruppikuuluvus kehtib 
)
;
COMMENT ON TABLE <misp2_schema>.group_person
    IS 'kasutajagruppi kuuluvus'
;
COMMENT ON COLUMN <misp2_schema>.group_person.group_id
    IS 'viide kasutajagrupile, kuhu kasutaja kuulub'
;
COMMENT ON COLUMN <misp2_schema>.group_person.person_id
    IS 'viide isikule, kes gruppi kuulub'
;
COMMENT ON COLUMN <misp2_schema>.group_person.org_id
    IS 'asutus, mille all kehtib see kirje (millise asutuse esindajana võib antud päringut sooritada) see võib olla sama asutus, mis group.org_id või ka viimase allasutus'
;
COMMENT ON COLUMN <misp2_schema>.group_person.validuntil
    IS 'aegumiskuupäev, mis ajani gruppikuuluvus kehtib'
;

CREATE TABLE <misp2_schema>.manager_candidate ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  manager_id integer NOT NULL,
  org_id integer NOT NULL,
  auth_ssn varchar(20) NOT NULL,
  portal_id integer NOT NULL
)
;
COMMENT ON TABLE <misp2_schema>.manager_candidate
    IS 'asutuse pääsuõiguste halduri kandidaadid, kelle puhul on vajalik mitme esindusõigusliku isiku poolt kinnitamine halduriks'
;

CREATE TABLE <misp2_schema>.org ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',  --  v5: asutuse kood ; v6: member code
  member_class varchar(16),  -- + v5: NULL; v6: member class
  subsystem_code varchar(64),  -- + v5: NULL; v6: subsystem code
  code varchar(20) not null,    --  asutuse kood 
  sup_org_id integer    --  viide ülemasutusele 
)
;
COMMENT ON TABLE <misp2_schema>.org
    IS 'asutused'
;
COMMENT ON COLUMN <misp2_schema>.org.code
    IS 'asutuse kood'
;
COMMENT ON COLUMN <misp2_schema>.org.sup_org_id
    IS 'viide ülemasutusele'
;

CREATE TABLE <misp2_schema>.org_name 
( 
   id serial,
   description varchar(256) NOT NULL,
   lang varchar(10)  NOT NULL,
   org_id integer NOT NULL,
   created timestamp not null default current_timestamp,
   last_modified timestamp not null default current_timestamp,
   username varchar(20) not null default 'admin'
)
;

CREATE TABLE <misp2_schema>.org_person ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  org_id integer NOT NULL,
  person_id integer NOT NULL,
  portal_id integer NOT NULL,
  role integer not null DEFAULT 0,    --  kasutajaroll: look in ee.aktors.<misp2_schema>.util.RolesBitwise for more information
  profession varchar(50)
)
;
COMMENT ON TABLE <misp2_schema>.org_person
    IS 'asutuse ja isiku seos, mis näitab, et isikul on õigus seda asutust esindada, teha päringuid selle asutuse nime all'
;
COMMENT ON COLUMN <misp2_schema>.org_person.role
    IS 'kasutajaroll: 0 - asutuse tavakasutaja 1 - asutuse pääsuõiguste haldur 2 - portaali haldur'
;

CREATE TABLE <misp2_schema>.org_query ( 
  id serial,
  org_id integer NOT NULL,
  query_id bigint NOT NULL,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
)
;
COMMENT ON TABLE <misp2_schema>.org_query
    IS 'asutusele turvaserveris avatud päringud'
;

CREATE TABLE <misp2_schema>.org_valid ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  org_id integer NOT NULL,    --  viide asutusele 
  valid_date  timestamp NOT NULL    --  kehtivuskontrolli teostamise aeg 
)
;
COMMENT ON TABLE <misp2_schema>.org_valid
    IS 'Asutuste kehtivuspäringu sooritamiste ajad'
;
COMMENT ON COLUMN <misp2_schema>.org_valid.org_id
    IS 'viide asutusele'
;
COMMENT ON COLUMN <misp2_schema>.org_valid.valid_date
    IS 'kehtivuskontrolli teostamise aeg'
;

CREATE TABLE <misp2_schema>.person ( 
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  ssn varchar(20) NOT NULL,    --  isikukood 
  givenname varchar(50),    --  eesnimi 
  surname varchar(50) NOT NULL,    --  perekonnanimi 
  password varchar(50),    --  parool 
  password_salt VARCHAR(50) NOT NULL DEFAULT '', -- sool parooli krüpteerimiseks
  overtake_code varchar(50),    --  ülevõtmiskood 
  overtake_code_salt VARCHAR(50) NOT NULL DEFAULT '', -- sool ülevõtmiskoodi krüpteerimiseks
  certificate varchar(3000),    --  sertifikaat 
  last_portal INTEGER  -- viimati kasutatud portaal
)
;
COMMENT ON TABLE <misp2_schema>.person
    IS 'isikud, portaali kasutajakontod'
;
COMMENT ON COLUMN <misp2_schema>.person.ssn
    IS 'isikukood'
;
COMMENT ON COLUMN <misp2_schema>.person.givenname
    IS 'eesnimi'
;
COMMENT ON COLUMN <misp2_schema>.person.surname
    IS 'perekonnanimi'
;
COMMENT ON COLUMN <misp2_schema>.person.password
    IS 'ülevõtmiskood'
;
COMMENT ON COLUMN <misp2_schema>.person.certificate
    IS 'sertifikaat'
;

CREATE TABLE <misp2_schema>.portal ( 
  id serial,
  short_name varchar(32) not null,
  org_id integer NOT NULL,    --  portaali (pea)asutus 
  misp_type integer NOT NULL,    --  portaali tüüp, vanas MISPis konfiparemeeter misp 
  security_host varchar(256) NOT NULL,    --  turvaserveri aadress, vanas MISPis konfiparemeeter security_host
  message_mediator varchar(256) NOT NULL,    --  päringute saatmise aadress (turvaserver või sõnumimootor)
  bpel_engine varchar(100) DEFAULT NULL,    --  BPEL mootori aadress (NULL - tegu MISP Lite-ga)
  debug integer NOT NULL,    --  debug log level (default = 0 - no debug info) 
  univ_auth_query varchar(256),    --  universaalse portaalitüübi korral: üksuse esindusõiguse kontrollpäringu nimi 
  univ_check_query varchar(256),    --  universaalse portaalitüübi korral üksuse kehtivuse kontrollpäringu nimi 
  univ_check_valid_time integer,    --  universaalse portaalitüübi korral: üksuse kehtivuse kontrollpäringu tulemuse kehtivusaeg tundides 
  univ_check_max_valid_time integer,
  univ_use_manager boolean,    --  universaalse portaalitüübi korral: näitab, kas antud portaali puhul kasutada üksuse halduri rolli, või selle asemel nn lihtsustatud õiguste andmist ilma üksuse halduri määramiseta; vanas MISPis konfiparameeter  'lihtsustatud_oigused' 
  use_topics boolean default false, -- naitab kas teenuste teemad on kasutusel
  use_xrd_issue boolean default false, -- naitab kas toimiku vali on kasutusel
  log_query boolean default true,    --  logimispäringu tegemine turvaserverisse
  register_units boolean,
  unit_is_consumer boolean,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  client_xroad_instance varchar(64), -- + V6 xroad client instance, nt ee-dev, EE - kehtib kõigi X-tee memberite kohta (org/producer)
  xroad_protocol_ver varchar(5) not null default '3.1', -- + 3.1(X-tee v5); 4.0(X-tee v6)
  misp2_xroad_service_member_class varchar(16), -- x-tee v6 misp2 logOnly teenuse liikmeklass (teenuse nimi eeldatakse olevat logOnly.v1)
  misp2_xroad_service_member_code varchar(20), --  x-tee v6 misp2 logOnly teenuse liikmekood
  misp2_xroad_service_subsystem_code varchar(64), -- x-tee v6 misp2 logOnly teenuse alamüsteemi kood
  eula_in_use boolean default false -- kas kasutajatingimustega nõustumist küsitakse portaali esmasel sisenemisel

 );

CREATE TABLE <misp2_schema>.portal_name 
( 
  id serial,
  description varchar(256) NOT NULL,
  lang varchar(10)  NOT NULL,
  portal_id integer NOT NULL,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
);

;
COMMENT ON TABLE <misp2_schema>.portal
    IS 'portaali andmed'
;
COMMENT ON COLUMN <misp2_schema>.portal.org_id
    IS 'portaali (pea)asutus'
;
COMMENT ON COLUMN <misp2_schema>.portal.short_name
    IS 'lühinimi, mida kasutatakse antud portaali poole pöördumisel URLis parameetrina (vanas MISPis portaali kataloogi nimi)'
;
COMMENT ON COLUMN <misp2_schema>.portal.misp_type
    IS 'portaali tüüp, vanas MISPis konfiparemeeter "misp"'
;
COMMENT ON COLUMN <misp2_schema>.portal.security_host
    IS 'turvaserveri aadress, vanas MISPis konfiparemeeter "security_host"'
;
COMMENT ON COLUMN <misp2_schema>.portal.message_mediator
    IS 'päringute saatmise aadress (turvaserver või sõnumimootor)'
;
COMMENT ON COLUMN <misp2_schema>.portal.bpel_engine
    IS 'BPEL mootori aadress (NULL - tegu MISP Lite-ga)'
;
COMMENT ON COLUMN <misp2_schema>.portal.debug
    IS 'debug log level (default = 0 - no debug info)'
;
COMMENT ON COLUMN <misp2_schema>.portal.univ_auth_query
    IS 'universaalse portaalitüübi korral: üksuse esindusõiguse kontrollpäringu nimi'
;
COMMENT ON COLUMN <misp2_schema>.portal.univ_check_query
    IS 'universaalse portaalitüübi korral üksuse kehtivuse kontrollpäringu nimi'
;
COMMENT ON COLUMN <misp2_schema>.portal.univ_check_valid_time
    IS 'universaalse portaalitüübi korral: üksuse kehtivuse kontrollpäringu tulemuse kehtivusaeg tundides'
;
COMMENT ON COLUMN <misp2_schema>.portal.univ_use_manager
    IS 'universaalse portaalitüübi korral: näitab, kas antud portaali puhul kasutada üksuse halduri rolli, või selle asemel nn lihtsustatud õiguste andmist ilma üksuse halduri määramiseta; vanas MISPis konfiparameeter  ''lihtsustatud_oigused'''
;
COMMENT ON COLUMN <misp2_schema>.portal.log_query
    IS 'logimispäringu nimi'
;
COMMENT ON COLUMN <misp2_schema>.portal.client_xroad_instance
    IS 'X-Tee v6 kliendi instants'
;
COMMENT ON COLUMN <misp2_schema>.portal.eula_in_use
    IS 'tõene, kui portaalis on EULA kasutusel ja kasutajatelt küsitakse sellega nõustumist'
;


CREATE TABLE <misp2_schema>.check_register_status (
  id serial,
  query_name varchar(256) NOT NULL,
  query_time timestamp NOT NULL default now(),
  is_ok boolean NOT NULL,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
);

COMMENT ON TABLE <misp2_schema>.check_register_status
    IS 'kehtivuse kontrollpäringu  registri olek'
;
COMMENT ON COLUMN <misp2_schema>.check_register_status.query_name
    IS 'kehtivuse kontrollpäringu  nimi'
;
COMMENT ON COLUMN <misp2_schema>.check_register_status.query_time
    IS 'kehtivuse kontrollpäringu  viimase sooritamise aeg'
;
COMMENT ON COLUMN <misp2_schema>.check_register_status.is_ok
    IS 'kehtivuse kontrollpäringu  registri staatus: 1 - ok, 0 - vigane (annab veaga vastust)'
;

CREATE TABLE <misp2_schema>.producer (
  id serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  xroad_instance varchar(64), -- v5: NULL; v6: X-Road Instance
  short_name varchar(50) not null, -- v5: producer name; v6: member code
  member_class varchar(16),  -- + v5: NULL; v6: member class / unit class
  subsystem_code varchar(64),  -- + v5: NULL; v6: subsystem code
  -- xroad_ver varchar(5), -- ? v5/v6 
  protocol varchar(16) not null,
  in_use boolean,
  is_complex boolean,
  wsdl_url varchar(256),
  repository_url varchar(256),
  portal_id integer NOT NULL
)
;
COMMENT ON TABLE <misp2_schema>.producer
    IS 'X-tee andmekogud'
;
COMMENT ON COLUMN <misp2_schema>.producer.protocol
        IS 'Protokolli, mida produceri querid kasutavad sõnumivahetuses.'
		;

CREATE TABLE <misp2_schema>.producer_name ( 
  id serial,
  description varchar(256) NOT NULL,
  lang varchar(10),
  producer_id integer,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
)
;

CREATE TABLE <misp2_schema>.query (
  id serial,
  type integer,    --  teenuse tüüp 0 - X-tee teenus  1-  WS-BPEL teenus  (2- portaali päringuõiguste andmekogu teenus)
  name varchar(256) NOT NULL, -- teenuse lühinimi, X-tee v6 SOAP 'serviceCode.serviceVersion' või REST 'operationId'
  xroad_request_namespace varchar(256) null, -- kasutatakse x-tee v6 klassifikaatorite päringul
  sub_query_names TEXT NULL, -- kasutatakse kompleksteenuse puhul alampäringute nimistu hoidmiseks
  producer_id integer,    --  viide andmekogule 
  package_id integer,    --  BPEL teenuse korral, viide BPEL package-le
  openapi_service_code varchar(256), -- Service code required for xroad rest requests
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
)
;
COMMENT ON TABLE <misp2_schema>.query
    IS 'teenused'
;
COMMENT ON COLUMN <misp2_schema>.query.type
    IS 'teenuse tüüp 0 - X-tee teenus  1-  WS-BPEL teenus  (2- portaali päringuõiguste andmekogu teenus)'
;
COMMENT ON COLUMN <misp2_schema>.query.name
    IS 'Teenuse lühinimi, X-tee v6 korral serviceCode ja serviceVersion punktiga eraldatuna. REST teenuste puhul operationId.'
;
COMMENT ON COLUMN <misp2_schema>.query.xroad_request_namespace
    IS 'kasutatakse x-tee v6 klassifikaatorite päringul'
;
COMMENT ON COLUMN <misp2_schema>.query.sub_query_names
    IS 'Kasutatakse kompleksteenuse puhul alampäringute nimistu hoidmiseks.'
;
COMMENT ON COLUMN <misp2_schema>.query.producer_id
    IS 'viide andmekogule'
;
COMMENT ON COLUMN <misp2_schema>.query.package_id
    IS 'BPEL teenuse korral, viide BPEL package-le'
;
COMMENT ON COLUMN <misp2_schema>.query.openapi_service_code
    IS 'Teenuse nimi, mis on vajalik xroad rest teenuste kasutamiseks'
;

CREATE TABLE <misp2_schema>.query_name (
  id serial,
  description varchar(256) not null,
  lang varchar(10),
  query_id integer,    --  viide teenusele
  query_note text, -- teenuse quicktipi poolt kasutatav väli
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin'
)
;

CREATE TABLE <misp2_schema>.query_error_log (
  id serial,
  query_log_id integer,
  code varchar(64),
  description text,
  detail text,
  created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_modified timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  username varchar(20) NOT NULL DEFAULT 'admin'
);

CREATE TABLE <misp2_schema>.query_log ( 
  id serial,
  query_name varchar(256),    --  andmekogu.päring.versioon
  main_query_name varchar(256),
  query_id varchar(128),    --  päringu ID
  description varchar(800),
  org_code varchar(256),
  unit_code varchar(256),
  query_time timestamp,
  person_ssn varchar(20), -- päringu sooritaja isikukood
  portal_id integer,
  query_time_sec numeric(10, 3), -- päringu sooritamise aeg sekundites
  success boolean default true,
  query_size numeric(12, 3), -- päringu vastuse suurus baitides
  created timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  last_modified timestamp not null default current_timestamp
)
;
COMMENT ON TABLE <misp2_schema>.query_log                
    IS 'sooritatud päringute metainfo logi'
;
COMMENT ON COLUMN <misp2_schema>.query_log.query_name
    IS 'andmekogu.päring.versioon'
;
COMMENT ON COLUMN <misp2_schema>.query_log.query_id
    IS 'päringu ID'
;
COMMENT ON COLUMN <misp2_schema>.query_log.person_ssn
    IS 'päringu sooritaja isikukood'
;

CREATE TABLE <misp2_schema>.t3_sec ( 
  id  serial,
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  user_from varchar(20) NOT NULL,    --  isikukood, kes andis õigusi 
  user_to varchar(20),    --  isikukood, kellele anti päringuõigused 
  action_id integer NOT NULL,    --  tegevuse tyyp: 0 - halduri määramine, 1 - haldiri kustutamine, 2 - isiku kasutajagruppi lisamine, 3 - isiku kasutajagrupist eemaldamine,  4 - päringuõiguste lisamine,  5 - päringuõiguste eemaldamine, 6 - kasutajagruppide lisamine,  7 - kasutajagruppide eemaldamine, 8 - esindusõiguse kontroll, 9 - isiku lisamine, 10 - isiku kustutamine, 11 - asutuse lisamine, 12 - asutuse kustutamine, 14 - portaali kustutamine, 15 - grupi parameetrite muutmine 
  query varchar(256),
  group_name varchar(150),    --  kasutajagrupi nimi 
  org_code varchar(20),    --  asutuse kood 
  portal_name varchar(32),
  valid_until varchar(50),
  query_id varchar(100)    --  päringu id 
)
;
COMMENT ON TABLE <misp2_schema>.t3_sec
    IS 'õiguste haldamisega seotud tegevuste logitabel, need tegevused salvestatakse ka X-tee logipäringuga'
;
COMMENT ON COLUMN <misp2_schema>.t3_sec.user_from
    IS 'isikukood, kes andis õigusi'
;
COMMENT ON COLUMN <misp2_schema>.t3_sec.user_to
    IS 'isikukood, kellele anti päringuõigused'
;
COMMENT ON COLUMN <misp2_schema>.t3_sec.action_id
    IS 'tegevuse tyyp: 0 - halduri määramine, 1 - haldiri kustutamine, 2 - isiku kasutajagruppi lisamine, 3 - isiku kasutajagrupist eemaldamine,  4 - päringuõiguste lisamine,  5 - päringuõiguste eemaldamine, 6 - kasutajagruppide lisamine,  7 - kasutajagruppide eemaldamine, 8 - esindusõiguse kontroll, 9 - isiku lisamine, 10 - isiku kustutamine, 11 - asutuse lisamine, 12 - asutuse kustutamine, 14 - portaali kustutamine, 15 - grupi parameetrite muutmine'
;
COMMENT ON COLUMN <misp2_schema>.t3_sec.group_name
    IS 'kasutajagrupi nimi'
;
COMMENT ON COLUMN <misp2_schema>.t3_sec.org_code
    IS 'asutuse kood'
;
COMMENT ON COLUMN <misp2_schema>.t3_sec.query_id
    IS 'päringu id'
;

CREATE TABLE <misp2_schema>.xforms ( 
  id serial,
  form text,    --  XForms vorm 
  query_id integer,    --  viide päringule 
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  URL varchar(256)    --  URL, millelt laetakse XForms 
)
;
COMMENT ON TABLE <misp2_schema>.xforms
    IS 'teenuste XForms vormid'
;
COMMENT ON COLUMN <misp2_schema>.xforms.form
    IS 'XForms vorm'
;
COMMENT ON COLUMN <misp2_schema>.xforms.query_id
    IS 'viide päringule'
;
COMMENT ON COLUMN <misp2_schema>.xforms.URL
    IS 'URL, millelt laetakse XForms'
;

CREATE TABLE <misp2_schema>.xslt ( 
  id serial,
  query_id integer,    --  viide päringule, kui null, siis rakendatakse kõigile
  portal_id integer,
  xsl text,    --  XSL stiililileht 
  priority smallint,    --  XSL rakendamise järjekorranumber 0-esimene 
  created timestamp not null default current_timestamp,
  last_modified timestamp not null default current_timestamp,
  username varchar(20) not null default 'admin',
  name varchar(256),    --  XSL stiililehe nimetus  
  form_type integer NOT NULL,    --  mis tüüpi vormile rakendatakse 0-HTML 1-PDF 
  in_use boolean NOT NULL,    --  näitab, kas XSL on kasutusel või mitte 
  producer_id integer,    --  viide andmekogule 
  URL varchar(256)    --  URL, millelt laetakse XSL 
)
;
COMMENT ON TABLE <misp2_schema>.xslt
    IS 'XSL stiililehed, mis rakendatakse XForms vormidele'
;
COMMENT ON COLUMN <misp2_schema>.xslt.query_id
    IS 'viide päringule, kui null, siis rakendatakse kõigile'
;
COMMENT ON COLUMN <misp2_schema>.xslt.xsl
    IS 'XSL stiililileht'
;
COMMENT ON COLUMN <misp2_schema>.xslt.priority
    IS 'XSL rakendamise järjekorranumber 0-esimene'
;
COMMENT ON COLUMN <misp2_schema>.xslt.name
    IS 'XSL stiililehe nimetus '
;
COMMENT ON COLUMN <misp2_schema>.xslt.form_type
    IS 'mis tüüpi vormile rakendatakse 0-HTML 1-PDF'
;
COMMENT ON COLUMN <misp2_schema>.xslt.in_use
    IS 'näitab, kas XSL on kasutusel või mitte'
;
COMMENT ON COLUMN <misp2_schema>.xslt.producer_id
    IS 'viide andmekogule'
;
COMMENT ON COLUMN <misp2_schema>.xslt.URL
    IS 'URL, millelt laetakse XSL'
;

CREATE TABLE <misp2_schema>.person_mail_org (
    id serial,
    org_id integer NULL,
    person_id integer NOT NULL,
    mail varchar(75),    --  elektronposti aadress
    notify_changes boolean NOT NULL default false,   --  kas kasutajat teavitatakse meili teel temaga tehtud muudatustest
    created timestamp not null default current_timestamp,
    last_modified timestamp not null default current_timestamp,
    username character varying(20)
)
;
COMMENT ON COLUMN <misp2_schema>.person_mail_org.mail
    IS 'elektronposti aadress'
;

CREATE TABLE <misp2_schema>.package (
    id serial,
    name varchar(256),    --  BPEL package nimi
    url varchar(256),    --  BPEL package upload url
    created timestamp not null default current_timestamp,
    last_modified timestamp not null default current_timestamp,
    username character varying(20)
)
;
COMMENT ON TABLE <misp2_schema>.package
    IS 'BPEL "pakid" (package)'
;
COMMENT ON COLUMN <misp2_schema>.package.name
    IS 'BPEL package nimi'
;
COMMENT ON COLUMN <misp2_schema>.package.url
    IS 'BPEL package upload url'
;

CREATE TABLE <misp2_schema>.admin 
( 
   id serial,
   created timestamp not null default current_timestamp,
   last_modified timestamp not null default current_timestamp,
   username varchar(20) not null default 'admin',
   password varchar(50) NOT NULL,
   login_username varchar(50) NOT NULL,
   salt varchar(50) NOT NULL
)
;

CREATE TABLE <misp2_schema>.news
( 
   id serial,
   created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   last_modified timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   username varchar(20) NOT NULL DEFAULT 'admin',
   lang varchar(10) NOT NULL,
   portal_id integer NOT NULL,
   news varchar(512)
)
;

CREATE TABLE <misp2_schema>.xroad_instance (
    id serial,
    portal_id INTEGER NOT NULL,
    code VARCHAR(64) NOT NULL,
    in_use BOOLEAN,
	selected BOOLEAN,
    created TIMESTAMP NOT NULL DEFAULT current_timestamp,
    last_modified TIMESTAMP NOT NULL DEFAULT current_timestamp,
    username VARCHAR(20) NOT NULL DEFAULT 'admin'
);
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

CREATE TABLE <misp2_schema>.portal_eula (
    id serial,
    portal_id INTEGER NOT NULL,
    lang VARCHAR(2) NOT NULL,
    content text NOT NULL, -- *.MD file format
    created TIMESTAMP NOT NULL DEFAULT current_timestamp,
    last_modified TIMESTAMP NOT NULL DEFAULT current_timestamp,
    username VARCHAR(20) NOT NULL DEFAULT 'admin'
);
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
    
--  Create Primary Keys

ALTER TABLE <misp2_schema>.news ADD CONSTRAINT PK_news PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.topic ADD CONSTRAINT PK_topic PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.query_topic ADD CONSTRAINT PK_query_topic PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.classifier ADD CONSTRAINT PK_classifier PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.check_register_status ADD CONSTRAINT PK_check_register_status PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.group_ ADD CONSTRAINT group_pk PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.group_item ADD CONSTRAINT pk_group_item PRIMARY KEY (group_id, org_query_id);
ALTER TABLE <misp2_schema>.group_person ADD CONSTRAINT pk_group_person PRIMARY KEY (group_id, person_id, org_id);
ALTER TABLE <misp2_schema>.manager_candidate ADD CONSTRAINT pk_manager_candidate PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.org ADD CONSTRAINT org_pk PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.org_name ADD CONSTRAINT pk_org_name PRIMARY KEY(id);
ALTER TABLE <misp2_schema>.org_person ADD CONSTRAINT org_person_id_pk PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.query_error_log ADD CONSTRAINT PK_query_error_log PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.org_query ADD CONSTRAINT PK_org_query PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.org_valid ADD CONSTRAINT org_valid_id_pk PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.person ADD CONSTRAINT person_pk PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.person_mail_org ADD CONSTRAINT PK_person_mail_org PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.portal ADD CONSTRAINT PK_portal PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.producer ADD CONSTRAINT PK_producer PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.producer_name ADD CONSTRAINT PK_producer_name PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.query ADD CONSTRAINT PK_query PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.query_name ADD CONSTRAINT PK_query_name PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.query_log ADD CONSTRAINT PK_query_log PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.t3_sec ADD CONSTRAINT t3_sec_id_pk PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.xforms ADD CONSTRAINT PK_xforms PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.xslt ADD CONSTRAINT PK_xslt PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.package ADD CONSTRAINT PK_package PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.topic_name ADD CONSTRAINT PK_topic_name PRIMARY KEY (id);
ALTER TABLE <misp2_schema>.portal_name ADD CONSTRAINT pk_portal_name PRIMARY KEY(id);
ALTER TABLE <misp2_schema>.admin ADD CONSTRAINT admin_pk PRIMARY KEY(id);
ALTER TABLE <misp2_schema>.topic ADD CONSTRAINT uniq_topics_portal UNIQUE(name, portal_id);
ALTER TABLE <misp2_schema>.xroad_instance ADD CONSTRAINT xroad_instance_pk PRIMARY KEY(id);
ALTER TABLE <misp2_schema>.portal_eula ADD CONSTRAINT portal_eula_pk PRIMARY KEY(id);
ALTER TABLE <misp2_schema>.person_eula ADD CONSTRAINT person_eula_pk PRIMARY KEY(id);

--  Create Indexes 

CREATE UNIQUE INDEX in_query_topic ON <misp2_schema>.query_topic (query_id, topic_id);
CREATE UNIQUE INDEX in_classifier_name_idx ON <misp2_schema>.classifier(name, xroad_query_member_code , xroad_query_xroad_protocol_ver , 
   xroad_query_xroad_instance , xroad_query_member_class , xroad_query_subsystem_code , xroad_query_service_code , xroad_query_service_version);
CREATE UNIQUE INDEX in_check_register_status ON <misp2_schema>.check_register_status(query_name);
CREATE UNIQUE INDEX in_uq_mgr_cand ON <misp2_schema>.manager_candidate (manager_id, org_id, auth_ssn, portal_id);
CREATE UNIQUE INDEX in_on_oid_lang ON <misp2_schema>.org_name (org_id, lang);
CREATE UNIQUE INDEX in_org_person_idx ON <misp2_schema>.org_person(org_id, person_id, portal_id);
CREATE UNIQUE INDEX in_org_query_idx ON <misp2_schema>.org_query(org_id, query_id);
CREATE UNIQUE INDEX in_org_valid_idx ON <misp2_schema>.org_valid (org_id);
CREATE UNIQUE INDEX in_person_ssn ON <misp2_schema>.person (ssn);
CREATE INDEX in_person_cert ON <misp2_schema>.person (certificate);
CREATE UNIQUE INDEX in_person_mail_org ON <misp2_schema>.person_mail_org (org_id, person_id);
CREATE UNIQUE INDEX UQ_portal_short_name ON <misp2_schema>.portal (short_name);
CREATE UNIQUE INDEX in_producer_name_pid_lang ON <misp2_schema>.producer_name (producer_id, lang);
CREATE UNIQUE INDEX in_qn_qid_lang ON <misp2_schema>.query_name (query_id, lang);
CREATE INDEX in_query_log_query_time ON <misp2_schema>.query_log (query_time);
CREATE INDEX in_query_log_query_name ON <misp2_schema>.query_log (query_name);
CREATE UNIQUE INDEX in_xslt_name_idx ON <misp2_schema>.xslt(portal_id, name);
CREATE UNIQUE INDEX in_topic_name ON <misp2_schema>.topic_name (lang, topic_id);
CREATE UNIQUE INDEX in_pn_pid_lang ON <misp2_schema>.portal_name (portal_id, lang);
CREATE UNIQUE INDEX in_admin_login_username ON <misp2_schema>.admin (login_username);
CREATE UNIQUE INDEX in_query_partial_producer_name ON <misp2_schema>.query (producer_id, name) WHERE openapi_service_code IS NULL;
CREATE UNIQUE INDEX in_query_partial_producer_name_service_code on <misp2_schema>.query (producer_id, name, openapi_service_code) WHERE openapi_service_code IS NOT NULL;
CREATE UNIQUE INDEX in_xroad_instance_code ON <misp2_schema>.xroad_instance (portal_id, code);
CREATE UNIQUE INDEX in_producer_portal_id_name_protocol ON <misp2_schema>.producer (portal_id, short_name, xroad_instance, member_class, subsystem_code, protocol);
CREATE UNIQUE INDEX in_uq_eula_portal_id_lang ON <misp2_schema>.portal_eula (portal_id, lang);
CREATE UNIQUE INDEX in_uq_query_producer_id_name ON <misp2_schema>.query (producer_id, name);
CREATE UNIQUE INDEX in_uq_query_producer_id_name_openapi_service_code
		ON <misp2_schema>.query (producer_id, name, COALESCE(openapi_service_code, ''));


--  Create Foreign Key Constraints with Indexes 

ALTER TABLE <misp2_schema>.topic_name ADD CONSTRAINT fk_topic_name_topic FOREIGN KEY (topic_id) REFERENCES <misp2_schema>.topic (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_topic_name_topic ON <misp2_schema>.topic_name (topic_id);

ALTER TABLE <misp2_schema>.group_ ADD CONSTRAINT fk_group_org FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_group_org ON <misp2_schema>.group_ (org_id);

ALTER TABLE <misp2_schema>.group_ ADD CONSTRAINT fk_group_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_group_portal ON <misp2_schema>.group_ (portal_id);

ALTER TABLE <misp2_schema>.query_log ADD CONSTRAINT fk_query_log_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_query_log_portal ON <misp2_schema>.query_log (portal_id);

ALTER TABLE <misp2_schema>.query_error_log ADD CONSTRAINT fk_query_error_log_query_log FOREIGN KEY (query_log_id) REFERENCES <misp2_schema>.query_log (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_query_error_log_query_log ON <misp2_schema>.query_error_log (query_log_id);

ALTER TABLE <misp2_schema>.topic ADD CONSTRAINT fk_topic_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_topic_portal ON <misp2_schema>.topic (portal_id);

ALTER TABLE <misp2_schema>.manager_candidate ADD CONSTRAINT fk_manager_candidate_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_manager_candidate_portal ON <misp2_schema>.manager_candidate (portal_id);

ALTER TABLE <misp2_schema>.query_topic ADD CONSTRAINT fk_q_t_topic FOREIGN KEY (topic_id) REFERENCES <misp2_schema>.topic (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_q_t_topic ON <misp2_schema>.query_topic (topic_id);

ALTER TABLE <misp2_schema>.query_topic ADD CONSTRAINT fk_q_t_query FOREIGN KEY (query_id) REFERENCES <misp2_schema>.query (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_q_t_query ON <misp2_schema>.query_topic (query_id);

ALTER TABLE <misp2_schema>.group_person ADD CONSTRAINT fk_group_person_person FOREIGN KEY (person_id) REFERENCES <misp2_schema>.person (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_group_person_person ON <misp2_schema>.group_person (person_id);

ALTER TABLE <misp2_schema>.group_person ADD CONSTRAINT fk_group_person_group FOREIGN KEY (group_id) REFERENCES <misp2_schema>.group_ (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_group_person_group ON <misp2_schema>.group_person (group_id);

ALTER TABLE <misp2_schema>.group_person ADD CONSTRAINT fk_group_person_org FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_group_person_org ON <misp2_schema>.group_person (org_id);

ALTER TABLE <misp2_schema>.manager_candidate ADD CONSTRAINT fk_manager_candidate_org FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_manager_candidate_org ON <misp2_schema>.manager_candidate (org_id);

ALTER TABLE <misp2_schema>.manager_candidate ADD CONSTRAINT fk_manager_candidate_person FOREIGN KEY (manager_id) REFERENCES <misp2_schema>.person (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_manager_candidate_person ON <misp2_schema>.manager_candidate (manager_id);

ALTER TABLE <misp2_schema>.org ADD CONSTRAINT fk_org_org FOREIGN KEY (sup_org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_org ON <misp2_schema>.org (sup_org_id);

ALTER TABLE <misp2_schema>.org_name ADD CONSTRAINT fk_org_name FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_name ON <misp2_schema>.org_name (org_id);

ALTER TABLE <misp2_schema>.org_person ADD CONSTRAINT fk_org_person_org FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_person_org ON <misp2_schema>.org_person (org_id);

ALTER TABLE <misp2_schema>.org_person ADD CONSTRAINT fk_org_person_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_person_portal ON <misp2_schema>.org_person (portal_id);

ALTER TABLE <misp2_schema>.org_person ADD CONSTRAINT fk_org_person_person FOREIGN KEY (person_id) REFERENCES <misp2_schema>.person (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_person_person ON <misp2_schema>.org_person (person_id);

ALTER TABLE <misp2_schema>.person_mail_org ADD CONSTRAINT fk_person_mail_org_org FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_person_mail_org_org ON <misp2_schema>.person_mail_org (org_id);

ALTER TABLE <misp2_schema>.person_mail_org ADD CONSTRAINT fk_person_mail_org_person FOREIGN KEY (person_id) REFERENCES <misp2_schema>.person (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_person_mail_org_person ON <misp2_schema>.person_mail_org (person_id);

ALTER TABLE <misp2_schema>.org_valid ADD CONSTRAINT fk_org_valid FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_valid ON <misp2_schema>.org_valid (org_id);

ALTER TABLE <misp2_schema>.org_query ADD CONSTRAINT fk_org_query_org FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_query_org ON <misp2_schema>.org_query (org_id);

ALTER TABLE <misp2_schema>.org_query ADD CONSTRAINT fk_org_query_query FOREIGN KEY (query_id) REFERENCES <misp2_schema>.query (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_org_query_query ON <misp2_schema>.org_query (query_id);

ALTER TABLE <misp2_schema>.group_item ADD CONSTRAINT fk_group_item_group FOREIGN KEY (group_id) REFERENCES <misp2_schema>.group_ (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_group_item_group ON <misp2_schema>.group_item (group_id);

ALTER TABLE <misp2_schema>.group_item ADD CONSTRAINT fk_group_item_org_query FOREIGN KEY (org_query_id) REFERENCES <misp2_schema>.org_query (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_group_item_org_query ON <misp2_schema>.group_item (org_query_id);

ALTER TABLE <misp2_schema>.portal ADD CONSTRAINT fk_portal_org FOREIGN KEY (org_id) REFERENCES <misp2_schema>.org (id) ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX in_portal_org ON <misp2_schema>.portal (org_id);

ALTER TABLE <misp2_schema>.query ADD CONSTRAINT fk_query_producer FOREIGN KEY (producer_id) REFERENCES <misp2_schema>.producer (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_query_producer ON <misp2_schema>.query (producer_id);

ALTER TABLE <misp2_schema>.query ADD CONSTRAINT fk_query_package FOREIGN KEY (package_id) REFERENCES <misp2_schema>.package (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_query_package ON <misp2_schema>.query (package_id);

ALTER TABLE <misp2_schema>.query_name ADD CONSTRAINT fk_query_name_id FOREIGN KEY (query_id) REFERENCES <misp2_schema>.query (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_query_name_id ON <misp2_schema>.query_name (query_id);

ALTER TABLE <misp2_schema>.producer_name ADD CONSTRAINT fk_producer_name FOREIGN KEY (producer_id) REFERENCES <misp2_schema>.producer (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_producer_name ON <misp2_schema>.producer_name (producer_id);

ALTER TABLE <misp2_schema>.producer ADD CONSTRAINT fk_producer_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_producer_portal ON <misp2_schema>.producer (portal_id);

ALTER TABLE <misp2_schema>.xforms ADD CONSTRAINT fk_xforms_query FOREIGN KEY (query_id) REFERENCES <misp2_schema>.query (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_xforms_query ON <misp2_schema>.xforms (query_id);

ALTER TABLE <misp2_schema>.xslt ADD CONSTRAINT fk_xslt_query FOREIGN KEY (query_id) REFERENCES <misp2_schema>.query (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_xslt_query ON <misp2_schema>.xslt (query_id);

ALTER TABLE <misp2_schema>.xslt ADD CONSTRAINT fk_xslt_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_xslt_portal ON <misp2_schema>.xslt (portal_id);

ALTER TABLE <misp2_schema>.portal_name ADD CONSTRAINT fk_portal_name_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_portal_name_portal ON <misp2_schema>.portal_name (portal_id);

ALTER TABLE <misp2_schema>.person ADD CONSTRAINT fk_last_portal_portal FOREIGN KEY (last_portal) REFERENCES <misp2_schema>.portal (id) ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX in_last_portal_portal ON <misp2_schema>.person (last_portal);

ALTER TABLE <misp2_schema>.xroad_instance ADD CONSTRAINT fk_xroad_instance_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_xroad_instance_portal ON <misp2_schema>.xroad_instance (portal_id);

ALTER TABLE <misp2_schema>.portal_eula ADD CONSTRAINT fk_portal_eula_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
-- Index in_uq_eula_portal_id_lang applies to foreign key fk_portal_eula_portal

ALTER TABLE <misp2_schema>.person_eula ADD CONSTRAINT fk_person_eula_person FOREIGN KEY (person_id) REFERENCES <misp2_schema>.person (id) ON DELETE CASCADE ON UPDATE CASCADE;
-- Index in_uq_person_eula_person_id_portal_id applies to foreign key fk_person_eula_person   

ALTER TABLE <misp2_schema>.person_eula ADD CONSTRAINT fk_person_eula_portal FOREIGN KEY (portal_id) REFERENCES <misp2_schema>.portal (id) ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX in_person_eula_portal ON <misp2_schema>.person_eula (portal_id);
