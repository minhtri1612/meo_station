resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-db-key-pair-quanque"
  public_key = file("~/.ssh/id_rsa.pub")  # Update this path to your public key
}