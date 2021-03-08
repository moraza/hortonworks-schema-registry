FROM openjdk:11

# set corp proxy below (and in m2/settings.xml) if needed
# ENV http_proxy=http://proxy.int.corp.local:8080
# ENV https_proxy=http://proxy.int.corp.local:8080
# ENV no_proxy=localhost,127.0.0.1,.int.corp.local

RUN apt-get update -y && apt-get install -y wget maven gettext-base
RUN mkdir /tmp/HDF

WORKDIR /tmp/HDF

RUN wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.23.tar.gz
RUN wget https://github.com/hortonworks/registry/archive/HDF-3.5.2.3-2-tag.tar.gz

RUN tar xzvf mysql-connector-java-8.0.23.tar.gz
RUN tar xzvf HDF-3.5.2.3-2-tag.tar.gz

WORKDIR registry-HDF-3.5.2.3-2-tag
RUN sed -i s/4.6.1/6.14.11/g webservice/pom.xml
RUN sed -i s/6.11.5/14.16.0/g webservice/pom.xml
RUN mvn package -DskipTests
RUN mv registry-dist/target/hortonworks-registry-0.8.1.tar.gz /opt/

WORKDIR /opt
RUN tar xzvf hortonworks-registry-0.8.1.tar.gz
RUN rm hortonworks-registry-0.8.1.tar.gz
RUN cp /tmp/HDF/mysql-connector-java-8.0.23/mysql-connector-java-8.0.23.jar /opt/hortonworks-registry-0.8.1/libs/mysql-connector-java-8.0.23-bin.jar
RUN cp /tmp/HDF/mysql-connector-java-8.0.23/mysql-connector-java-8.0.23.jar /opt/hortonworks-registry-0.8.1/bootstrap/lib/mysql-connector-java-8.0.23-bin.jar
RUN rm -rf /tmp/HDF
RUN cp hortonworks-registry-0.8.1/conf/registry.yaml hortonworks-registry-0.8.1/conf/registry.yaml.template
RUN sed -i s/com.mysql.jdbc.jdbc2.optional.MysqlDataSource/com.mysql.cj.jdbc.MysqlDataSource/g hortonworks-registry-0.8.1/conf/registry.yaml.template
RUN sed -i "s!jdbc:mysql://localhost/schema_registry!jdbc:mysql://\$DB_HOST:\$DB_PORT/\$DB_NAME!g" hortonworks-registry-0.8.1/conf/registry.yaml.template
RUN sed -i "s/registry_user/\$DB_USER/g" hortonworks-registry-0.8.1/conf/registry.yaml.template
RUN sed -i "s/registry_password/\$DB_PASSWORD/g" hortonworks-registry-0.8.1/conf/registry.yaml.template
RUN ln -s /opt/hortonworks-registry-0.8.1 /opt/hortonworks-registry
RUN groupadd -r hortonworks && useradd --no-log-init -r -g hortonworks hortonworks
COPY entrypoint.sh /opt/hortonworks-registry/entrypoint.sh
COPY wait-for-it.sh /opt/hortonworks-registry/wait-for-it.sh
RUN chown -R hortonworks:hortonworks /opt
RUN chgrp -R 0 /opt && chmod -R g=u /opt
RUN chmod +x /opt/hortonworks-registry/*.sh
RUN chmod +x /opt/hortonworks-registry/bin/*.sh

ENV DB_NAME schema_registry
ENV DB_USER registry_user
ENV DB_PASSWORD registry_password
ENV DB_HOST localhost
ENV DB_PORT 3306

EXPOSE 9090 9091

USER hortonworks

WORKDIR /opt/hortonworks-registry

ENTRYPOINT ["/opt/hortonworks-registry/entrypoint.sh"]

CMD ["/opt/hortonworks-registry/bin/registry-server-start.sh","/opt/hortonworks-registry/conf/registry.yaml"]

