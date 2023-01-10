#!/bin/bash

# load apt cache
sudo apt-get update
sudo apt-get upgrade -y

# enable ipv4 forwarding
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# install frr
sudo apt-get install frr -y
sudo sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons
sudo touch /etc/frr/bgpd.conf
sudo chown frr /etc/frr/bgpd.conf
sudo chmod 640 /etc/frr/bgpd.conf
sudo systemctl enable frr --now
sudo systemctl restart frr

# configure frr
sudo bash -c 'cat << EOF > /root/frr-command.txt
configure
ip route 10.2.27.192/27 10.2.27.52
router bgp 65099
write
EOF'
sudo /usr/bin/vtysh -f /root/frr-command.txt