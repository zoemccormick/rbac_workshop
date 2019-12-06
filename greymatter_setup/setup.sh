#!/bin/bash

source ./credsenv.sh

sudo rm -rf minikube-linux-amd64*
sudo minikube delete
sudo snap remove helm
sudo snap remove kubectl
sudo apt-get remove -y docker.io

sudo apt update
sudo apt install docker.io socat -y
sudo snap install kubectl --channel=1.6/stable --classic
wget https://git.io/get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh --version v2.15.2
wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube

sudo minikube start --vm-driver=none --memory 4096 --cpus 4 --kubernetes-version='v1.15.5'

sudo helm init
sleep 45
sudo helm repo add appscode https://charts.appscode.com/stable/
sudo helm repo update
sudo helm install appscode/voyager --name voyager-operator --version 10.0.0 \
  --namespace kube-system \
  --set cloudProvider=minikube \
  --set enableAnalytics=false \
  --set apiserver.enableAdmissionWebhook=false
sleep 45

sudo helm repo add decipher https://nexus.production.deciphernow.com/repository/helm-hosted --username $NEXUS_USER --password $NEXUS_PASSWORD
sudo helm repo update

sudo helm install decipher/greymatter -f custom-greymatter.yaml -f custom-greymatter-secrets.yaml --set global.environment=kubernetes --set global.k8s_use_voyager_ingress=true --name gm


sleep 30
sudo kubectl get pods
sleep 45 
sudo kubectl get pods
sleep 45
sudo kubectl get pods
