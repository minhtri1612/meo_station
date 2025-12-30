variable "region" {
  default = "ap-southeast-2"
}

variable "ami_id" {
  description = "AMI ID to use (leave empty to auto-detect latest Ubuntu 22.04 LTS)"
  type        = string
  default     = "" # Empty = auto-detect latest Ubuntu 22.04 LTS for your region
}

variable "instance_type" {
  default = "t3.medium"
}

variable "my_ip" {
  description = "Your public IP with /32 (for SSH)"
  default     = "0.0.0.0/0"
}

variable "master_count" {
  default = 1
}
variable "worker_count" {
  default = 3
}
