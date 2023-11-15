provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "MY-VPC"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.subnet_cidr
  availability_zone       = "ap-southeast-1a" 
  map_public_ip_on_launch = true
  tags = {
    Name = "My-subnet1"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.subnet_cidr
  availability_zone       = "ap-southeast-1b" 
  map_public_ip_on_launch = true
  tags = {
    Name = "My-subnet2"
  }
}

resource "aws_internet_gateway" "Igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MY-IGW"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Igw.id
  }
}

resource "aws_iam_role" "eks_s3_access_role" {
  name = "eks_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com",
        },
      },
    ],
  })
}
resource "aws_eks_cluster" "my_eks_cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_s3_access_role.arn 

  vpc_config {
    subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  }
}

 resource "aws_s3_bucket" "Demo_bucket" {
  bucket = "my-latestrecent-bucket"
  acl    = "private"  
  tags = {
    Name = "MY-Demo_Bucket"
  }


   timeouts {
    create = "30m"
  }
}

resource "aws_db_subnet_group" "example_db_subnet_group" {
  name       = "mynewdemo-db-subnetgroup"
  subnet_ids = var.subnets

  tags = {
    Name = "Demo_DB_SubnetGroup"
  }
}


resource "aws_db_instance" "my_db" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "13.7"
  instance_class       = var.db_instance_class
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres12"
  db_subnet_group_name = aws_db_subnet_group.example_db_subnet_group.name

  vpc_security_group_ids = ["sg-0800e157613db45a9"] 

  tags = {
    Name = "my-Demo_DB"
  }
}

resource "aws_security_group" "my_sg" {
  name        = "my-security-group"
  description = "My security group description"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_sg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  enable_http2 = true
  idle_timeout = 60
}

# Route 53
resource "aws_route53_record" "my_domain" {
  name    = "my-domain.com"
  type    = "A"
  zone_id = var.route53_zone_id

  alias {
    name                   = aws_lb.my_alb.dns_name
    zone_id                = aws_lb.my_alb.zone_id
    evaluate_target_health = true
  }
}

# Amazon ECR
resource "aws_ecr_repository" "my_ecr_repo" {
  name                 = "my-ecr-repo"
  image_tag_mutability = "MUTABLE"
}
