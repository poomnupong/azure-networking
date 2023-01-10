Enable traffic forwarding in Ubuntu:

# sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 0

# cat /proc/sys/net/ipv4/ip_forward
0

# sysctl -w net.ipv4.ip_forward=1

vi /etc/sysctl.conf
net.ipv4.ip_forward = 1

!=== install frr

routeServerSubnetPrefix="10.2.27.192/27"
bgpNvaSubnetGateway="10.2.27.49"

sudo apt install frr -y
sudo sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons
sudo touch /etc/frr/bgpd.conf
sudo chown frr /etc/frr/bgpd.conf
sudo chmod 640 /etc/frr/bgpd.conf
sudo systemctl enable frr --now

sudo ip route add $routeServerSubnetPrefix via $bgpNvaSubnetGateway dev eth1

!=== configure FRR/bgpd
route-map SET-NEXT-HOP-FW permit 10
set ip next-hop 10.2.27.52
exit
!
router bgp 65027
no bgp ebgp-requires-policy
neighbor 10.2.27.196 remote-as 65515  
neighbor 10.2.27.196 ebgp-multihop 2
neighbor 10.2.27.197 remote-as 65515 
neighbor 10.2.27.197 ebgp-multihop 2
network 0.0.0.0/0
!
address-family ipv4 unicast
  neighbor 10.2.27.196 route-map SET-NEXT-HOP-FW out
  neighbor 10.2.27.197 route-map SET-NEXT-HOP-FW out
exit-address-family

!=== enable SNAT on linux for internet traffic
iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE


