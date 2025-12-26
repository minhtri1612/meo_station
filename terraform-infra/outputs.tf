output "master_public_ip" {
  value = [for w in aws_instance.masters : w.public_ip]
}

output "worker_public_ips" {
  value = [for w in aws_instance.workers : w.public_ip]
}

output "ssh_key_file" {
  value = local_file.private_key.filename
}

output "cloudwatch_dashboard_name" {
  value = aws_cloudwatch_dashboard.k8s_dashboard.dashboard_name
}
