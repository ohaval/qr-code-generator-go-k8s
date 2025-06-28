#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="qr-generator"
IMAGE_NAME="qr-generator:latest"

echo -e "${GREEN}🚀 Setting up local Kubernetes environment for QR Code Generator${NC}"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-120}

    echo -e "${YELLOW}⏳ Waiting for $deployment to be ready...${NC}"
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $deployment is ready!${NC}"
        return 0
    else
        echo -e "${RED}❌ $deployment failed to become ready within ${timeout}s${NC}"
        return 1
    fi
}

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl not found. Please install it first.${NC}"
    exit 1
fi

if ! command_exists kind; then
    echo -e "${RED}❌ kind not found. Please install it first.${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker not found. Please install it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites found${NC}"

# Check if cluster exists
echo -e "${BLUE}🔍 Checking for existing kind cluster...${NC}"
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}⚠️  Cluster '${CLUSTER_NAME}' already exists${NC}"
    echo -e "${YELLOW}   Using existing cluster${NC}"
else
    echo -e "${BLUE}🏗️  Creating kind cluster: ${CLUSTER_NAME}${NC}"
    kind create cluster --name $CLUSTER_NAME
    echo -e "${GREEN}✅ Cluster created successfully${NC}"
fi

# Ensure kubectl is using the right context
echo -e "${BLUE}🔧 Setting kubectl context...${NC}"
kubectl config use-context kind-$CLUSTER_NAME >/dev/null
echo -e "${GREEN}✅ kubectl context set to kind-${CLUSTER_NAME}${NC}"

# Build Docker image
echo -e "${BLUE}🏗️  Building Docker image...${NC}"
echo -e "${YELLOW}📦 Building QR generator image...${NC}"
docker build -t $IMAGE_NAME . >/dev/null
echo -e "${GREEN}✅ Docker image built successfully${NC}"

# Load image into kind cluster
echo -e "${BLUE}📥 Loading image into kind cluster...${NC}"
kind load docker-image $IMAGE_NAME --name $CLUSTER_NAME >/dev/null
echo -e "${GREEN}✅ Image loaded into cluster${NC}"

# Deploy Kubernetes resources
echo -e "${BLUE}🚀 Deploying Kubernetes resources...${NC}"
kubectl apply -f k8s/ >/dev/null
echo -e "${GREEN}✅ Kubernetes manifests applied${NC}"

# Wait for deployment to be ready
wait_for_deployment qr-generator

# Verify deployment
echo -e "${BLUE}🔍 Verifying deployment...${NC}"
echo ""

# Show cluster status
echo -e "${YELLOW}📊 Cluster Status:${NC}"
kubectl get pods -l app=qr-generator

echo ""
echo -e "${YELLOW}🌐 Services:${NC}"
kubectl get services -l app=qr-generator

echo ""

# Test the service
echo -e "${BLUE}🧪 Testing QR generator service...${NC}"

# Wait a bit more for pods to fully start
sleep 5

# Test health endpoint
echo -e "${YELLOW}🔍 Testing health endpoint...${NC}"
if kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -- curl -s http://qr-generator-service/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Health endpoint is responding${NC}"
else
    echo -e "${RED}❌ Health endpoint test failed${NC}"
fi

# Test QR generation endpoint
echo -e "${YELLOW}🔍 Testing QR generation...${NC}"
if kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -- curl -s -X POST 'http://qr-generator-service/api/v1/qr/generate?text=test' --output /dev/null >/dev/null 2>&1; then
    echo -e "${GREEN}✅ QR generation endpoint is working${NC}"
else
    echo -e "${RED}❌ QR generation test failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Local Kubernetes environment is ready!${NC}"
echo ""
echo -e "${YELLOW}📋 Quick Info:${NC}"
echo "  • Cluster: $CLUSTER_NAME"
echo "  • Context: kind-$CLUSTER_NAME"
echo "  • Image: $IMAGE_NAME"
echo ""
echo -e "${YELLOW}🧪 Test commands:${NC}"
echo "  • Status: make k8s-status"
echo "  • Logs: make k8s-logs"
echo "  • Port forward: kubectl port-forward service/qr-generator-service 8080:80"
echo "  • Test health: curl http://localhost:8080/health"
echo "  • Generate QR: curl -X POST 'http://localhost:8080/api/v1/qr/generate?text=hello' --output qr.png"
echo ""
echo -e "${YELLOW}🛑 Cleanup commands:${NC}"
echo "  • Remove deployment: make k8s-delete"
echo "  • Remove cluster: kind delete cluster --name $CLUSTER_NAME"