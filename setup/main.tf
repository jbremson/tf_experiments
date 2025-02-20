provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "jb-777-bucket"  # Change to a unique bucket name
  force_destroy = true            # Allows deletion of non-empty bucket
}

# Enable bucket ownership controls to disable ACLs
resource "aws_s3_bucket_ownership_controls" "my_bucket_ownership" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Step 2: Create a Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_ssm_role.name
}

resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
  name = "ec2_ssm_instance_profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Step 3: Create a Security Group
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # Allow SSH from the private subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["10.0.0.0/16"] # Allow outbound to the VPC
  }
}

# Step 4: Create an EC2 Instance
resource "aws_instance" "my_instance" {
  ami           = "ami-053a45fff0a704a47" # Replace with a valid AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_instance_profile.name



}

# Step 5: Create an S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.my_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [aws_vpc.my_vpc.main_route_table_id]
  subnet_ids =        [aws_subnet.private_subnet.id]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.us-east-1.ssm"  # Change region as needed
  subnet_ids =        [aws_subnet.private_subnet.id]
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.us-east-1.ssmmessages"  # Change region as needed
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true

}

resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.us-east-1.ec2messages"  # Change region as needed
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true

}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid = ""
      }
    ]
  })
}

