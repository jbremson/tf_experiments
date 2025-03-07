# Provider configuration
provider "aws" {
  region = "us-east-1" # You can change this to your preferred region
}

# Create an S3 bucket for content
resource "aws_s3_bucket" "content_bucket" {
  bucket = "my-example-cloudfront-bucket-${random_id.bucket_suffix.hex}"
}

# Random ID to make bucket name unique
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.content_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.content_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "example-oac"
  description                       = "Origin Access Control for S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  # Origin configuration
  origin {
    domain_name              = aws_s3_bucket.content_bucket.bucket_regional_domain_name
    origin_id                = "S3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Distribution settings
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Example CloudFront Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400  # 24 hours
    max_ttl                = 31536000  # 1 year
    compress               = true
  }

  # Price class (options: PriceClass_100, PriceClass_200, PriceClass_All)
  price_class = "PriceClass_100"

  # Viewer certificate (using default CloudFront certificate)
  viewer_certificate {
    cloudfront_default_certificate = true
  }
    # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# Output the CloudFront domain name
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

# Output the bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.content_bucket.bucket
}