#!/bin/bash

echo Docker Credentials:
read -p "docker email: " DECIPHER_DOCKER_EMAIL
read -p "docker password: " -s DECIPHER_DOCKER_PASSWORD

export DECIPHER_DOCKER_EMAIL=$DECIPHER_DOCKER_EMAIL
export DECIPHER_DOCKER_USER=$DECIPHER_DOCKER_EMAIL
export DECIPHER_DOCKER_PASSWORD=$DECIPHER_DOCKER_PASSWORD
export NEXUS_USER=$DECIPHER_DOCKER_EMAIL
export NEXUS_PASSWORD=$DECIPHER_DOCKER_PASSWORD