
locals {
  cluster_name                                      = "game-2048"
  kubernetes_namespace                              = "game-2048"
  aws_load_balancer_controller_service_account_name = "aws_load_balancer_controller_service_account"
  first_subnet_id                                   = tolist(data.aws_subnets.default_vpc_subnets.ids)[0]
  accepted_public_subnets_list_for_cluster          = [for s in data.aws_subnet.default_vpc_subnet : s.id if s.availability_zone != "us-east-1e"]
  fargate_profile_namespace_map                     = { "game-2048" = "game-2048", "kube-system" = "kube-system" }
}

data "aws_caller_identity" "current" {}

# -----------Retrieve vpc and subnet data
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default_vpc_subnet" {
  for_each = toset(data.aws_subnets.default_vpc_subnets.ids)
  id       = each.value
}

module "eks_cluster" {
  source          = "./modules/eks"
  cluster_name    = local.cluster_name
  role_arn        = module.cluster_iam.role_arn
  subnet_ids_list = local.accepted_public_subnets_list_for_cluster
  depends_on      = [module.cluster_iam]
}


module "cluster_iam" {
  source             = "./modules/iam"
  role_name          = "customEKSClusterRole"
  policy_description = "Policy for EKS cluster"
  policy_arn         = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

# Create the IAM OIDC provider
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]
  url             = module.eks_cluster.cluster_object.identity[0].oidc[0].issuer
}

# Get the TLS certificate for the OIDC provider
data "tls_certificate" "oidc_thumbprint" {
  url = module.eks_cluster.cluster_object.identity[0].oidc[0].issuer
}


# ------------------role for lb controller(which manages ingress)
# create iam role for lb controller to create lb resources and congiring routes in aws
# create policy json data from github url, create policy out of it and add it to alb_controller_role

data "http" "aws_lb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

module "alb_controller_iam" {
  source             = "./modules/iam"
  role_name          = "customAmazonEKSLoadBalancerControllerRole"
  policy_description = "Policy for AWS Load Balancer Controller"
  policy_document    = data.http.aws_lb_controller_policy.response_body
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks_cluster.cluster_object.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks_cluster.cluster_object.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# -----------------access entry creation in eks for iam user to authentitate to cluster api server
# create access entry and associate access policy for current user to have access to eks game-2048 cluster

resource "aws_eks_access_entry" "current_user" {
  cluster_name  = module.eks_cluster.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
  depends_on = [
    module.eks_cluster
  ]
}

resource "aws_eks_access_policy_association" "current_user" {
  cluster_name  = module.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_caller_identity.current.arn

  access_scope {
    type = "cluster"
  }
  depends_on = [
    module.eks_cluster, aws_eks_access_entry.current_user
  ]
}

# -----------create a namespace, it will be done in the yaml definition file

# -----------PROCESS: creating fargate profile 
#            https://docs.aws.amazon.com/eks/latest/userguide/pod-execution-role.html
# -----------create role for eks components to create pods in fargate

module "fargate_iam" {
  source             = "./modules/iam"
  role_name          = "customAmazonEKSFargatePodExecutionRole"
  policy_description = "Policy for Fargate"
  policy_arn         = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}


# -----------fargate requires Private subnets, as we are using default vpc lets create two private subnets in the vpc  priv-subnet-01 with az,priv-subnet-02
#            as priv subnet required 1.create seperate route table, 2. associate route table with subnet 
#            [NOTE:(from fargate profile creation console)Specify the subnets in your VPC where your pods will run. Only private subnets are supported.]
# to provide internet access for resources in private subnets
# EX:so pods in private subnet deployed on fargate can pull docker containers
# Allocate an Elastic IP for the NAT Gateway

module "fargate_private_subnets" {
  source                   = "./modules/networking"
  vpc_id                   = data.aws_vpc.default.id
  vpc_cidr_block           = data.aws_vpc.default.cidr_block
  private_subnet_cidrs_map = { "priv-subnet-a" = "172.31.96.0/20", "priv-subnet-b" = "172.31.112.0/20" }
  nat_gateway_subnet_id    = local.first_subnet_id
}


# -----------create fargate profile , during creation add namespace to fargate profile
module "fargate_profiles" {
  for_each                       = local.fargate_profile_namespace_map
  source                         = "./modules/fargate"
  cluster_name                   = module.eks_cluster.name
  fargate_profile_name           = each.key
  kubernetes_namespace           = each.value
  private_subnet_ids_list        = module.fargate_private_subnets.private_subnet_ids
  fargate_pod_execution_role_arn = module.fargate_iam.role_arn
}



# ------------to enable logging for fargate pods
#       create a iam policy with necessary permissions and attach it to fargate role 
#       follow aws documentaion
#       https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html
#  data "http" "fargate_cloudwatch_policy" {
#   url = "https://raw.githubusercontent.com/aws-samples/amazon-eks-fluent-logging-examples/mainline/examples/fargate/cloudwatchlogs/permissions.json"
# }
# resource "aws_iam_policy" "fargate_cloudwatch_policy" {
#   name        = "fargate_cloudwatch_policy"
#   path        = "/"
#   description = "policy to allow components in fargate to do actions on cloudwatch"
#   policy = data.http.fargate_cloudwatch_policy.response_body
# }
# resource "aws_iam_role_policy_attachment" "fargate_cloudwatch_policy" {
#   policy_arn = aws_iam_policy.fargate_cloudwatch_policy.arn
#   role       = aws_iam_role.AmazonEKSFargatePodExecutionRole.name
# }
