#!/bin/bash

cd fib/

sudo kubectl apply -f 1_kubernetes/fib.yaml
sleep 15

greymatter create cluster < 2_sidecar/cluster.json
greymatter create domain < 2_sidecar/domain.json
greymatter create listener < 2_sidecar/listener.json
greymatter create shared_rules < 2_sidecar/shared_rules.json
greymatter create route < 2_sidecar/route.json
greymatter create proxy < 2_sidecar/proxy.json

greymatter create cluster < 3_edge/fib-cluster.json
greymatter create shared_rules < 3_edge/fib-shared_rules.json
greymatter create route < 3_edge/fib-route.json
greymatter create route < 3_edge/fib-route-2.json

curl -XPOST https://$GREYMATTER_API_HOST/services/catalog/latest/clusters --cert $GREYMATTER_API_SSLCERT --key $GREYMATTER_API_SSLKEY -k -d "@4_catalog/entry.json"
