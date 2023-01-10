#!/bin/bash

# load apt cache
sudo apt-get update
sudo apt-get upgrade -y

# enable ipv4 forwarding
sudo /usr/bin/sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo /usr/sbin/sysctl -p

# install frr
sudo apt-get install frr -y
sudo sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons
sudo touch /etc/frr/bgpd.conf
sudo chown frr /etc/frr/bgpd.conf
sudo chmod 640 /etc/frr/bgpd.conf
sudo systemctl enable frr --now
sudo systemctl restart frr

# configure frr
cat << EOF > /tmp/frr-command.txt
configure
router bgp 65099
write
EOF
sudo /usr/bin/vtysh -c /tmp/frr-command.txt
