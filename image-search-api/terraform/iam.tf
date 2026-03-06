# ---------------------------------------------------------------
# IAM — EC2 instance role with least-privilege SSM read access.
# The app (boto3 inside Docker) inherits credentials transparently
# via the instance metadata service; no keys are needed in .env.
# ---------------------------------------------------------------

# Trust policy: allow EC2 to assume this role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_role" {
  name               = "image-search-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = { App = "image-search" }
}

# Policy: read-only access to /image-search/* parameters
data "aws_iam_policy_document" "ssm_read" {
  statement {
    sid    = "SSMGetParameters"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/image-search/*",
    ]
  }

  # Required to decrypt SecureString values with the default SSM KMS key
  statement {
    sid    = "KMSDecrypt"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ssm_read_policy" {
  name        = "image-search-ssm-read"
  description = "Allow image-search EC2 to read its SSM parameters"
  policy      = data.aws_iam_policy_document.ssm_read.json
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.ssm_read_policy.arn
}

# Instance profile that EC2 needs to use the role
resource "aws_iam_instance_profile" "app_profile" {
  name = "image-search-app-profile"
  role = aws_iam_role.app_role.name
}
