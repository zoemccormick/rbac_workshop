#!/bin/bash

sudo mkdir /etc/ssl/quickstart
sudo mv certs/ /etc/ssl/quickstart/certs

chmod +x greymatter
sudo mv greymatter /usr/local/bin/greymatter