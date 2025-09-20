
# Outputs
output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.web.public_ip}"
}

output "tunnel_command" {
  value = "ssh -i ~/.ssh/id_rsa -f -N -L 5432:${aws_db_instance.postgres.endpoint}:5432 ec2-user@${aws_instance.web.public_ip}"
}