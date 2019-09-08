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

Build the Docker image 
docker build -t hunger/docker2helm:latest .
which will make it available in your local Docker registry.

# 03-Running our app with linked DB (using Docker Compose)


Prerequisites

Docker Compose: 1.17.1

Docker

Created a docker-compose.yml as below:

``` yaml

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

```


Run our app and the Postgresql container

sudo  docker-compose up  

or 

sudo docker-compose -f docker-compose.yml up

make sure you have build your own image before running the above 

i.e: docker build -t hunger/docker2helm:latest .



# 04-k8s & helm

### Prerequisite:

- k8
- docker
- helm
- kubelet
- nginx-controller 


### Mandatory :

### Nginx Ingress Controller

NGINX Ingress controller can be installed via Helm using the chart stable/nginx-ingress from the official charts repository. 

To install the chart with the release name my-nginx:

helm install stable/nginx-ingress --name my-nginx

If the kubernetes cluster has RBAC enabled, then run:

helm install stable/nginx-ingress --name my-nginx --set rbac.create=true

Detect installed version:

POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- /nginx-ingress-controller --version



We want to get a postgres DB running in our k8s cluster. Helm already has a postgres chart that we can use.. and setup to our own needs by overriding settings applicable to us. The repo for Helm Stable charts is at: https://github.com/helm/charts/tree/master/stable/postgresql

Within the repo under the scripts folder, i have created install scripts for this helm chart. Basically what they are doing is:

- took a copy of the values.yml from the above mentioned repo. and customised it so that I could set the values for: postgresqlUsername, postgresqlPassword and postgresqlDatabase as well as the initdbScripts

```yaml
postgresql:
  postgresqlUsername: postgresHelm
  postgresqlPassword: postgresHelm
  postgresqlDatabase: postgresHelmDB
initdbScripts:
  db-init.sql: |
    create sequence hibernate_sequence start with 1 increment by 1;
    create table greeting (id bigint not null, say varchar(255), primary key (id));
    insert into greeting(id,say) values(1,'Hello Hunger Station');
    insert into greeting(id,say) values(2,'Hunger Station,What's New In Catalog Today');
    insert into greeting(id,say) values(3,'Howdy! Hunger Station ');
    insert into greeting(id,say) values(4,'Howdy, Hunger Station ');

```


We want to mount our own config to the Spring Boot container. To do this we need to change the deployment.yaml to include a mounted volume for our config. First create a configuration.yaml(configmap) file in the templates folder with the following::

```yaml
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
        
   ```
        
This creates a ConfigMap for k8s, and pushes in our application.yml that will later be used by our Spring Boot application. See the .Values.configuration.spring.datasource.url is matching the values.yaml where we added our Spring related settings.


To install this chart

we will need to add the stable helm repo and  
helm dependency update ./helm/docker-2-helm-full/

Then we can install the chart using 
helm install --name docker-2-helm ./helm/docker-2-helm-full/

# NOTE : 
- Include a host entry in your hosts file (edit /etc/hosts) for hunger-2-helm.local the name given to the k8s ingress to your application in the values.yaml of helm chart , IP is the kubernetes master ip.



# Script to Bringup The app using docker-compose 
### Script Name : hunger_docker_compose.sh

Steps for building and running the application using docker-compose

### To Install the pre-requisites 

$ ./hunger_docker_compose.sh

### To Build the application

$ ./hunger_docker_compose.sh hunger build 



### to Run the application

$ ./hunger_docker_compose.sh hunger up


### To bring down the application 
$./hunger_docker_compose.sh hunger down 


# Script to Bringup the environment in kubernetes cluster using Custom Helm chart

### Script name : hunger_helm_launch.sh

### To install pre-requisites 

$ ./hunger_helm_launch.sh

### to bring up the application

$ ./hunger_helm_launch.sh hunger up

### to bring down the application

$ ./hunger_helm_launch.sh hunger down


# STATS
-------------------------------------------------------------------------------------------------------------------------

