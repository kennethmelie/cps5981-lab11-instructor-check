# Cougar Advising - AWS declaration, REMEDIATED (scanned only; never applied in the lab).
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Nightly exports of advising ledgers (student financial data). Private, versioned, encrypted.
resource "aws_s3_bucket" "exports" {
  bucket = "cougar-advising-exports"
}

resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "exports" {
  bucket = aws_s3_bucket.exports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "exports" {
  bucket        = aws_s3_bucket.exports.id
  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "s3-access/exports/"
}

# Audit logs live in their own bucket, not beside the data they audit.
resource "aws_s3_bucket" "audit" {
  bucket = "cougar-advising-audit"
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Deploy identity for the pipeline: only this repository's main branch may assume it.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "deploy" {
  name = "cougar-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:your-github-username/cps5981-lab11:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Least privilege: the pipeline writes release bundles to one prefix of one bucket. Nothing else.
resource "aws_iam_role_policy" "deploy" {
  name = "cougar-deploy-policy"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "${aws_s3_bucket.exports.arn}/releases/*"
    }]
  })
}

# No SSH from the internet: administrators use Session Manager, which is authenticated and logged.
resource "aws_security_group" "web" {
  name        = "cougar-web"
  description = "Cougar Advising web server"

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS out for package updates only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.web.name
  ebs_optimized               = true
  monitoring                  = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  # The password is no longer in the template: the app reads it from Parameter Store at start-up.
  user_data = "export LEDGER_DB_PASSWORD_PARAMETER=/cougar/ledger-db-password"
}

# The server's own identity may read exactly one secret parameter, and nothing else.
resource "aws_iam_role" "web" {
  name = "cougar-web"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "web" {
  name = "cougar-web-read-ledger-secret"
  role = aws_iam_role.web.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "ssm:GetParameter", Resource = "arn:aws:ssm:us-east-1:*:parameter/cougar/ledger-db-password" }]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "cougar-web"
  role = aws_iam_role.web.name
}

# Audit trail of changes to the account: on, in every region, tamper-evident.
resource "aws_cloudtrail" "audit" {
  name                       = "cougar-audit"
  s3_bucket_name             = aws_s3_bucket.audit.id
  enable_logging             = true
  enable_log_file_validation = true
  is_multi_region_trail      = true
}
