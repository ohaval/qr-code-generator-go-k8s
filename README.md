# QR Code Generator - Go + Kubernetes

A high-performance QR code generation service built with Go, containerized with Docker, and deployed on Kubernetes. Perfect for generating QR codes on-demand with support for both local development and production deployments on AWS EKS.

## 🚀 Quick Start

```bash
# Run locally
make run

# Test the API
curl -X POST 'http://localhost:8080/api/v1/qr/generate?text=hello' --output qr.png
```

## 📋 Overview

This project demonstrates a complete cloud-native application lifecycle:

- **Backend**: Go service with RESTful API for QR code generation
- **Containerization**: Multi-stage Docker build with security best practices
- **Local Development**: Kubernetes deployment using kind cluster
- **Production**: AWS EKS deployment with auto-scaling and load balancing
- **Testing**: Comprehensive unit tests, E2E tests, and load testing
- **CI/CD**: Automated workflows for quality assurance

### API Endpoints

- `GET /health` - Health check endpoint
- `POST /api/v1/qr/generate?text=<content>` - Generate QR code (returns PNG image)
- `GET /` - API info message

## 🐳 Docker Usage

### Quick Docker Setup

```bash
# Build and run with Docker
make docker-dev

# Or step by step:
make docker-build
make docker-run
```

### Manual Docker Commands

```bash
# Build the image
docker build -t qr-generator .

# Run container
docker run -d --name qr-generator-container -p 8080:8080 qr-generator

# Test the service
curl -X POST 'http://localhost:8080/api/v1/qr/generate?text=hello' --output qr.png

# Stop and clean up
make docker-stop
make docker-clean
```

### Docker Features

- Multi-stage build for optimized image size
- Non-root user for security
- Health checks with wget
- Alpine Linux base for minimal footprint
- Proper signal handling and graceful shutdown

## 🏠 Local Kubernetes (kind)

### Complete Local Setup

```bash
# Set up kind cluster and deploy application
make k8s-setup
```

This command:
- Creates a kind cluster named `qr-generator`
- Builds and loads the Docker image
- Deploys the application with 2 replicas
- Sets up service and port forwarding

### Manual kind Commands

```bash
# Check deployment status
make k8s-status

# View application logs
make k8s-logs

# Port forward to access the service
kubectl port-forward service/qr-generator-service 8080:80

# Test the service
curl -X POST 'http://localhost:8080/api/v1/qr/generate?text=hello' --output qr.png

# Clean up kind cluster
make k8s-clean
```

### Local Kubernetes Features

- 2 replicas for high availability
- Resource limits and requests
- Health checks (liveness and readiness probes)
- Security context with non-root user
- Service with ClusterIP for internal access

## ☁️ AWS EKS Production Deployment

### Complete EKS Setup

```bash
# Set up EKS cluster, ECR, and Load Balancer Controller
make eks-setup

# Deploy application to EKS
make eks-deploy
```

### Manual EKS Commands

```bash
# Check deployment status
kubectl get pods,services,ingress -n qr-generator

# View application logs
kubectl logs -l app=qr-generator -n qr-generator --tail=50 -f

# Get the ALB endpoint
kubectl get ingress qr-generator-ingress -n qr-generator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test the service
curl -X POST 'http://<ALB-ENDPOINT>/api/v1/qr/generate?text=hello' --output qr.png

# Destroy EKS cluster
make eks-destroy
```

### EKS Production Features

- **Auto-scaling**: Horizontal Pod Autoscaler (3-10 replicas)
- **Load balancing**: AWS Application Load Balancer
- **Container registry**: Amazon ECR for image storage
- **Resource management**: CPU and memory limits/requests
- **Security**: Non-root containers, read-only filesystem
- **Monitoring**: Health checks and readiness probes

## 🧪 Testing

### Unit Tests

```bash
# Run unit tests
make test
```

### End-to-End Tests

```bash
# Test against local service
make e2e-test

# Test against EKS deployment (auto-detects ALB URL)
make e2e-test-eks
```

### Load Testing

```bash
# Run load tests against EKS deployment
make load-test
```

The load test:
- Ramps up to 100 concurrent users
- Tests both health and QR generation endpoints
- Validates response times and error rates
- Requires k6 to be installed (`brew install k6`)

## 🛠️ Development

### Prerequisites

- Go 1.23.5+
- Docker
- kubectl
- kind (for local Kubernetes)
- AWS CLI (for EKS deployment)
- k6 (for load testing)

### Development Commands

```bash
# Run locally
make run

# Run tests
make test

# Lint code
make lint

# Install test tools
make install-test-tools
```

### Project Structure

```
├── main.go                 # Main application
├── main_test.go           # Unit tests
├── e2e_test.go            # End-to-end tests
├── Dockerfile             # Multi-stage Docker build
├── Makefile               # Build and deployment commands
├── k8s/                   # Kubernetes manifests
│   ├── kind/              # Local development
│   └── eks/               # Production deployment
├── scripts/               # Automation scripts
├── load-tests/            # Performance testing
└── docs/                  # Project documentation
```

## 📊 Performance

The service is designed for high performance:

- **Response time**: <200ms for QR generation
- **Throughput**: Handles 100+ concurrent users
- **Auto-scaling**: Scales based on CPU and memory usage
- **Resource efficiency**: Minimal memory footprint (~32Mi per pod)
