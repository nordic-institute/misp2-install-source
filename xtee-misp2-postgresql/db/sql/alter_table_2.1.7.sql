-- update all sequences to correct values
DO $$ 
	DECLARE max_id INTEGER;
BEGIN

	select  max(id) into max_id from misp2.query;
	perform  setval('misp2.query_id_seq', max_id +1 );

	select  max(id) into max_id from misp2.classifier;
	perform  setval('misp2.classifier_id_seq', max_id + 1);
	
	select  max(id) into max_id from misp2.check_register_status;
	perform  setval('misp2.check_register_status_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.group_;
	perform  setval('misp2.group__id_seq', max_id + 1);

	select  max(id) into max_id from misp2.group_item;
	perform  setval('misp2.group_item_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.group_person;
	perform  setval('misp2.group_person_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.manager_candidate;
	perform  setval('misp2.manager_candidate_id_seq', max_id + 1);
	
	select  max(id) into max_id from misp2.news;
	perform  setval('misp2.news_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.org;
	perform  setval('misp2.org_id_seq', max_id + 1);
	
	select  max(id) into max_id from misp2.org_name;
	perform  setval('misp2.org_name_id_seq', max_id + 1);
		
	select  max(id) into max_id from misp2.org_person;
	perform  setval('misp2.org_person_id_seq', max_id + 1);
	
	select  max(id) into max_id from misp2.org_query;
	perform  setval('misp2.org_query_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.org_valid;
	perform  setval('misp2.org_valid_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.person;
	perform  setval('misp2.person_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.producer_name;
	perform  setval('misp2.producer_name_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.producer;
	perform  setval('misp2.producer_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.query_name;
	perform  setval('misp2.query_name_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.query_error_log;
	perform  setval('misp2.query_error_log_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.query_log;
	perform  setval('misp2.query_log_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.t3_sec;
	perform  setval('misp2.t3_sec_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.xforms;
	perform  setval('misp2.xforms_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.xslt;
	perform  setval('misp2.xslt_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.person_mail_org;
	perform  setval('misp2.person_mail_org_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.package;
	perform  setval('misp2.package_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.topic_name;
	perform  setval('misp2.topic_name_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.portal_name;
	perform  setval('misp2.portal_name_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.query_topic;
	perform  setval('misp2.query_topic_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.topic;
	perform  setval('misp2.topic_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.portal;
	perform  setval('misp2.portal_id_seq', max_id + 1);

	select  max(id) into max_id from misp2.admin;
	perform  setval('misp2.admin_id_seq', max_id + 1);
	

	
END $$;