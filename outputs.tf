output "Consul_Server_IPs" {
  value = aws_instance.consul-server[*].public_ip
}

output "Consul_Client_IPs" {
  value = aws_instance.consul-client[*].public_ip
}

output "Consul_Server" {
  value = "http://${aws_route53_record.fqdn.name}:8500"
}

output "ActiveMQ_Server" {
  value = "http://${aws_instance.activemq-server.public_ip}:8161/admin"
}

output "ActiveMQ_Server_IP" {
  value = aws_instance.activemq-server.public_ip
}