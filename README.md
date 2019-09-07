# HS_Assignemnt


Following core technology are used in stack, during this post:

Spring is an application framework and inversion of control container for the Java platform.
Docker is the container technology that allows you to containerise your applications.
Docker Compose is a tool for defining and running multi-container applications.
Kubernetes (commonly known as K8s) is an open-source container-orchestration system for automating deployment, scaling and management of containerised applications.
Helm is a package manager for K8s, it simplifies the installation of an application and its dependencies into a K8s cluster.



# 01-Creating a Spring Boot Rest API

This application includes:

An endpoint /hello that'll respond with various greetings text sourced from a DB.
Spring Actuator: which exposes health check endpoints  http://localhost:8080/actuator/health

Compiling and Running the app

Build Using ./mvnw clean package
Run Using java -jar target/hunger-2-helm.jar or ./mvnw spring-boot:run



# 02-Containerise It


Prerequisites:
   Docker to be installed 

Build Docker image and Run it

Build the Docker image docker build -t hunger/docker2helm:latest .
which will make it available in your local Docker registry.

# 03-Running our app with linked DB (using Docker Compose)


Prerequisites
Docker Compose: 1.17.1

Docker
Created a docker-compose.yml as below:

version: '3.1'

volumes:
  init.sql: 
  data:
  postgres_data:
    driver: local
  application-container.yml: 

services:
  db:
    image: postgres:9.6.9
    volumes:
    - postgres_data:/var/lib/postgresql/data 
    - ./docker/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
    - "5433:5432"
    environment:
    - POSTGRES_PASSWORD=example
    - POSTGRES_DB=db
    
  adminer:
    image: adminer
    restart: always
    ports:
    - 8081:8080
    
  docker2helm:
    image: hunger/docker2helm
    volumes:
    - ./application-container.yml:/config/application.yml
    restart: always
    ports:
    - 8080:8080
    links:
      - db
    depends_on:
      - db




Run our app and the Postgresql container

sudo  docker-compose up  or sudo docker-compose -f docker-compose.yml up  or
make sure you have build your own image before running the above 
i.e: docker build -t hunger/docker2helm:latest .



# 04-k8s & helm

Prerequisite:
- k8
- docker
- helm
- kubelet
- nginx-controller 


We want to get a postgres DB running in our k8s cluster. Helm already has a postgres chart that we can use.. and setup to our own needs by overriding settings applicable to us. The repo for Helm Stable charts is at: https://github.com/helm/charts/tree/master/stable/postgresql

Within the repo under the scripts folder, i have created install scripts for this helm chart. Basically what they are doing is:

I took a copy of the values.yml from the above mentioned repo. and customised it so that I could set the values for: postgresqlUsername, postgresqlPassword and postgresqlDatabase as well as the initdbScripts

initdbScripts:
  db-init.sql: |
    create sequence hibernate_sequence start with 1 increment by 1;
    create table greeting (id bigint not null, say varchar(255), primary key (id));
    insert into greeting(id,say) values(1,'Hello Hunger Station');
    insert into greeting(id,say) values(2,'Hunger Station,What's New In Catalog Today');
    insert into greeting(id,say) values(3,'Howdy! Hunger Station ');
    insert into greeting(id,say) values(4,'Howdy, Hunger Station ');


We want to mount our own config to the Spring Boot container. To do this we need to change the deployment.yaml to include a mounted volume for our config. First create a configuration.yaml file in the templates folder with the following::

apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "hunger-2-helm.fullname" . }}-configmap
  labels:
    heritage: {{ .Release.Service }}
    release: {{ .Release.Name }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
    app: {{ template "hunger-2-helm.fullname" . }}
data: 
  application.yml: |-
    spring:
      datasource:
        url: {{ .Values.configuration.spring.datasource.url }}
        username: {{ .Values.configuration.spring.datasource.username }}
        password: {{ .Values.configuration.spring.datasource.password }}
        platform: {{ .Values.configuration.spring.datasource.platform }}
      jpa:
        show-sql: {{ .Values.configuration.spring.jpa.showsql }}
        generate-ddl: {{ .Values.configuration.spring.jpa.generateddl }}
        hibernate.ddl-auto: {{ .Values.configuration.spring.jpa.hibernateddlauto }}
        
This creates a ConfigMap for k8s, and pushes in our application.yml that will later be used by our Spring Boot application. See the .Values.configuration.spring.datasource.url is matching the values.yaml where we added our Spring related settings.


To install this chart

we will need to add the stable helm repo and  
helm dependency update ./helm/docker-2-helm-full/

Then we can install the chart using 
helm install --name docker-2-helm ./helm/docker-2-helm-full/


