#!/bin/bash
# Setup my hunger  environemt
pn=muzzu_tweak

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Run this section if docker is not installed
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# check for pre-reqs
if [ ! -x "$(which docker)" ]; then
     
    echo Check/Installing docker
    
     [ ! -x "$(which docker)" ] && yum install -y docker && service docker start
    
  # Now lets get docker compose
    echo Check/Installing docker-compose
    dc=$(which docker-compose)

    if [ $? -ne 0 ]; then
        curl -L https://github.com/docker/compose/releases/download/1.7.0/docker-compose-`uname -s`-`uname -m` > docker-compose
        chmod +x docker-compose
        sudo mv docker-compose /usr/local/bin/docker-compose
    fi
    echo check/Installing Kubectl
    if [ ! -x "$(which kubectl)" ];then
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    fi
    echo check/Installing Helm
    if [ ! -x "$(which helm)" ]; then
        curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
        wget https://get.helm.sh/helm-v3.0.0-beta.2-linux-amd64.tar.gz && tar -zxvf helm-v2.0.0-linux-amd64.tgz &&  mv linux-amd64/helm /usr/local/bin/helm && helm init && helm repo add stable https://kubernetes-charts.storage.googleapis.com
        minikube start --vm-driver=none
    fi


fi

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# helper functions 

# a little clean up function
cleanup(){
    docker rm $(docker ps --filter status=exited -q 2>/dev/null) 2>/dev/null
    docker rmi $(docker images --filter dangling=true -q 2>/dev/null) 2>/dev/null
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Help 
if [ $# -lt 1 ] || [ "$1" = "help" ]; then
   echo
   echo "$pn usage: command [arg...]"
   echo
   echo "Commands:"
   echo
   echo "hunger      Creates the hunger environment"
   echo "prod       Creates the production environment"
   echo "status     Display the status of the environment"
   echo "test       Quick test - header info only" 
   echo "clean      Removes dangling images and exited containers"
   echo "images     List images"
   echo
   exit
fi 

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# hunger
if [ "$1" = "hunger" ]; then
	if [ $# -lt 2 ]; then
        echo
        echo "usage : $pn $1 [  up | down ]"
    else
            cmd="$2"
            if [ "$2" = "up" ]; then docker build -t hunger/docker2helm . && helm dependency update helm/docker-2-helm-full/ && helm install hunger-2-helm helm-chart/docker-2-helm-full/ ;fi
            if [ "$2" = "down" ]; then helm delete hunger-2-helm ;fi;
    fi
	echo
    exit
fi    	

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# prod
#if [ "$1" = "prod" ]; then
#	if [ $# -lt 2 ]; then
#        echo
#        echo "usage : $pn $1 [ build | up | down ]"
#    else
#        cd $1
#            cmd="$2"
#            if [ "$2" = "up" ]; then cmd="up -d";fi;
#            docker-compose $cmd $3 $4
#            if [ "$2" = "build" ]; then docker build -t hunger/docker2helm ;echo;docker images
#            else echo;docker-compose ps;fi        
#        cd ..
#    fi
#	echo
#    exit
#fi  

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# status
if [ "$1" = "status" ]; then
    env | grep DOCKER
    docker ps -a
	echo;exit
fi      	

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# test
if [ "$1" = "test" ]; then
    echo curl -I -X GET http://localhost/
    curl -I -X GET http://localhost/$2
	echo;exit
fi

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# bench
if [ "$1" = "bench" ]; then
    echo ab -n 1000 -c 10 http://localhost/
    ab -n 1000 -c 10 http://localhost/
	echo;exit
fi
      	
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# images
if [ "$1" = "images" ]; then
    docker images
	echo;exit
fi    	

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# clean
if [ "$1" = "clean" ]; then
	if [ "$2" = "all" ]; then docker rmi $(docker images -q)
    elif [ "$2" = "up" ]; then cleanup
    else
        echo
        echo "usage : $pn clean [ up | all ]";
	fi
	echo;exit;	
fi;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Unknown
echo
(>&2 echo $pn: UNKNOWN COMMAND [\"$1\"])
$0 help
exit
