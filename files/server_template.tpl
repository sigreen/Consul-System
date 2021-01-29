#!/usr/bin/env bash

# Server specific consul configuration grabbing local IP
cat << EOF > /etc/consul/consul.d/consul-server.hcl
server = true
log_file = "/etc/consul/logs/"
log_level = "DEBUG"
bootstrap_expect = 3
retry_join = ["provider=aws tag_key=Name tag_value=${server_name_tag}"]
bind_addr = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
advertise_addr = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
client_addr = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
ui = true
watches = [
    {
      type = "checks"
	    service = "httpd"
      args = ["/etc/consul/consul.d/check-handler.py"]
    }
  ]
EOF

# Starting consul services
sudo systemctl start consul