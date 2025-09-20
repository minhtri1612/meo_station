# Get your current public IP
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# EC2 Security Group (in public subnet)
resource "aws_security_group" "ec2" {
  name        = "ec2-sg"
  description = "Allow ALB to EC2 (3000) and SSH from your IP only"
  vpc_id      = aws_vpc.main.id

  # Rule 1: Only ALB can access EC2 on port 3000
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Rule 2: SSH restricted to your current public IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${trimspace(data.http.my_ip.body)}/32"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
    # Allow RDS to respond to EC2
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Open but restricted by EC2 SG
  }

  tags = {
    Name = "rds-sg"
    }
}


