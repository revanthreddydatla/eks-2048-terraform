variable "cluster_name" {
  type = string
  description = "Name of the EKS cluster"
}
variable "role_arn" {
  type = string
  description = "iam role arn for the EKS cluster"
}
variable "subnet_ids_list" {
  type = list(string)
  description = "list of subnet ids, where cluster can create resources"
}