``` go
root@ip-172-31-12-83:~/basic-java-app-2-helm# ./hunger_docker_compose.sh hunger build 
Sending build context to Docker daemon  13.71MB
Step 1/12 : FROM maven:3.5.3-jdk-8-alpine as BUILD
 ---> 562eb2188339
Step 2/12 : WORKDIR /build
 ---> Using cache
 ---> c2c91730278a
Step 3/12 : COPY pom.xml .
 ---> Using cache
 ---> 9c8ae3839454
Step 4/12 : RUN mvn clean
 ---> Using cache
 ---> 5996c0834239
Step 5/12 : RUN mvn compiler:help jar:help resources:help surefire:help clean:help install:help deploy:help site:help dependency:help javadoc:help spring-boot:help
 ---> Using cache
 ---> 4dbfd1497ead
Step 6/12 : RUN mvn dependency:go-offline
 ---> Using cache
 ---> c9296f54b895
Step 7/12 : COPY src/ /build/src/
 ---> Using cache
 ---> 8d66b2656271
Step 8/12 : RUN mvn package
 ---> Using cache
 ---> 5c6e0c1ff851
Step 9/12 : FROM openjdk:8-jre-alpine as APP
 ---> f7a292bbb70c
Step 10/12 : EXPOSE 8080
 ---> Using cache
 ---> ecdbc6004022
Step 11/12 : COPY --from=BUILD /build/target/hunger-helm.jar app.jar
 ---> Using cache
 ---> 7de5497bf003
Step 12/12 : ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
 ---> Using cache
 ---> f66a5f4686a6
Successfully built f66a5f4686a6
Successfully tagged hunger/docker2helm:latest
db uses an image, skipping
adminer uses an image, skipping
Building docker2helm
Step 1/12 : FROM maven:3.5.3-jdk-8-alpine as BUILD
 ---> 562eb2188339
Step 2/12 : WORKDIR /build
 ---> Using cache
 ---> c2c91730278a
Step 3/12 : COPY pom.xml .
 ---> 82a4f86b23d6
Step 4/12 : RUN mvn clean
 ---> Running in f4249696a294
 
 
 
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::        (v2.1.1.RELEASE)

2019-09-07 21:26:08.624  INFO 44 --- [           main] c.e.demo.Docker2HelmApplicationTests     : Starting Docker2HelmApplicationTests on 030ba8d4cf67 with PID 44 (started by root in /build)
2019-09-07 21:26:08.631  INFO 44 --- [           main] c.e.demo.Docker2HelmApplicationTests     : No active profile set, falling back to default profiles: default
2019-09-07 21:26:10.101  INFO 44 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Bootstrapping Spring Data repositories in DEFAULT mode.
2019-09-07 21:26:10.217  INFO 44 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Finished Spring Data repository scanning in 106ms. Found 1 repository interfaces.
2019-09-07 21:26:10.874  INFO 44 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.transaction.annotation.ProxyTransactionManagementConfiguration' of type [org.springframework.transaction.annotation.ProxyTransactionManagementConfiguration$$EnhancerBySpringCGLIB$$f463ff] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2019-09-07 21:26:11.216  INFO 44 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Starting...
2019-09-07 21:26:11.665  INFO 44 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Start completed.
2019-09-07 21:26:11.748  INFO 44 --- [           main] o.hibernate.jpa.internal.util.LogHelper  : HHH000204: Processing PersistenceUnitInfo [
	name: default
	...]
2019-09-07 21:26:11.838  INFO 44 --- [           main] org.hibernate.Version                    : HHH000412: Hibernate Core {5.3.7.Final}
2019-09-07 21:26:11.841  INFO 44 --- [           main] org.hibernate.cfg.Environment            : HHH000206: hibernate.properties not found
2019-09-07 21:26:12.030  INFO 44 --- [           main] o.hibernate.annotations.common.Version   : HCANN000001: Hibernate Commons Annotations {5.0.4.Final}
2019-09-07 21:26:12.219  INFO 44 --- [           main] org.hibernate.dialect.Dialect            : HHH000400: Using dialect: org.hibernate.dialect.H2Dialect
Hibernate: drop table greeting if exists
Hibernate: drop sequence if exists hibernate_sequence
Hibernate: create sequence hibernate_sequence start with 1 increment by 1
Hibernate: create table greeting (id bigint not null, say varchar(255), primary key (id))
2019-09-07 21:26:13.231  INFO 44 --- [           main] o.h.t.schema.internal.SchemaCreatorImpl  : HHH000476: Executing import script 'org.hibernate.tool.schema.internal.exec.ScriptSourceInputNonExistentImpl@3e03046d'
2019-09-07 21:26:13.236  INFO 44 --- [           main] j.LocalContainerEntityManagerFactoryBean : Initialized JPA EntityManagerFactory for persistence unit 'default'
2019-09-07 21:26:14.471  INFO 44 --- [           main] o.s.s.concurrent.ThreadPoolTaskExecutor  : Initializing ExecutorService 'applicationTaskExecutor'
2019-09-07 21:26:14.541  WARN 44 --- [           main] aWebConfiguration$JpaWebMvcConfiguration : spring.jpa.open-in-view is enabled by default. Therefore, database queries may be performed during view rendering. Explicitly configure spring.jpa.open-in-view to disable this warning
2019-09-07 21:26:15.743  INFO 44 --- [           main] o.s.b.a.e.web.EndpointLinksResolver      : Exposing 2 endpoint(s) beneath base path '/actuator'
2019-09-07 21:26:15.842  INFO 44 --- [           main] c.e.demo.Docker2HelmApplicationTests     : Started Docker2HelmApplicationTests in 7.967 seconds (JVM running for 9.137)
[INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 8.823 s - in com.example.demo.Docker2HelmApplicationTests
2019-09-07 21:26:15.972  INFO 44 --- [       Thread-6] o.s.s.concurrent.ThreadPoolTaskExecutor  : Shutting down ExecutorService 'applicationTaskExecutor'
2019-09-07 21:26:16.006  INFO 44 --- [       Thread-6] j.LocalContainerEntityManagerFactoryBean : Closing JPA EntityManagerFactory for persistence unit 'default'
2019-09-07 21:26:16.007  INFO 44 --- [       Thread-6] .SchemaDropperImpl$DelayedDropActionImpl : HHH000477: Starting delayed evictData of schema as part of SessionFactory shut-down'
Hibernate: drop table greeting if exists
Hibernate: drop sequence if exists hibernate_sequence
2019-09-07 21:26:16.101  INFO 44 --- [       Thread-6] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown initiated...
2019-09-07 21:26:16.133  INFO 44 --- [       Thread-6] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown completed.
[INFO] 
[INFO] Results:
[INFO] 
[INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
[INFO] 
[INFO] 
[INFO] --- maven-jar-plugin:3.1.0:jar (default-jar) @ basic-java-app-2-helm ---
[INFO] Building jar: /build/target/hunger-helm.jar
[INFO] 
[INFO] --- spring-boot-maven-plugin:2.1.1.RELEASE:repackage (repackage) @ basic-java-app-2-helm ---
[INFO] Replacing main artifact with repackaged archive
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time: 15.763 s
[INFO] Finished at: 2019-09-07T21:26:17Z
[INFO] ------------------------------------------------------------------------
Removing intermediate container 030ba8d4cf67
 ---> 46dd52280563
Step 9/12 : FROM openjdk:8-jre-alpine as APP
 ---> f7a292bbb70c
Step 10/12 : EXPOSE 8080
 ---> Using cache
 ---> ecdbc6004022
Step 11/12 : COPY --from=BUILD /build/target/hunger-helm.jar app.jar
 ---> 7c9e28fd0e39
Step 12/12 : ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
 ---> Running in 8c479b33fd0f
Removing intermediate container 8c479b33fd0f
 ---> 7873e1d07bca
Successfully built 7873e1d07bca
Successfully tagged hunger/docker2helm:latest


```

