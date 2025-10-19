🎮 2048 Game on AWS EKS — Terraform Automated Infrastructure

📘 About
This guide automates the deployment of the 2048 game on AWS EKS using Terraform and Helm. It includes cluster setup, Fargate profiles, IAM roles, and AWS Load Balancer Controller integration.

✅ Features
1. EKS Cluster Setup
   - Uses default AWS VPC and public subnets.
   - Creates an EKS cluster with required IAM roles and policies.

2. IAM Roles and Policies
   - IAM role for EKS to manage AWS resources (CNI, security groups).
   - IAM access entry and AmazonEKSClusterAdminPolicy for the current AWS CLI user.

3. Fargate Profiles
   - game-2048 profile for app workloads.
   - kube-system profile for system pods like CoreDNS.

4. Fargate Pod Execution Role
   - IAM role with AmazonEKSFargatePodExecutionRole for Fargate pods.

5. Private Subnet Setup
   - Creates 2 private subnets, route table, NAT gateway, and EIP.
   - Enables internet access for private subnets via NAT.

6. OIDC Identity Provider
   - Registers EKS OIDC provider in IAM for IRSA (IAM Roles for Service Accounts).

7. AWS Load Balancer Controller
   - IAM role for service account to allow controller to create ALBs.

🛠️ Prerequisites
- AWS Account
- AWS CLI
- kubectl
- Terraform
- Helm

🚀 Setup Instructions

1. Configure AWS CLI
   aws configure
   aws s3 ls  # Test AWS CLI access

2. Deploy Infrastructure
   # Make sure you are in the terraform folder
   terraform apply

3. Update kubeconfig
   aws eks update-kubeconfig --name game-2048

4. Verify Cluster Access
   kubectl get svc -n kube-system

5. Deploy the 2048 App
   # Make sure you are in the kubernetes_definition_files folder
   kubectl apply -f game_2048.yaml
   # ⚠️ Don't forget to update the IAM account ID in the ServiceAccount annotation

6. Restart CoreDNS
   kubectl rollout restart deployment coredns -n kube-system

7. Install AWS Load Balancer Controller
   helm repo add eks https://aws.github.io/eks-charts
   helm repo update

   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     -n kube-system \
     --set clusterName=game-2048 \
     --set serviceAccount.create=false \
     --set serviceAccount.name=aws-load-balancer-controller \
     --set region=<AWS_REGION> \
     --set vpcId=<VPC_ID>

8. Check Ingress and Logs
   kubectl get ingress ingress-2048 -n game-2048
   kubectl get deployment aws-load-balancer-controller -n kube-system
   kubectl logs deployment/aws-load-balancer-controller -n kube-system

9. Restart CoreDNS (if needed)
   kubectl rollout restart deployment coredns -n kube-system

🧹 Cleanup Instructions

1. Delete Ingress
   kubectl delete ingress ingress-2048 -n game-2048

2. Confirm Load Balancer Deletion
   - Check EC2 → Load Balancers in AWS Console.

3. Destroy Infrastructure
   terraform destroy
