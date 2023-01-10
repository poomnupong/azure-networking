#!/bin/bash

sudo apt-get update
sudo apt-get upgrade -y

# install frr
sudo apt-get install frr -y
sudo sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons
sudo touch /etc/frr/bgpd.conf
sudo chown frr /etc/frr/bgpd.conf
sudo chmod 640 /etc/frr/bgpd.conf
sudo systemctl enable frr --now