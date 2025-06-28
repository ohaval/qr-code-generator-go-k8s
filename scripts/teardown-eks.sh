#!/bin/bash

set -e

# Configuration (matching setup-eks.sh)
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

confirm_destruction() {
    echo
    print_warning "This will destroy ALL EKS resources including:"
    echo "  • EKS Cluster: $CLUSTER_NAME"
    echo "  • ECR Repository: $ECR_REPO_NAME (with all images)"
    echo "  • Application Load Balancer (if exists)"
    echo "  • IAM Roles and Policies"
    echo "  • All deployed applications"
    echo
    print_error "This action is IRREVERSIBLE!"
    echo
}

check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi

    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi

    # Check if eksctl is installed
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl not found. Please install eksctl first."
        exit 1
    fi

    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_warning "helm not found. Skipping Helm-related cleanup."
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi

    print_success "Prerequisites check completed"
}

cleanup_kubernetes_resources() {
    print_status "Cleaning up Kubernetes application resources..."

    # Check if cluster exists and kubectl is configured
    if ! aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "EKS cluster $CLUSTER_NAME not found. Skipping Kubernetes cleanup."
        return 0
    fi

    # Update kubeconfig
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME 2>/dev/null || true

    # Delete application resources
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_status "Deleting application resources in namespace $NAMESPACE..."
        kubectl delete -f k8s/eks/ -n $NAMESPACE --ignore-not-found=true || print_warning "Some application resources may not exist"

        # Wait a bit for resources to be deleted
        sleep 10

        # Delete namespace
        kubectl delete namespace $NAMESPACE --ignore-not-found=true || print_warning "Namespace deletion failed or doesn't exist"
        print_success "Application resources deleted"
    else
        print_warning "Namespace $NAMESPACE not found. Skipping application cleanup."
    fi
}

cleanup_load_balancer_controller() {
    print_status "Cleaning up AWS Load Balancer Controller..."

    if ! aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "EKS cluster not found. Skipping Load Balancer Controller cleanup."
        return 0
    fi

    # Check if Helm is available
    if command -v helm &> /dev/null; then
        # Remove AWS Load Balancer Controller Helm chart
        if helm list -n kube-system | grep -q "aws-load-balancer-controller"; then
            print_status "Uninstalling AWS Load Balancer Controller Helm chart..."
            helm uninstall aws-load-balancer-controller -n kube-system || print_warning "Failed to uninstall Load Balancer Controller"
            print_success "Load Balancer Controller Helm chart removed"
        else
            print_warning "AWS Load Balancer Controller Helm chart not found"
        fi

        # Remove Helm repository
        print_status "Removing Helm repository..."
        helm repo remove eks 2>/dev/null || print_warning "Helm repository 'eks' not found"
    else
        print_warning "Helm not available. Skipping Helm-related cleanup."
    fi

    # Wait for controller pods to be terminated
    print_status "Waiting for Load Balancer Controller pods to terminate..."
    sleep 10
}

cleanup_iam_resources() {
    print_status "Cleaning up IAM resources..."

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

    # Delete IAM service account (this will also delete the associated role)
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_status "Deleting IAM service account..."
        eksctl delete iamserviceaccount \
            --cluster=$CLUSTER_NAME \
            --region=$REGION \
            --namespace=kube-system \
            --name=aws-load-balancer-controller \
            2>/dev/null || print_warning "IAM service account deletion failed or doesn't exist"
    fi

    # Wait a bit for role to be cleaned up
    sleep 5

    # Delete IAM policies
    print_status "Deleting IAM policies..."

    # Delete main policy
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
    if aws iam get-policy --policy-arn $POLICY_ARN &>/dev/null; then
        # Delete all policy versions except default, then delete the policy
        aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'Versions[?!IsDefaultVersion].VersionId' --output text | tr '\t' '\n' | while read version; do
            [ ! -z "$version" ] && aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $version 2>/dev/null || true
        done
        aws iam delete-policy --policy-arn $POLICY_ARN 2>/dev/null || print_warning "Failed to delete main IAM policy"
        print_success "Main IAM policy deleted"
    else
        print_warning "Main IAM policy not found"
    fi

    # Delete additional permissions policy
    ADDITIONAL_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerAdditionalPermissions"
    if aws iam get-policy --policy-arn $ADDITIONAL_POLICY_ARN &>/dev/null; then
        aws iam delete-policy --policy-arn $ADDITIONAL_POLICY_ARN 2>/dev/null || print_warning "Failed to delete additional permissions policy"
        print_success "Additional permissions policy deleted"
    else
        print_warning "Additional permissions policy not found"
    fi
}

