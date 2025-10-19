output "name" {
  value = aws_eks_cluster.this.name
}
output "cluster_object" {
  value = aws_eks_cluster.this
}