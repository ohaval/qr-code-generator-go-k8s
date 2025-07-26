#!/bin/bash

set -e

# Configuration
CLUSTER_NAME="qr-generator-cluster"
REGION="us-east-1"
NODE_GROUP_NAME="qr-generator-nodes"
ECR_REPO_NAME="qr-code-generator"
NAMESPACE="qr-generator"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI first."
        print_status "Install with: curl 'https://awscli.amazonaws.com/AWSCLIV2.pkg' -o 'AWSCLIV2.pkg' && sudo installer -pkg AWSCLIV2.pkg -target /"
        exit 1
    fi

    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi

    # Check if eksctl is installed
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl not found. Installing eksctl..."
        curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
        sudo mv /tmp/eksctl /usr/local/bin/
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi

    print_success "All prerequisites are satisfied"
}

create_ecr_repository() {
    print_status "Creating ECR repository..."

    # Check if repository already exists
    if aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION &> /dev/null; then
        print_warning "ECR repository $ECR_REPO_NAME already exists"
    else
        aws ecr create-repository \
            --repository-name $ECR_REPO_NAME \
            --region $REGION \
            --encryption-configuration encryptionType=AES256
        print_success "ECR repository $ECR_REPO_NAME created"
    fi

    # Get repository URI
    ECR_URI=$(aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION --query 'repositories[0].repositoryUri' --output text)
    print_status "ECR Repository URI: $ECR_URI"
}

create_eks_cluster() {
    print_status "Creating EKS cluster (this may take 15-20 minutes)..."

    # Check if cluster already exists
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "EKS cluster $CLUSTER_NAME already exists"
    else
        # Create cluster with eksctl
        eksctl create cluster \
            --name $CLUSTER_NAME \
            --region $REGION \
            --version 1.32 \
            --nodegroup-name $NODE_GROUP_NAME \
            --node-type t3.medium \
            --nodes 2 \
            --nodes-min 1 \
            --nodes-max 4 \
            --managed \
            --with-oidc \
            --ssh-access \
            --ssh-public-key ~/.ssh/eks_qr_generator.pub

        print_success "EKS cluster $CLUSTER_NAME created"
    fi
}

configure_kubectl() {
    print_status "Configuring kubectl..."

    # Update kubeconfig
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

    # Verify connection
    if kubectl get nodes &> /dev/null; then
        print_success "kubectl configured successfully"
        kubectl get nodes
    else
        print_error "Failed to configure kubectl"
        exit 1
    fi
}

create_namespace() {
    print_status "Creating Kubernetes namespace..."

    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace $NAMESPACE
        print_success "Namespace $NAMESPACE created"
    fi
}

