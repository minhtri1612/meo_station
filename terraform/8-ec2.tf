# EC2 Instance
resource "aws_instance" "web" {
  ami                    = "ami-0146fc9ad419e2cfd"  # Amazon Linux 2 in ap-southeast-2
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public_1.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y postgresql15
              EOF

  tags = {
    Name = "database-client"
  }
}
