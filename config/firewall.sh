#!/bin/sh
# Apply base firewall rules - IPv4 and IPv6
# Keeps fail2ban chains intact, blocks all except SSH+ICMP+Tailscale

### IPv4 ###
# Flush INPUT rules only (keep fail2ban chains)
iptables -F INPUT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow Tailscale interface (trusted - all traffic permitted)
iptables -A INPUT -i tailscale0 -j ACCEPT

# Allow established/related
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (fail2ban f2b-sshd chain handles banning, then ACCEPT non-banned)
iptables -N f2b-sshd 2>/dev/null || true
iptables -A INPUT -p tcp --dport 22 -j f2b-sshd
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow ICMP
iptables -A INPUT -p icmp -j ACCEPT

# DROP everything else
iptables -A INPUT -j DROP

# Docker: block public exposure via DOCKER-USER chain
# Docker bypasses INPUT chain via FORWARD/NAT — DOCKER-USER runs before DOCKER chain
iptables -N DOCKER-USER 2>/dev/null || true
iptables -F DOCKER-USER
# Allow container outbound (docker0/br-*) - must come first
iptables -I DOCKER-USER -i docker0 -j RETURN
iptables -I DOCKER-USER -i br+ -j RETURN
# Allow Tailscale and loopback inbound to containers
iptables -I DOCKER-USER -i tailscale0 -j RETURN
iptables -I DOCKER-USER -i lo -j RETURN
# Allow established/related back through (return traffic for container outbound)
iptables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
# Block NEW inbound connections from public interfaces to Docker ports
iptables -A DOCKER-USER -i eth0 -j DROP
iptables -A DOCKER-USER -i enp0s6 -j DROP
iptables -A DOCKER-USER -j RETURN

### IPv6 ###
# Flush INPUT rules
ip6tables -F INPUT

# Allow loopback
ip6tables -A INPUT -i lo -j ACCEPT

# Allow Tailscale interface
ip6tables -A INPUT -i tailscale0 -j ACCEPT

# Allow established/related
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow ICMPv6 (required for IPv6 neighbor discovery, SLAAC, etc.)
ip6tables -A INPUT -p ipv6-icmp -j ACCEPT

# DROP everything else
ip6tables -A INPUT -j DROP

echo "Firewall rules applied"
iptables -L INPUT -n -v
ip6tables -L INPUT -n -v
