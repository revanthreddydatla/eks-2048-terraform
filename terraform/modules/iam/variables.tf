variable "role_name" {
  type        = string
  description = "Name of the IAM role"
}

variable "assume_role_policy" {
  type        = string
  description = "Trust policy for IAM role"
}

# variable "policy_name" {
#   type        = string
#   default = null
#   description = "Name of the IAM policy. Required if policy document is given."
# }

variable "policy_description" {
  type        = string
  default     = "IAM policy for AWS service"
}


variable "policy_document" {
  type        = string
  default     = null
  description = "JSON IAM policy document. Required if policy_arn is not provided."
}

variable "policy_arn" {
  type        = string
  default     = null
  description = "Existing IAM policy ARN. Required if policy_document is not provided."
}
