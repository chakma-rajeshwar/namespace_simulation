#!/bin/bash

# Create bridges
ip link add br0 type bridge
ip link add br1 type bridge
ip link set br0 up
ip link set br1 up

# Create namespaces
ip netns add ns1
ip netns add ns2
ip netns add router-ns

# Create veth pairs
ip link add veth1-ns type veth peer name veth1-br
ip link add veth2-ns type veth peer name veth2-br
ip link add veth3-ns type veth peer name veth3-br
ip link add veth4-ns type veth peer name veth4-br

# Move veth endpoints to namespaces
ip link set veth1-ns netns ns1
ip link set veth2-ns netns ns2
ip link set veth3-ns netns router-ns
ip link set veth4-ns netns router-ns

# Connect veth endpoints to bridges
ip link set veth1-br master br0
ip link set veth2-br master br1
ip link set veth3-br master br0
ip link set veth4-br master br1

# Bring up bridge interfaces
ip link set veth1-br up
ip link set veth2-br up
ip link set veth3-br up
ip link set veth4-br up

# Bring up interfaces inside namespaces
ip netns exec ns1 ip link set dev veth1-ns up
ip netns exec ns2 ip link set dev veth2-ns up
ip netns exec router-ns ip link set dev veth3-ns up
ip netns exec router-ns ip link set dev veth4-ns up

# Assign IPs to interfaces
ip netns exec ns1 ip addr add 10.11.0.1/24 dev veth1-ns
ip netns exec ns2 ip addr add 10.12.0.1/24 dev veth2-ns
ip netns exec router-ns ip addr add 10.11.0.2/24 dev veth3-ns  
ip netns exec router-ns ip addr add 10.12.0.2/24 dev veth4-ns 

# Add default routes in namespaces
ip netns exec ns1 ip route add default via 10.11.0.2
ip netns exec ns2 ip route add default via 10.12.0.2

# Enable IP forwarding in the router namespace
ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1

# Add routing rules in the router namespace
ip netns exec router-ns ip route replace 10.11.0.0/24 dev veth3-ns
ip netns exec router-ns ip route replace 10.12.0.0/24 dev veth4-ns

# Firewall rules
iptables --append FORWARD --in-interface br0 --jump ACCEPT
iptables --append FORWARD --out-interface br0 --jump ACCEPT
iptables --append FORWARD --in-interface br1 --jump ACCEPT
iptables --append FORWARD --out-interface br1 --jump ACCEPT
iptables -A FORWARD -i br0 -o br1 -j ACCEPT
iptables -A FORWARD -i br1 -o br0 -j ACCEPT

ip netns exec ns1 iptables -A OUTPUT -o veth1-ns -j ACCEPT
ip netns exec ns1 iptables -A INPUT -i veth1-ns -j ACCEPT

ip netns exec ns2 iptables -A INPUT -i veth2-ns -j ACCEPT
ip netns exec ns2 iptables -A OUTPUT -o veth2-ns -j ACCEPT

ip netns exec router-ns iptables -A FORWARD -i veth3-ns -o veth4-ns -j ACCEPT
ip netns exec router-ns iptables -A FORWARD -i veth4-ns -o veth3-ns -j ACCEPT
