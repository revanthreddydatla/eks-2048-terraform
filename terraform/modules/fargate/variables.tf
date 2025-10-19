variable "cluster_name" {
  type = string
}
variable "fargate_profile_name" {
  type = string
}
variable "kubernetes_namespace" {
  type = string
}
variable "fargate_pod_execution_role_arn" {
  type = string
}
variable "private_subnet_ids_list" {
  type = list(string)
}