output "server_ip_addr" {
  value = aws_instance.consul-server[*].public_ip
}

output "client_ip_addr" {
  value = aws_instance.consul-client[*].public_ip
}

output "server_fqdn" {
  value = aws_route53_record.fqdn.name
}

output "activemq_ip" {
  value = aws_instance.activemq-server.public_ip
}