setup_aws_load_balancer_controller() {
    print_status "Setting up AWS Load Balancer Controller..."

    # Create IAM OIDC provider
    print_status "Creating IAM OIDC provider..."
    if eksctl utils associate-iam-oidc-provider --region=$REGION --cluster=$CLUSTER_NAME --approve; then
        print_success "IAM OIDC provider created successfully"
    else
        print_error "Failed to create IAM OIDC provider"
        return 1
    fi

    # Download IAM policy
    print_status "Downloading latest IAM policy..."
    if curl -s -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json; then
        print_success "IAM policy downloaded successfully"
    else
        print_error "Failed to download IAM policy"
        return 1
    fi

    # Create or update IAM policy
    print_status "Creating/updating IAM policy..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

    if aws iam get-policy --policy-arn $POLICY_ARN &>/dev/null; then
        print_status "Policy exists, creating new version..."
        if aws iam create-policy-version \
            --policy-arn $POLICY_ARN \
            --policy-document file://iam_policy.json \
            --set-as-default 2>/dev/null; then
            print_success "IAM policy updated successfully"
        else
            print_warning "Failed to update policy, but continuing (policy might be current)"
        fi
    else
        if aws iam create-policy \
            --policy-name AWSLoadBalancerControllerIAMPolicy \
            --policy-document file://iam_policy.json 2>/dev/null; then
            print_success "IAM policy created successfully"
        else
            print_error "Failed to create IAM policy"
            return 1
        fi
    fi

    # Create additional permissions policy for missing permissions
    print_status "Creating additional permissions policy..."
    cat > additional_permissions.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:ModifyListenerAttributes"
            ],
            "Resource": "*"
        }
    ]
}
EOF

    ADDITIONAL_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerAdditionalPermissions"
    if ! aws iam get-policy --policy-arn $ADDITIONAL_POLICY_ARN &>/dev/null; then
        if aws iam create-policy \
            --policy-name AWSLoadBalancerControllerAdditionalPermissions \
            --policy-document file://additional_permissions.json; then
            print_success "Additional permissions policy created successfully"
        else
            print_warning "Failed to create additional permissions policy"
        fi
    else
        print_status "Additional permissions policy already exists"
    fi

    # Create IAM service account
    print_status "Creating IAM service account..."
    if eksctl create iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --role-name AmazonEKSLoadBalancerControllerRole \
        --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
        --approve 2>/dev/null; then
        print_success "IAM service account created successfully"
    else
        print_warning "IAM service account already exists or creation failed (this is OK if account exists)"
    fi

    # Attach additional permissions policy to the role
    print_status "Attaching additional permissions to LoadBalancer Controller role..."
    if aws iam attach-role-policy \
        --role-name AmazonEKSLoadBalancerControllerRole \
        --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerAdditionalPermissions 2>/dev/null; then
        print_success "Additional permissions attached successfully"
    else
        print_warning "Additional permissions already attached or attachment failed"
    fi

    # Add Helm repository
    print_status "Adding Helm repository for AWS Load Balancer Controller..."
    if ! helm repo list | grep -q "eks"; then
        helm repo add eks https://aws.github.io/eks-charts
        print_success "Helm repository added successfully"
    else
        print_warning "Helm repository already exists"
    fi

    print_status "Updating Helm repositories..."
    helm repo update

    # Install AWS Load Balancer Controller
    print_status "Installing AWS Load Balancer Controller..."
    if ! helm list -n kube-system | grep -q "aws-load-balancer-controller"; then
        if helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=$CLUSTER_NAME \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller; then
            print_success "AWS Load Balancer Controller installed successfully"
        else
            print_error "Failed to install AWS Load Balancer Controller"
            rm -f iam_policy.json
            return 1
        fi
    else
        print_warning "AWS Load Balancer Controller is already installed"
    fi

    # Verify controller deployment
    print_status "Verifying controller deployment..."
    sleep 5  # Give some time for the deployment to start
    if kubectl get deployment -n kube-system aws-load-balancer-controller; then
        print_success "Controller deployment found"

        # Check if pods are running
        print_status "Checking controller pod status..."
        if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=60s; then
            print_success "Controller pods are running successfully"
        else
            print_error "Controller pods are not ready. Check logs with: kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
        fi
    else
        print_error "Controller deployment not found"
        rm -f iam_policy.json
        return 1
    fi

    # Clean up downloaded files
    rm -f iam_policy.json additional_permissions.json

    print_success "AWS Load Balancer Controller setup completed"
}

verify_setup() {
    print_status "Verifying EKS setup..."

    # Check cluster status
    CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
    print_status "Cluster Status: $CLUSTER_STATUS"

    # Check nodes
    print_status "Cluster Nodes:"
    kubectl get nodes -o wide

    # Check namespaces
    print_status "Available Namespaces:"
    kubectl get namespaces

    # Check if Load Balancer Controller is running
    print_status "AWS Load Balancer Controller Status:"
    kubectl get deployment -n kube-system aws-load-balancer-controller || print_warning "Load Balancer Controller not found"

    print_success "EKS cluster verification completed"
}

print_next_steps() {
    echo
    print_success "EKS setup completed successfully!"
    echo
    print_status "Next steps:"
    echo "Deploy your application to EKS:"
    echo "   make eks-deploy"
    echo
    print_status "Cluster Name: $CLUSTER_NAME"
    print_status "Region: $REGION"
    print_status "ECR Repository: $ECR_URI"
    print_status "Namespace: $NAMESPACE"
}

main() {
    echo "==========================================="
    echo "        EKS Setup for QR Generator        "
    echo "==========================================="
    echo

    check_prerequisites
    create_ecr_repository
    create_eks_cluster
    configure_kubectl
    create_namespace
    setup_aws_load_balancer_controller
    verify_setup
    print_next_steps
}

# Check if Helm is installed, install if not
if ! command -v helm &> /dev/null; then
    print_status "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Run main function
main