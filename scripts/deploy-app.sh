#!/bin/bash

set -e

# Configuration (matching setup-eks.sh)
CLUSTER_NAME="qr-generator-cluster"
REGION="us-east-1"
ECR_REPO_NAME="qr-code-generator"
NAMESPACE="qr-generator"

# Colors for output (matching setup-eks.sh)
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

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Check AWS CLI and configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi

    # Check kubectl configuration
    if ! kubectl get nodes &> /dev/null; then
        print_error "kubectl not configured for the cluster. Please run setup-eks.sh first."
        exit 1
    fi

    print_success "All prerequisites are satisfied"
}

login_to_ecr() {
    print_status "Logging into Amazon ECR..."

    # Get ECR repository URI
    ECR_URI=$(aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION --query 'repositories[0].repositoryUri' --output text)
    if [ -z "$ECR_URI" ]; then
        print_error "Failed to get ECR repository URI. Please make sure the repository exists."
        exit 1
    fi
    print_status "ECR Repository URI: $ECR_URI"

    # Login to ECR
    if aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI; then
        print_success "Successfully logged into ECR"
    else
        print_error "Failed to login to ECR"
        exit 1
    fi
}

build_and_push_image() {
    print_status "Building Docker image for AMD64 architecture..."
    print_status "Note: Building for AMD64 to ensure compatibility with EKS nodes"

    if docker build --platform linux/amd64 -t $ECR_REPO_NAME .; then
        print_success "Docker image built successfully for AMD64"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi

    print_status "Tagging Docker image..."
    if docker tag $ECR_REPO_NAME:latest $ECR_URI:latest; then
        print_success "Docker image tagged successfully"
    else
        print_error "Failed to tag Docker image"
        exit 1
    fi

    print_status "Pushing Docker image to ECR..."
    if docker push $ECR_URI:latest; then
        print_success "Docker image pushed successfully"
    else
        print_error "Failed to push Docker image"
        exit 1
    fi
}

verify_k8s_manifests() {
    print_status "Verifying Kubernetes manifests..."

    # Check if EKS manifests directory exists
    if [ ! -d "k8s/eks" ]; then
        print_error "k8s/eks directory not found"
        exit 1
    fi

    # Check if required manifests exist
    if [ ! -f "k8s/eks/deployment.yaml" ]; then
        print_error "k8s/eks/deployment.yaml not found"
        exit 1
    fi

    if [ ! -f "k8s/eks/service.yaml" ]; then
        print_error "k8s/eks/service.yaml not found"
        exit 1
    fi

    print_success "Kubernetes manifests verified"
}

deploy_application() {
    print_status "Deploying application to Kubernetes..."

    # Apply EKS-specific kubernetes manifests
    if kubectl apply -f k8s/eks/ -n $NAMESPACE; then
        print_success "Kubernetes manifests applied successfully"
    else
        print_error "Failed to apply Kubernetes manifests"
        exit 1
    fi

    # Wait for deployment to be ready
    print_status "Waiting for deployment to be ready..."
    if kubectl wait --for=condition=available deployment --all -n $NAMESPACE --timeout=120s; then
        print_success "Deployment is ready"
    else
        print_error "Deployment failed to become ready"
        print_status "Check deployment status with: kubectl describe deployment -n $NAMESPACE"
        exit 1
    fi
}

verify_deployment() {
    print_status "Verifying deployment..."

    # Check pods
    print_status "Pod status:"
    kubectl get pods -n $NAMESPACE

    # Check services
    print_status "Service status:"
    kubectl get services -n $NAMESPACE

    # If we have any ingress resources
    if kubectl get ingress -n $NAMESPACE &> /dev/null; then
        print_status "Ingress status:"
        kubectl get ingress -n $NAMESPACE
    fi

    print_success "Deployment verification completed"
}

print_access_info() {
    echo
    print_success "Application deployed successfully!"
    echo
    print_status "Access Information:"

    # Get ingress information
    INGRESS_HOST=$(kubectl get ingress qr-generator-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$INGRESS_HOST" ]; then
        echo "Application Endpoint: http://$INGRESS_HOST"
        echo "Health Check: curl http://$INGRESS_HOST/health"
        echo "Generate QR: curl -X POST 'http://$INGRESS_HOST/api/v1/qr/generate?text=hello' --output qr.png"
    else
        print_warning "Application endpoint not yet available. It may take a few minutes to provision."
        print_status "Check status with: kubectl get ingress qr-generator-ingress -n $NAMESPACE"
    fi

    echo
    print_status "Useful Commands:"
    echo "View logs: kubectl logs -n $NAMESPACE -l app=qr-generator"
    echo "View pod details: kubectl describe pod -n $NAMESPACE -l app=qr-generator"
    echo "View service: kubectl describe service qr-generator-service -n $NAMESPACE"
    echo "View Ingress: kubectl describe ingress qr-generator-ingress -n $NAMESPACE"
}

main() {
    echo "==========================================="
    echo "      QR Generator App Deployment"
    echo "==========================================="
    echo

    check_prerequisites
    login_to_ecr
    build_and_push_image
    verify_k8s_manifests
    deploy_application
    verify_deployment
    print_access_info
}

# Run main function
main