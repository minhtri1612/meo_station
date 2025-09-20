resource "aws_s3_bucket" "database_client_bucket" {
  bucket = "database-client-bucket-tritran-richard-16122004" # must be globally unique

  tags = {
    Name        = "database-client-bucket"
    Environment = "dev"
  }
}

############################################
# 5. Define local files list
############################################
locals {
  product_images = fileset("${path.module}/../public/products/A", "*")
}

############################################
# 6. Upload all files from local folder to S3
############################################
resource "aws_s3_object" "product_files" {
  for_each = toset(local.product_images)

  bucket = aws_s3_bucket.database_client_bucket.bucket
  key    = "products/A/${each.value}"  # Path in S3
  source = "${path.module}/../public/products/A/${each.value}"
  acl    = "private"
}

############################################
# 7. Restrict role to this bucket (optional — S3FullAccess already covers it)
############################################
resource "aws_iam_role_policy" "s3_bucket_policy" {
  name = "database-client-s3-bucket-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*"],
        Resource = [
          aws_s3_bucket.database_client_bucket.arn,
          "${aws_s3_bucket.database_client_bucket.arn}/*"
        ]
      }
    ]
  })
}