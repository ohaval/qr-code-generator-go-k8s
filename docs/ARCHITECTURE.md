# Architecture

## Tech Stack
- **Backend**: Go (Golang) with Gin web framework
- **Infrastructure**: Kubernetes (kind for local, EKS for production)
- **Cloud Provider**: AWS (EKS, ECR, ALB)
- **API**: RESTful API with JSON responses (stateless)
- **Testing**: Go testing package + testify, integration tests
- **CI/CD**: GitHub Actions with AWS deployment

## Deployment Options

### Local Development Environment (kind)
- Local Kubernetes cluster using kind
- Docker images built locally
- Port forwarding for local access
- Development configuration with debug logging

### Production Environment (EKS)
- AWS EKS cluster with managed node groups
- Container images stored in ECR
- Application Load Balancer for ingress

## System Components

### QR Code Generator Service
- Stateless service for generating QR codes on-demand
- Supports only URL QR code types
- No data persistence - generates and returns images directly
- No authentication or authorization

### Web API
- HTTP endpoints for QR code generation
- Health check endpoints

### Infrastructure
- Kubernetes manifests for deployment
- Helm charts for configuration management
- Ingress controller for external access
- ConfigMaps and Secrets for configuration

## Testing Strategy
- Unit tests for core QR generation logic
- Integration tests for API endpoints
- Kubernetes deployment tests in kind cluster
