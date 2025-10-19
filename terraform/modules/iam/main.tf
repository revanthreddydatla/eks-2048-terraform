resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
}

resource "aws_iam_policy" "custom" {
  count = var.policy_document != null ? 1 : 0
  name        = "${var.role_name}-policy"
  path        = "/"
  description = var.policy_description
  policy      = var.policy_document
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = var.policy_document != null ? aws_iam_policy.custom[0].arn : var.policy_arn
}