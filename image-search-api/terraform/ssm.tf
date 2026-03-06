# ---------------------------------------------------------------
# SSM Parameter Store — values are managed outside Terraform.
#
# All app secrets live under the /image-search prefix and are
# created/updated independently (e.g. via the AWS Console or CLI).
# Terraform does NOT own these values, so it will never prompt for
# them on plan/apply.
#
# The EC2 user_data script pulls every parameter at boot time
# using the instance's IAM role — no credentials needed here.
# ---------------------------------------------------------------

locals {
  ssm_prefix = "/image-search"
}
