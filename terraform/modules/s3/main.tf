# terraform/modules/s3/main.tf
# ==============================================================================
# S3 Module - Object Storage for Event Assets
# ==============================================================================

# S3 Bucket for event assets (images, documents, etc.)
resource "aws_s3_bucket" "assets" {
  bucket = "${var.project_name}-${var.environment}-assets-${var.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-assets"
      Environment = var.environment
      Purpose     = "Event assets storage"
    }
  )
}

# Block public access
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null ? true : false
  }
}

# Lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  count = var.enable_lifecycle_rules ? 1 : 0

  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    filter {
      prefix = "uploads/"
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = var.transition_to_glacier_days
      storage_class = "GLACIER"
    }

    filter {
      prefix = "archives/"
    }
  }

  rule {
    id     = "expire-old-versions"
    status = var.enable_versioning ? "Enabled" : "Disabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    filter {}
  }

  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {}
  }
}

# CORS configuration for frontend uploads
resource "aws_s3_bucket_cors_configuration" "assets" {
  count = var.enable_cors ? 1 : 0

  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ============================================================================
# CRITICAL FIX: Bucket policy for CloudFront OAC access
# ============================================================================
resource "aws_s3_bucket_policy" "assets_cloudfront" {
  count = var.cloudfront_distribution_arn != "" ? 1 : 0

  bucket = aws_s3_bucket.assets.id

  # Ensure public access block is created first
  depends_on = [aws_s3_bucket_public_access_block.assets]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
}

# Enable access logging
resource "aws_s3_bucket_logging" "assets" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.assets.id

  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "assets-logs/"
}

# ==============================================================================
# Logging Bucket
# ==============================================================================

resource "aws_s3_bucket" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = "${var.project_name}-${var.environment}-logs-${var.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-logs"
      Environment = var.environment
      Purpose     = "Access logs"
    }
  )
}

# Enable ACL for logs bucket (required by CloudFront)
resource "aws_s3_bucket_ownership_controls" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Configure ACL for CloudFront log delivery
resource "aws_s3_bucket_acl" "logs" {
  count = var.enable_access_logging ? 1 : 0

  depends_on = [aws_s3_bucket_ownership_controls.logs]

  bucket = aws_s3_bucket.logs[0].id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy for ALB access logs and CloudFront logs
resource "aws_s3_bucket_policy" "logs" {
  count = var.enable_access_logging ? 1 : 0

  depends_on = [aws_s3_bucket_public_access_block.logs]

  bucket = aws_s3_bucket.logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs[0].arn}/*"
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs[0].arn
      },
      {
        Sid    = "AWSALBLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::156460612806:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs[0].arn}/*"
      },
      {
        Sid    = "AWSALBLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::156460612806:root"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs[0].arn
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = var.logs_expiration_days
    }

    filter {}
  }
}

# ==============================================================================
# Backend Files Bucket
# ==============================================================================

resource "aws_s3_bucket" "backend_files" {
  bucket = "${var.project_name}-backend-${var.environment}-files-${var.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-backend-${var.environment}-files"
      Environment = var.environment
      Purpose     = "Backend developer files storage"
    }
  )
}

# Enable ACL for backend_files bucket
resource "aws_s3_bucket_ownership_controls" "backend_files" {
  bucket = aws_s3_bucket.backend_files.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

# Configure bucket ACL as public-read for direct frontend access
resource "aws_s3_bucket_acl" "backend_files" {
  depends_on = [aws_s3_bucket_ownership_controls.backend_files, aws_s3_bucket_public_access_block.backend_files]

  bucket = aws_s3_bucket.backend_files.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "backend_files" {
  bucket = aws_s3_bucket.backend_files.id

  block_public_acls       = false  # Allow public ACLs
  block_public_policy     = false  # Allow public bucket policy
  ignore_public_acls      = false  # Respect ACLs
  restrict_public_buckets = false  # Allow public bucket access
}

resource "aws_s3_bucket_versioning" "backend_files" {
  bucket = aws_s3_bucket.backend_files.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend_files" {
  bucket = aws_s3_bucket.backend_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null ? true : false
  }
}

# CORS configuration for backend_files bucket (direct frontend uploads)
resource "aws_s3_bucket_cors_configuration" "backend_files" {
  bucket = aws_s3_bucket.backend_files.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag", "x-amz-request-id"]
    max_age_seconds = 3600
  }
}

# Bucket policy for public read access
resource "aws_s3_bucket_policy" "backend_files" {
  depends_on = [aws_s3_bucket_public_access_block.backend_files]

  bucket = aws_s3_bucket.backend_files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.backend_files.arn}/*"
      }
    ]
  })
}

# Lifecycle rules for backend_files bucket
resource "aws_s3_bucket_lifecycle_configuration" "backend_files" {
  bucket = aws_s3_bucket.backend_files.id

  rule {
    id     = "transition-old-files"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    filter {
      prefix = "uploads/"
    }
  }

  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {}
  }
}

# ==============================================================================
# Security Reports Bucket
# ==============================================================================

resource "aws_s3_bucket" "security_reports" {
  bucket = "${var.project_name}-${var.environment}-security-reports-${var.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-security-reports"
      Environment = var.environment
      Purpose     = "Security scan reports storage"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "security_reports" {
  bucket = aws_s3_bucket.security_reports.id

  rule {
    id     = "expire-old-reports"
    status = "Enabled"

    expiration {
      days = 90
    }

    filter {}
  }
}

# ==============================================================================
# Backups Bucket
# ==============================================================================

resource "aws_s3_bucket" "backups" {
  bucket = "${var.project_name}-${var.environment}-backups-${var.account_id}"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-backups"
      Environment = var.environment
      Purpose     = "Database and application backups"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    filter {}
  }
}