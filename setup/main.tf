provider "aws" {
  region = "us-east-1"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "PrivateSubnet"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "PrivateRT"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  vpc_id = aws_vpc.main.id
  name   = "vpc-endpoint-sg"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "VPCEndpointSG"
  }
}

# VPC Endpoints for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
  tags = {
    Name = "SSMEndpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
  tags = {
    Name = "SSMMessagesEndpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
  tags = {
    Name = "EC2MessagesEndpoint"
  }
}

# IAM Configuration
resource "aws_iam_role" "ssm_cloudwatch_role" {
  name = "SSM-CloudWatch-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ssm_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ssm_cloudwatch_profile" {
  name = "SSM-CloudWatch-Profile"
  role = aws_iam_role.ssm_cloudwatch_role.name
}

# EC2 Instance
resource "aws_instance" "private_instance" {
  ami                  = var.amznLnx2023 # Amazon Linux 2 - update for your region
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.private.id
  iam_instance_profile = aws_iam_instance_profile.ssm_cloudwatch_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-cloudwatch-agent
              echo '{
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [{
                        "file_path": "/var/log/messages",
                        "log_group_name": "private-instance-logs",
                        "log_stream_name": "{instance_id}"
                      }]
                    }
                  }
                }
              }' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              EOF

  tags = {
    Name = "PrivateInstance"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "instance_logs" {
  name              = "private-instance-logs"
  retention_in_days = 30
}