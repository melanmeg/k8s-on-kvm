#!/bin/bash
set -eu

KUBE_API_SERVER_VIP=192.168.11.100
NODE_IPS=( 192.168.11.111 192.168.11.112 192.168.11.113 )

apt install -y haproxy 

cat > /etc/haproxy/haproxy.cfg <<EOF
global
  log /dev/log    local0
  log /dev/log    local1 notice
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
  stats timeout 30s
  user haproxy
  group haproxy
  daemon
defaults
  log     global
  mode    http
  option  httplog
  option  dontlognull
  timeout connect 5000
  timeout client  50000
  timeout server  50000
  errorfile 400 /etc/haproxy/errors/400.http
  errorfile 403 /etc/haproxy/errors/403.http
  errorfile 408 /etc/haproxy/errors/408.http
  errorfile 500 /etc/haproxy/errors/500.http
  errorfile 502 /etc/haproxy/errors/502.http
  errorfile 503 /etc/haproxy/errors/503.http
  errorfile 504 /etc/haproxy/errors/504.http
frontend k8s-api
  bind ${KUBE_API_SERVER_VIP}:8443
  mode tcp
  option tcplog
  default_backend k8s-api
backend k8s-api
  mode tcp
  option tcplog
  option tcp-check
  balance roundrobin
  default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
  server k8s-api-1 ${NODE_IPS[0]}:6443 check
  server k8s-api-2 ${NODE_IPS[1]}:6443 check
  server k8s-api-3 ${NODE_IPS[2]}:6443 check
EOF

echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
sysctl -p

apt-get -y install keepalived

cat > /etc/keepalived/keepalived.conf <<EOF
# Define the script used to check if haproxy is still working
vrrp_script chk_haproxy { 
    script "/usr/bin/killall -0 haproxy"
    interval 2 
    weight 2 
}
  
# Configuration for Virtual Interface
vrrp_instance LB_VIP {
  interface enp1s0
  state MASTER        # set to BACKUP on the peer machine
  priority 101        # set to  99 on the peer machine
  virtual_router_id 51
  smtp_alert          # Enable Notifications Via Email
  authentication {
      auth_type AH
      auth_pass zaq12wsx	# Password for accessing vrrpd. Same on all devices
  }
  unicast_src_ip ${NODE_IPS[0]} # Private IP address of master
  unicast_peer {
    ${NODE_IPS[2]}		# Private IP address of the backup haproxy
  }
  virtual_ipaddress {
      ${KUBE_API_SERVER_VIP}
  }
  track_script {
      chk_haproxy
  }
}
EOF

systemctl restart keepalived
systemctl restart haproxy

systemctl enable keepalived --now
systemctl enable haproxy --now
