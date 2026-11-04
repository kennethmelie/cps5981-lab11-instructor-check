# Cougar Advising - AWS declaration (SCANNED ONLY. Never apply this: the lab needs no cloud account.)
# The same system is declared for Google Cloud in ../gcp/main.tf so you can compare control objectives.
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Nightly exports of advising ledgers (student financial data).
resource "aws_s3_bucket" "exports" {
  bucket = "cougar-advising-exports"
}

resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Deploy identity used by the CI/CD pipeline (GitHub Actions OIDC).
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
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "deploy" {
  name = "cougar-deploy-policy"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "*", Resource = "*" }]
  })
}

# Network rule for the advising server.
resource "aws_security_group" "web" {
  name        = "cougar-web"
  description = "Cougar Advising web server"

  ingress {
    description = "SSH for emergency fixes"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data              = "export LEDGER_DB_PASSWORD=cougar2026"
}

# Audit trail of changes to the account.
resource "aws_cloudtrail" "audit" {
  name                       = "cougar-audit"
  s3_bucket_name             = aws_s3_bucket.exports.id
  enable_logging             = false
  enable_log_file_validation = false
  is_multi_region_trail      = false
}
