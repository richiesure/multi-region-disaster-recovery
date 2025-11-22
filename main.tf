provider "aws" {
  alias  = "primary"
  region = "eu-west-2"  # London (Primary)
}

provider "aws" {
  alias  = "secondary"
  region = "eu-west-1"  # Ireland (DR)
}

data "aws_caller_identity" "current" {}

# Primary Region - S3 Bucket with replication
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "dr-primary-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Primary-Data-Bucket"
    Environment = "Production"
    Region      = "eu-west-2"
  }
}

resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Secondary Region - Replica Bucket
resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "dr-secondary-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "DR-Replica-Bucket"
    Environment = "DR"
    Region      = "eu-west-1"
  }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for S3 replication
resource "aws_iam_role" "replication" {
  provider = aws.primary
  name     = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  provider = aws.primary
  name     = "s3-replication-policy"
  role     = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.secondary.arn}/*"
      }
    ]
  })
}

# S3 Replication Configuration
resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  provider   = aws.primary
  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.secondary]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary.arn
      storage_class = "STANDARD"
    }
  }
}

# Route53 Health Check for Primary Region
resource "aws_route53_health_check" "primary" {
  provider          = aws.primary
  fqdn              = "ec2-13-40-154-34.eu-west-2.compute.amazonaws.com"
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "Primary-Health-Check"
  }
}

# SNS Topic for DR Alerts
resource "aws_sns_topic" "dr_alerts" {
  provider = aws.primary
  name     = "disaster-recovery-alerts"

  tags = {
    Name = "DR-Alerts"
  }
}

resource "aws_sns_topic_subscription" "dr_email" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.dr_alerts.arn
  protocol  = "email"
  endpoint  = "richieprograms@gmail.com"
}

# CloudWatch Alarm for Health Check
resource "aws_cloudwatch_metric_alarm" "primary_health" {
  provider            = aws.primary
  alarm_name          = "primary-region-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Primary region is unhealthy - consider failover"
  alarm_actions       = [aws_sns_topic.dr_alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  tags = {
    Name = "Primary-Health-Alarm"
  }
}
