# OAC is a mechanism for securely accessing private S3 bucket
resource "aws_cloudfront_origin_access_control" "web" {
  name                              = "web"
  description                       = "OAC for Portfolio web S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "cloudfront_web_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.web.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        aws_cloudfront_distribution.web_distribution.arn
      ]
    }
  }
}
resource "aws_s3_bucket_policy" "cloudfront_web_access" {
  bucket = aws_s3_bucket.web.id
  depends_on = [
    aws_s3_bucket_public_access_block.web_block_public
  ]
  policy = data.aws_iam_policy_document.cloudfront_web_access.json
}

locals {
  # apparently just internal identifier whose job is letting different parts of the distribution config to refer to each other
  s3_origin_id = "s3-origin-id"
}
resource "aws_cloudfront_distribution" "web_distribution" {
  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }

  enabled = true
  # is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_100"

  custom_error_response {
    # CF doesn't have `s3:ListBucket` permission, so requesting a path that doesn't exist results in S3 returning 403
    error_code            = 403
    error_caching_min_ttl = 10
    response_code         = 404
    response_page_path    = "/404.html"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.portfolio.arn
    ssl_support_method  = "sni-only"
  }
}

resource "aws_acm_certificate" "portfolio" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  # has to be in us-east-1 because it's used by CloudFront
  # CF is a global resource, but still has to be "assigned" to a region, so they canonically chose the first region - us-east-1
  # and this is also where it's looking for certificates
  provider = aws.us-east-1
}

resource "aws_acm_certificate_validation" "portfolio" {
  certificate_arn         = aws_acm_certificate.portfolio.arn
  validation_record_fqdns = [for record in aws_route53_record.dns_validation : record.fqdn]

  provider = aws.us-east-1
}