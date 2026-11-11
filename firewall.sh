#!/bin/bash
# Applies zero-trust FORWARD rules on vpn-gateway-a
docker exec vpn-gateway-a sh -c '
iptables -F FORWARD
iptables -P FORWARD DROP
iptables -I FORWARD -p tcp --dport 23 -j DROP
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -o wg0 -p icmp -j ACCEPT
iptables -A FORWARD -o wg0 -p tcp -m multiport --dports 22,80,443,8080 -j ACCEPT
iptables -L FORWARD -n -v
'