``` go
root@ip-172-31-12-83:~/basic-java-app-2-helm# ./hunger_docker_compose.sh hunger up
Creating network "basic-java-app-2-helm_default" with the default driver
Pulling db (postgres:9.6.9)...
9.6.9: Pulling from library/postgres
be8881be8156: Pull complete
bcc05f43b4de: Pull complete
78c4cc9b5f06: Pull complete
d45b5ac60cd5: Pull complete
67f823cf5f8b: Pull complete
0626c6149c90: Pull complete
e25dcd1f62ca: Pull complete
c3c9ac2352c5: Pull complete
b0c2f7780de2: Pull complete
1cd39ae8e6f8: Pull complete
3945b9fc0c53: Pull complete
2bff6467ae03: Pull complete
e3e21dfd259c: Pull complete
0c30f6cc3676: Pull complete
Pulling adminer (adminer:)...
latest: Pulling from library/adminer
9d48c3bd43c5: Pull complete
4bf02c0a37c8: Pull complete
9ce49f939c6f: Pull complete
2fa33c09831c: Pull complete
113619c0d281: Pull complete
81b3f149ce20: Pull complete
3c094da6b6a5: Pull complete
2840f8ed2a6f: Pull complete
713f7780ded2: Pull complete
6996efb28816: Pull complete
dffda6d7cede: Pull complete
c488b6fd8f5b: Pull complete
4d90e6179326: Pull complete
c3450bea6ebf: Pull complete
d44f11135653: Pull complete
d1847aa19b84: Pull complete
Creating basic-java-app-2-helm_adminer_1_14d22f876a9f     ... done
Creating basic-java-app-2-helm_db_1_123e28afe24c      ... done
Creating basic-java-app-2-helm_docker2helm_1_cd94488bb2b4 ... done

                      Name                                    Command               State           Ports         
------------------------------------------------------------------------------------------------------------------
basic-java-app-2-helm_adminer_1_418fe43422ec       entrypoint.sh docker-php-e ...   Up      0.0.0.0:8081->8080/tcp
basic-java-app-2-helm_db_1_36ae017e29ba            docker-entrypoint.sh postgres    Up      0.0.0.0:5433->5432/tcp
basic-java-app-2-helm_docker2helm_1_5a975e0140db   java -Djava.security.egd=f ...   Up      0.0.0.0:8080->8080/tcp

root@ip-172-31-12-83:~/basic-java-app-2-helm# ./hunger_docker_compose.sh hunger down
Stopping basic-java-app-2-helm_docker2helm_1_5a975e0140db ... done
Stopping basic-java-app-2-helm_db_1_36ae017e29ba          ... done
Stopping basic-java-app-2-helm_adminer_1_418fe43422ec     ... done
Removing basic-java-app-2-helm_docker2helm_1_5a975e0140db ... done
Removing basic-java-app-2-helm_db_1_36ae017e29ba          ... done
Removing basic-java-app-2-helm_adminer_1_418fe43422ec     ... done
Removing network basic-java-app-2-helm_default

Name   Command   State   Ports
------------------------------

```


