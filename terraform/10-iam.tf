############################################
# 1. IAM Role
############################################
resource "aws_iam_role" "ec2_s3_role" {
  name = "database-client-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

############################################
# 2. Attach S3 Full Access to Role
############################################
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

############################################
# 3. Create Instance Profile
############################################
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "database-client-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
}