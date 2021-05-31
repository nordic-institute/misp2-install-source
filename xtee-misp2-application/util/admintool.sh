#!/bin/bash

java -Djava.security.egd=file:///dev/urandom -jar /usr/xtee/app/AdminTool.jar -config /var/lib/tomcat8/webapps/APP_NAME/WEB-INF/classes/config.cfg "$1" "$2"
