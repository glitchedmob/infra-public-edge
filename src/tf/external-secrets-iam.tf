data "aws_caller_identity" "current" {}

locals {
  external_secrets_oidc_issuer = "k8s-oidc-edge.levizitting.com"
  external_secrets_subject     = "system:serviceaccount:external-secrets:external-secrets"

  external_secrets_ssm_parameter_arns = [
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/homelab/${local.hostname}/*",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/homelab/public-edge/*",
  ]
  external_secrets_legacy_credential_arns = [
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.flux_access_key_id_ssm_path}",
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.flux_secret_access_key_ssm_path}",
  ]
}

resource "aws_iam_role" "external_secrets" {
  name                 = "external-secrets"
  path                 = "/public-edge/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/public-edge/KubernetesWorkloadBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.external_secrets_oidc_issuer}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.external_secrets_oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.external_secrets_oidc_issuer}:sub" = local.external_secrets_subject
          }
        }
      }
    ]
  })

  tags = {
    KubernetesNamespace      = "external-secrets"
    KubernetesServiceAccount = "external-secrets"
    ManagedBy                = "OpenTofu"
    Repository               = "glitchedmob/infra-public-edge"
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "ReadPublicEdgeParameters"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyLegacyCredentials"
        Effect = "Deny"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = local.external_secrets_legacy_credential_arns
      },
      {
        Sid    = "ReadPublicEdgeParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = local.external_secrets_ssm_parameter_arns
      },
    ]
  })
}