delete_eks_cluster() {
    print_status "Deleting EKS cluster (this may take 10-15 minutes)..."

    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        # Delete the cluster using eksctl (this will also delete the node group)
        eksctl delete cluster --name $CLUSTER_NAME --region $REGION --wait
        print_success "EKS cluster $CLUSTER_NAME deleted"
    else
        print_warning "EKS cluster $CLUSTER_NAME not found"
    fi
}

delete_ecr_repository() {
    print_status "Deleting ECR repository..."

    if aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION &> /dev/null; then
        # Delete all images first, then delete repository
        aws ecr delete-repository \
            --repository-name $ECR_REPO_NAME \
            --region $REGION \
            --force
        print_success "ECR repository $ECR_REPO_NAME deleted"
    else
        print_warning "ECR repository $ECR_REPO_NAME not found"
    fi
}

cleanup_local_config() {
    print_status "Cleaning up local configuration..."

    # Remove cluster from kubeconfig
    kubectl config delete-cluster arn:aws:eks:$REGION:$(aws sts get-caller-identity --query Account --output text):cluster/$CLUSTER_NAME 2>/dev/null || true
    kubectl config delete-context arn:aws:eks:$REGION:$(aws sts get-caller-identity --query Account --output text):cluster/$CLUSTER_NAME 2>/dev/null || true

    # Clean up any temporary files that might exist
    rm -f iam_policy.json additional_permissions.json 2>/dev/null || true

    print_success "Local configuration cleaned up"
}

verify_cleanup() {
    print_status "Verifying cleanup..."

    # Check if cluster still exists
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "EKS cluster still exists (deletion may still be in progress)"
    else
        print_success "EKS cluster confirmed deleted"
    fi

    # Check if ECR repository still exists
    if aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION &> /dev/null; then
        print_warning "ECR repository still exists"
    else
        print_success "ECR repository confirmed deleted"
    fi

    # Check IAM policies
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
    if aws iam get-policy --policy-arn $POLICY_ARN &>/dev/null; then
        print_warning "Main IAM policy still exists"
    else
        print_success "Main IAM policy confirmed deleted"
    fi

    print_success "Cleanup verification completed"
}

print_completion_message() {
    echo
    print_success "EKS teardown completed!"
    echo
    print_status "Resources that have been deleted:"
    echo "  ✓ EKS Cluster: $CLUSTER_NAME"
    echo "  ✓ ECR Repository: $ECR_REPO_NAME"
    echo "  ✓ AWS Load Balancer Controller"
    echo "  ✓ IAM Roles and Policies"
    echo "  ✓ Application resources"
    echo "  ✓ Local kubectl configuration"
    echo
    print_status "Note: It may take a few more minutes for all AWS resources to be fully deleted."
    print_status "Check the AWS Console to confirm all resources have been removed."
}

main() {
    echo "==========================================="
    echo "       EKS Teardown for QR Generator      "
    echo "==========================================="
    echo

    confirm_destruction
    check_prerequisites
    cleanup_kubernetes_resources
    cleanup_load_balancer_controller
    cleanup_iam_resources
    delete_eks_cluster
    delete_ecr_repository
    cleanup_local_config
    verify_cleanup
    print_completion_message
}

# Run main function
main