``` go
root@ip-172-31-12-83:~/basic-java-app-2-helm# ./hunger_helm_launch.sh hunger up
Sending build context to Docker daemon  13.71MB
Step 1/12 : FROM maven:3.5.3-jdk-8-alpine as BUILD
 ---> 562eb2188339
Step 2/12 : WORKDIR /build
 ---> Using cache
 ---> c2c91730278a
Step 3/12 : COPY pom.xml .
 ---> Using cache
 ---> 9c8ae3839454
Step 4/12 : RUN mvn clean
 ---> Using cache
 ---> 5996c0834239
Step 5/12 : RUN mvn compiler:help jar:help resources:help surefire:help clean:help install:help deploy:help site:help dependency:help javadoc:help spring-boot:help
 ---> Using cache
 ---> 4dbfd1497ead
Step 6/12 : RUN mvn dependency:go-offline
 ---> Using cache
 ---> c9296f54b895
Step 7/12 : COPY src/ /build/src/
 ---> Using cache
 ---> 8d66b2656271
Step 8/12 : RUN mvn package
 ---> Using cache
 ---> 5c6e0c1ff851
Step 9/12 : FROM openjdk:8-jre-alpine as APP
 ---> f7a292bbb70c
Step 10/12 : EXPOSE 8080
 ---> Using cache
 ---> ecdbc6004022
Step 11/12 : COPY --from=BUILD /build/target/hunger-helm.jar app.jar
 ---> Using cache
 ---> 7de5497bf003
Step 12/12 : ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
 ---> Using cache
 ---> f66a5f4686a6
Successfully built f66a5f4686a6
Successfully tagged hunger/docker2helm:latest
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Downloading postgresql from repo https://kubernetes-charts.storage.googleapis.com
Deleting outdated charts
NAME: hunger-2-helm
LAST DEPLOYED: 2019-09-07 21:13:35.051193269 +0000 UTC m=+0.078046331
NAMESPACE: default
STATUS: deployed
NOTES:
1. Get the application URL by running these commands:
  http://hunger-helm.local/

root@ip-172-31-12-83:~/basic-java-app-2-helm# ./hunger_helm_launch.sh images
REPOSITORY                                                       TAG                  IMAGE ID            CREATED             SIZE
hunger/docker2helm                                               latest               f66a5f4686a6        3 hours ago         123MB
<none>                                                           <none>               5c6e0c1ff851        3 hours ago         262MB
<none>                                                           <none>               e9a83cec18bf        3 hours ago         123MB
<none>                                                           <none>               d1099e400225        3 hours ago         262MB
bitnami/minideb                                                  latest               f6ff062cc163        21 hours ago        67.5MB
<none>                                                           <none>               21766087302b        42 hours ago        123MB
bitnami/minideb                                                  <none>               a467a4d1cfd4        45 hours ago        67.5MB
melissapalmer/docker2helm                                        latest               ba5929cf300f        2 days ago          123MB
bitnami/minideb                                                  <none>               36a04c0a66d3        2 days ago          67.5MB
<none>                                                           <none>               73b3018fee0e        3 days ago          224MB
quay.io/kubernetes-ingress-controller/nginx-ingress-controller   0.25.1               0439eb3e11f1        3 weeks ago         511MB
k8s.gcr.io/kube-scheduler                                        v1.15.2              88fa9cb27bd2        4 weeks ago         81.1MB
k8s.gcr.io/kube-proxy                                            v1.15.2              167bbf6c9338        4 weeks ago         82.4MB
k8s.gcr.io/kube-apiserver                                        v1.15.2              34a53be6c9a7        4 weeks ago         207MB
k8s.gcr.io/kube-controller-manager                               v1.15.2              9f5df470155d        4 weeks ago         159MB
quay.io/kubernetes-ingress-controller/nginx-ingress-controller   0.25.0               02149b6f439f        2 months ago        508MB
openjdk                                                          8-jre-alpine         f7a292bbb70c        3 months ago        84.9MB
bitnami/postgresql                                               10.6.0               c241e64af7d6        6 months ago        191MB
k8s.gcr.io/kube-addon-manager                                    v9.0                 119701e77cbc        7 months ago        83.1MB
k8s.gcr.io/coredns                                               1.3.1                eb516548c180        7 months ago        40.3MB
k8s.gcr.io/kubernetes-dashboard-amd64                            v1.10.1              f9aed6605b81        8 months ago        122MB
k8s.gcr.io/etcd                                                  3.3.10               2c4adeb21b4f        9 months ago        258MB
maven                                                            3.5.3-jdk-8-alpine   562eb2188339        14 months ago       119MB
k8s.gcr.io/pause                                                 3.1                  da86e6ba6ca1        20 months ago       742kB
gcr.io/k8s-minikube/storage-provisioner                          v1.8.1               4689081edb10        22 months ago       80.8MB

root@ip-172-31-12-83:~/basic-java-app-2-helm# ./hunger_helm_launch.sh status
CONTAINER ID        IMAGE                                                            COMMAND                  CREATED              STATUS                          PORTS                                                                NAMES
fc777636a63d        f66a5f4686a6                                                     "java -Djava.securit…"   About a minute ago   Up About a minute                                                                                    k8s_hunger-helm_hunger-2-helm-hunger-helm-74b54674b5-b677g_default_a5fc7fa8-8539-40ea-a007-21afa4e8f920_1
3fa8b46a830c        bitnami/postgresql                                               "/app-entrypoint.sh …"   About a minute ago   Up About a minute                                                                                    k8s_hunger-2-helm-postgresql_hunger-2-helm-postgresql-0_default_1279353e-a846-4ce7-a730-17c86466f79b_0
eae003d435d7        bitnami/minideb                                                  "sh -c 'chown -R 100…"   About a minute ago   Exited (0) About a minute ago                                                                        k8s_init-chmod-data_hunger-2-helm-postgresql-0_default_1279353e-a846-4ce7-a730-17c86466f79b_0
92727822f9ca        f66a5f4686a6                                                     "java -Djava.securit…"   About a minute ago   Exited (1) About a minute ago                                                                        k8s_hunger-helm_hunger-2-helm-hunger-helm-74b54674b5-b677g_default_a5fc7fa8-8539-40ea-a007-21afa4e8f920_0
9d6b3ff3fbdf        k8s.gcr.io/pause:3.1                                             "/pause"                 About a minute ago   Up About a minute                                                                                    k8s_POD_hunger-2-helm-postgresql-0_default_1279353e-a846-4ce7-a730-17c86466f79b_0
8e9a807e7e6f        k8s.gcr.io/pause:3.1                                             "/pause"                 About a minute ago   Up About a minute                                                                                    k8s_POD_hunger-2-helm-hunger-helm-74b54674b5-b677g_default_a5fc7fa8-8539-40ea-a007-21afa4e8f920_0
9868fd3953ad        quay.io/kubernetes-ingress-controller/nginx-ingress-controller   "/usr/bin/dumb-init …"   43 hours ago         Up 43 hours                                                                                          k8s_nginx-ingress-controller_nginx-ingress-controller-5d9cf9c69f-7ktnl_kube-system_3df2a6f9-244a-4710-98c1-19349740db01_0
5f586441d6bc        k8s.gcr.io/pause:3.1                                             "/pause"                 43 hours ago         Up 43 hours                     0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 0.0.0.0:18080->18080/tcp   k8s_POD_nginx-ingress-controller-5d9cf9c69f-7ktnl_kube-system_3df2a6f9-244a-4710-98c1-19349740db01_0
7498122a8691        quay.io/kubernetes-ingress-controller/nginx-ingress-controller   "/usr/bin/dumb-init …"   43 hours ago         Up 43 hours                                                                                          k8s_nginx-ingress-controller_nginx-ingress-controller-79f6884cf6-jls8h_ingress-nginx_85c536e9-0748-49e1-a253-76433c32fdf1_0
27f88f9e1f6e        k8s.gcr.io/pause:3.1                                             "/pause"                 43 hours ago         Up 43 hours                                                                                          k8s_POD_nginx-ingress-controller-79f6884cf6-jls8h_ingress-nginx_85c536e9-0748-49e1-a253-76433c32fdf1_0
782dbe22306e        f9aed6605b81                                                     "/dashboard --insecu…"   2 days ago           Up 2 days                                                                                            k8s_kubernetes-dashboard_kubernetes-dashboard-7b8ddcb5d6-6h7tl_kube-system_74da02b9-889d-41e1-877e-776fce47b6bb_7
a909b917fd72        4689081edb10                                                     "/storage-provisioner"   2 days ago           Up 2 days                                                                                            k8s_storage-provisioner_storage-provisioner_kube-system_51178133-8fc3-4edc-8493-7f8a5504a7bc_2
7c40beba3a06        f9aed6605b81                                                     "/dashboard --insecu…"   2 days ago           Exited (1) 2 days ago                                                                                k8s_kubernetes-dashboard_kubernetes-dashboard-7b8ddcb5d6-6h7tl_kube-system_74da02b9-889d-41e1-877e-776fce47b6bb_6
bcf51e0763b5        eb516548c180                                                     "/coredns -conf /etc…"   2 days ago           Up 2 days                                                                                            k8s_coredns_coredns-5c98db65d4-fdr8q_kube-system_e46a9754-678e-4ac5-9b82-ef380e1c6b51_1
1d8c80c0e82a        eb516548c180                                                     "/coredns -conf /etc…"   2 days ago           Up 2 days                                                                                            k8s_coredns_coredns-5c98db65d4-wfk6g_kube-system_6a23e426-9008-4f4b-8940-ecd91c91561a_1
c899dc933fea        167bbf6c9338                                                     "/usr/local/bin/kube…"   2 days ago           Up 2 days                                                                                            k8s_kube-proxy_kube-proxy-w9s6f_kube-system_0a754a59-4256-4fba-af84-a667be338357_1
77c45d872660        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_kubernetes-dashboard-7b8ddcb5d6-6h7tl_kube-system_74da02b9-889d-41e1-877e-776fce47b6bb_1
455300b254e8        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_coredns-5c98db65d4-fdr8q_kube-system_e46a9754-678e-4ac5-9b82-ef380e1c6b51_1
07610fbe518e        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_kube-proxy-w9s6f_kube-system_0a754a59-4256-4fba-af84-a667be338357_1
772871ee50f6        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_coredns-5c98db65d4-wfk6g_kube-system_6a23e426-9008-4f4b-8940-ecd91c91561a_1
eb0202ef0163        4689081edb10                                                     "/storage-provisioner"   2 days ago           Exited (1) 2 days ago                                                                                k8s_storage-provisioner_storage-provisioner_kube-system_51178133-8fc3-4edc-8493-7f8a5504a7bc_1
9f4e31f9efb4        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_storage-provisioner_kube-system_51178133-8fc3-4edc-8493-7f8a5504a7bc_1
ee8bc9ab0b41        2c4adeb21b4f                                                     "etcd --advertise-cl…"   2 days ago           Up 2 days                                                                                            k8s_etcd_etcd-minikube_kube-system_eb4a391d58c17412163ba10527fa63ac_0
67fac95bc141        34a53be6c9a7                                                     "kube-apiserver --ad…"   2 days ago           Up 2 days                                                                                            k8s_kube-apiserver_kube-apiserver-minikube_kube-system_0381b03a9b74e85a645f0cfc106983dc_0
1351c75d70dc        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_etcd-minikube_kube-system_eb4a391d58c17412163ba10527fa63ac_0
7f6dbca6b5de        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_kube-apiserver-minikube_kube-system_0381b03a9b74e85a645f0cfc106983dc_0
1307db65c967        9f5df470155d                                                     "kube-controller-man…"   2 days ago           Up 2 days                                                                                            k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_5c39844f0b908333a05ae0c6cec35511_5
35edc6893099        119701e77cbc                                                     "/opt/kube-addons.sh"    2 days ago           Up 2 days                                                                                            k8s_kube-addon-manager_kube-addon-manager-minikube_kube-system_65a31d2b812b11a2035f37c8a742e46f_1
90beb9c8dc02        88fa9cb27bd2                                                     "kube-scheduler --bi…"   2 days ago           Up 2 days                                                                                            k8s_kube-scheduler_kube-scheduler-minikube_kube-system_abfcb4f52e957b11256c1f6841d49700_4
bdf5ddac2343        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_kube-addon-manager-minikube_kube-system_65a31d2b812b11a2035f37c8a742e46f_1
7efdfd80724d        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_kube-scheduler-minikube_kube-system_abfcb4f52e957b11256c1f6841d49700_1
913662af0788        k8s.gcr.io/pause:3.1                                             "/pause"                 2 days ago           Up 2 days                                                                                            k8s_POD_kube-controller-manager-minikube_kube-system_5c39844f0b908333a05ae0c6cec35511_1
e73d84c75fba        73b3018fee0e                                                     "/bin/sh -c 'mvn pac…"   2 days ago           Exited (255) 2 days ago                                                                              clever_kirch
18114e50916b        88fa9cb27bd2                                                     "kube-scheduler --bi…"   2 days ago           Exited (1) 2 days ago                                                                                k8s_kube-scheduler_kube-scheduler-minikube_kube-system_abfcb4f52e957b11256c1f6841d49700_3
9bb4a177aacf        9f5df470155d                                                     "kube-controller-man…"   2 days ago           Exited (255) 2 days ago                                                                              k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_5c39844f0b908333a05ae0c6cec35511_4
a23734ba338a        eb516548c180                                                     "/coredns -conf /etc…"   3 days ago           Exited (255) 2 days ago                                                                              k8s_coredns_coredns-5c98db65d4-wfk6g_kube-system_6a23e426-9008-4f4b-8940-ecd91c91561a_0
2e94ac3aea9d        eb516548c180                                                     "/coredns -conf /etc…"   3 days ago           Exited (255) 2 days ago                                                                              k8s_coredns_coredns-5c98db65d4-fdr8q_kube-system_e46a9754-678e-4ac5-9b82-ef380e1c6b51_0
4d9112818151        167bbf6c9338                                                     "/usr/local/bin/kube…"   3 days ago           Exited (255) 2 days ago                                                                              k8s_kube-proxy_kube-proxy-w9s6f_kube-system_0a754a59-4256-4fba-af84-a667be338357_0
443a08d82345        k8s.gcr.io/pause:3.1                                             "/pause"                 3 days ago           Exited (255) 2 days ago                                                                              k8s_POD_coredns-5c98db65d4-fdr8q_kube-system_e46a9754-678e-4ac5-9b82-ef380e1c6b51_0
4386dac1b953        k8s.gcr.io/pause:3.1                                             "/pause"                 3 days ago           Exited (255) 2 days ago                                                                              k8s_POD_coredns-5c98db65d4-wfk6g_kube-system_6a23e426-9008-4f4b-8940-ecd91c91561a_0
6aa07fa2b6a0        k8s.gcr.io/pause:3.1                                             "/pause"                 3 days ago           Exited (255) 2 days ago                                                                              k8s_POD_kube-proxy-w9s6f_kube-system_0a754a59-4256-4fba-af84-a667be338357_0
ea62b76cdda0        119701e77cbc                                                     "/opt/kube-addons.sh"    3 days ago           Exited (255) 2 days ago                                                                              k8s_kube-addon-manager_kube-addon-manager-minikube_kube-system_65a31d2b812b11a2035f37c8a742e46f_0
483e16ed4150        k8s.gcr.io/pause:3.1                                             "/pause"                 3 days ago           Exited (255) 2 days ago                                                                              k8s_POD_kube-scheduler-minikube_kube-system_abfcb4f52e957b11256c1f6841d49700_0
b195f168bc5b        k8s.gcr.io/pause:3.1                                             "/pause"                 3 days ago           Exited (255) 2 days ago                                                                              k8s_POD_kube-controller-manager-minikube_kube-system_5c39844f0b908333a05ae0c6cec35511_0
d8d607d0eae6        k8s.gcr.io/pause:3.1                                             "/pause"                 3 days ago           Exited (255) 2 days ago                                                                              k8s_POD_kube-addon-manager-minikube_kube-system_65a31d2b812b11a2035f37c8a742e46f_0

```

 ### Application Working Status Check 
