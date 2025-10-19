resource "aws_eks_cluster" "this" {
  name = var.cluster_name

  access_config {
    authentication_mode = "API"
  }

  role_arn = var.role_arn
  version  = "1.31"

  vpc_config {
    subnet_ids = var.subnet_ids_list
  }

}