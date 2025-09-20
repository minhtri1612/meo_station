
# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "main-db-subnet-group"
  }
}

# Regular RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier             = "database-1"
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp2"
  storage_encrypted      = true
  
  db_name  = "mydb"
  username = "postgres"
  password = "Minhchau3112..."  # Change this!
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  
  skip_final_snapshot     = true
  deletion_protection     = false
  
  publicly_accessible     = false
  
  tags = {
    Name = "postgres-instance"
  }
}