``` go
###Health EndPoint:

root@ip-172-31-12-83:~/new/HS_Assignemnt# curl http://hunger-2-helm.local/actuator/health
{"status":"UP"}

###DB query EndPoint

root@ip-172-31-12-83:~/new/curl http://hunger-2-helm.local/hello
{"say":"Hi Hunger Station ,I'm hungry on IP: 172.17.0.5"}

```

### Known Issues and Fixes 

There were a couple issues with the Helm Chart initdbScripts field ,if application container keep on crashing due to missing greetins table , then we need to re-run the initdbScripts located at /docker-entrypoint-initdb.d/db-init.sql inside postgresql container

``` go
$psql -U postgresHelm -d postgresHelmDB -a -f /docker-entrypoint-initdb.d/db-init.sql

```

### Exception at container launch :

``` go

2019-09-06 03:02:02.166  INFO 1 --- [           main] org.hibernate.type.BasicTypeRegistry     : HHH000270: Type registration [java.util.UUID] overrides previous : org.hibernate.type.UUIDBinaryType@4f25b795
2019-09-06 03:02:02.991  WARN 1 --- [           main] ConfigServletWebServerApplicationContext : Exception encountered during context initialization - cancelling refresh attempt: org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'entityManagerFactory' defined in class path resource [org/springframework/boot/autoconfigure/orm/jpa/HibernateJpaConfiguration.class]: Invocation of init method failed; nested exception is javax.persistence.PersistenceException: [PersistenceUnit: default] Unable to build Hibernate SessionFactory; nested exception is org.hibernate.tool.schema.spi.SchemaManagementException: Schema-validation: missing table [greeting]
2019-09-06 03:02:02.992  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown initiated...
2019-09-06 03:02:03.005  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown completed.
2019-09-06 03:02:03.007  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Stopping service [Tomcat]
2019-09-06 03:02:03.033  INFO 1 --- [           main] ConditionEvaluationReportLoggingListener : 

Error starting ApplicationContext. To display the conditions report re-run your application with 'debug' enabled.
2019-09-06 03:02:03.035 ERROR 1 --- [           main] o.s.boot.SpringApplication               : Application run failed

org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'entityManagerFactory' defined in class path resource [org/springframework/boot/autoconfigure/orm/jpa/HibernateJpaConfiguration.class]: Invocation of init method failed; nested exception is javax.persistence.PersistenceException: [PersistenceUnit: default] Unable to build Hibernate SessionFactory; nested exception is org.hibernate.tool.schema.spi.SchemaManagementException: Schema-validation: missing table [greeting]




Caused by: javax.persistence.PersistenceException: [PersistenceUnit: default] Unable to build Hibernate SessionFactory; nested exception is org.hibernate.tool.schema.spi.SchemaManagementException: Schema-validation: missing table [greeting]
	at org.springframework.orm.jpa.AbstractEntityManagerFactoryBean.buildNativeEntityManagerFactory(AbstractEntityManagerFactoryBean.java:402) ~[spring-orm-5.1.3.RELEASE.jar!/:5.1.3.RELEASE]
	at org.springframework.orm.jpa.AbstractEntityManagerFactoryBean.afterPropertiesSet(AbstractEntityManagerFactoryBean.java:377) ~[spring-orm-5.1.3.RELEASE.jar!/:5.1.3.RELEASE]
	at org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean.afterPropertiesSet(LocalContainerEntityManagerFactoryBean.java:341) ~[spring-orm-5.1.3.RELEASE.jar!/:5.1.3.RELEASE]
	at org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.invokeInitMethods(AbstractAutowireCapableBeanFactory.java:1804) ~[spring-beans-5.1.3.RELEASE.jar!/:5.1.3.RELEASE]
	at org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.initializeBean(AbstractAutowireCapableBeanFactory.java:1741) ~[spring-beans-5.1.3.RELEASE.jar!/:5.1.3.RELEASE]
	... 24 common frames omitted
Caused by: org.hibernate.tool.schema.spi.SchemaManagementException: Schema-validation: missing table [greeting]
	at org.hibernate.tool.schema.internal.AbstractSchemaValidator.validateTable(AbstractSchemaValidator.java:121) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.tool.schema.internal.GroupedSchemaValidatorImpl.validateTables(GroupedSchemaValidatorImpl.java:42) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.tool.schema.internal.AbstractSchemaValidator.performValidation(AbstractSchemaValidator.java:89) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.tool.schema.internal.AbstractSchemaValidator.doValidation(AbstractSchemaValidator.java:68) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.tool.schema.spi.SchemaManagementToolCoordinator.performDatabaseAction(SchemaManagementToolCoordinator.java:191) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.tool.schema.spi.SchemaManagementToolCoordinator.process(SchemaManagementToolCoordinator.java:72) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.internal.SessionFactoryImpl.<init>(SessionFactoryImpl.java:310) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.boot.internal.SessionFactoryBuilderImpl.build(SessionFactoryBuilderImpl.java:467) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.hibernate.jpa.boot.internal.EntityManagerFactoryBuilderImpl.build(EntityManagerFactoryBuilderImpl.java:939) ~[hibernate-core-5.3.7.Final.jar!/:5.3.7.Final]
	at org.springframework.orm.jpa.vendor.SpringHibernateJpaPersistenceProvider.createContainerEntityManagerFactory(SpringHibernateJpaPersistenceProvider.java:57) ~[spring-orm-5.1.3.RELEASE.jar!/:5.1.3.RELEASE]
	at org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean.createNativeEntityManagerFactory(LocalContainerEntityManagerFactoryBean.java:365) ~[spring-orm-5.1.3.RELEASE.jar!/:5.1.3.RELEASE]
	at org.springframework.orm.jpa.AbstractEntityManagerFactoryBean.buildNativeEntityManagerFactory(AbstractEntityManagerFactoryBean.java:390) 
	
```


