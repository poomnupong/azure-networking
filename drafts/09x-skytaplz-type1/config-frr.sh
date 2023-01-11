#!/bin/bash

#== load apt cache
sudo apt-get update

#== enable ipv4 forwarding
sudo /usr/bin/sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo /usr/sbin/sysctl -p

#== install frr
echo "== install FRR =="
sudo apt-get install frr -y
sudo sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons
sudo touch /etc/frr/bgpd.conf
sudo chown frr /etc/frr/bgpd.conf
sudo chmod 640 /etc/frr/bgpd.conf
sudo systemctl enable frr --now
sudo systemctl restart frr

#== make sure everything is up to date
sudo apt-get -y --fix-missing upgrade

#== install iptables-persistent
# TODO

# Enable NAT to Internet
iptables -t nat -A POSTROUTING -d 10.0.0.0/8 -j ACCEPT
iptables -t nat -A POSTROUTING -d 172.16.0.0/12 -j ACCEPT
iptables -t nat -A POSTROUTING -d 192.168.0.0/16 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# configure frr
# cat << EOF > /tmp/frr-command.txt
# configure
# router bgp 65099
# write
# EOF
# sudo /usr/bin/vtysh -c /tmp/frr-command.txt
