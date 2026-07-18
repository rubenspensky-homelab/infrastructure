resource "aws_iam_user" "s3_backups" {
  name = "${var.name_prefix}-s3-backups"
  path = "/${var.name_prefix}/"
}

resource "aws_iam_user" "secrets_reader" {
  name = "${var.name_prefix}-secrets-reader"
  path = "/${var.name_prefix}/"
}

data "aws_iam_policy_document" "s3_backups" {
  statement {
    sid = "ListBackupsBucket"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [aws_s3_bucket.backups.arn]
  }

  statement {
    sid = "ReadWriteBackupsObjects"

    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]

    resources = ["${aws_s3_bucket.backups.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_backups" {
  name        = "${var.name_prefix}-s3-backups-read-write"
  description = "Read and write access to the homelab backups S3 bucket."
  policy      = data.aws_iam_policy_document.s3_backups.json
}

resource "aws_iam_user_policy_attachment" "s3_backups" {
  user       = aws_iam_user.s3_backups.name
  policy_arn = aws_iam_policy.s3_backups.arn
}

data "aws_iam_policy_document" "secrets_reader" {
  statement {
    sid = "ReadHomelabSecrets"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = [for secret in aws_secretsmanager_secret.homelab : secret.arn]
  }

  statement {
    sid = "ReadHomelabParameters"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]

    resources = [for parameter in aws_ssm_parameter.homelab : parameter.arn]
  }
}

resource "aws_iam_policy" "secrets_reader" {
  name        = "${var.name_prefix}-secrets-read"
  description = "Read-only access to selected homelab secrets and parameters."
  policy      = data.aws_iam_policy_document.secrets_reader.json
}

resource "aws_iam_user_policy_attachment" "secrets_reader" {
  user       = aws_iam_user.secrets_reader.name
  policy_arn = aws_iam_policy.secrets_reader.arn
}
