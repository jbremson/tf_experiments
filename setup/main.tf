provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# Create an S3 bucket
resource "aws_s3_bucket" "test_bucket" {
  bucket = "jb-test-bucket-777"  # Change to a unique bucket name

  tags = {
    Name        = "My Test Bucket"
    Environment = "Testing"
  }
}