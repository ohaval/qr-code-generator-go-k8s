# Project Plan

## Development Plan

### Phase 1: Core API Development
- [x] Set up Go project structure with proper modules
- [ ] Add QR code generation library dependency
- [ ] Implement core QR code generation function
- [ ] Set up Gin HTTP server with basic configuration
- [ ] Implement `GET /health` endpoint
- [ ] Implement `POST /api/v1/qr/generate` endpoint
- [ ] Add request validation (URL format, required fields)
- [ ] Add proper error handling and HTTP status codes
- [ ] Add basic logging
- [ ] Write integration tests for API endpoints
- [ ] Test API manually with curl/Postman

### Phase 2: Containerization & Deployment
- [ ] Create Dockerfile with multi-stage build
- [ ] Build and test Docker image locally
- [ ] Create Kubernetes deployment manifest
- [ ] Create Kubernetes service manifest
- [ ] Set up kind cluster locally
- [ ] Deploy and test in kind cluster
- [ ] Add proper configuration management (environment variables)
- [ ] Add resource limits and health checks to K8s manifests
- [ ] Test complete deployment flow

## MVP Goals
- [ ] Basic text/URL QR code generation
- [ ] REST API with core endpoints
- [ ] Docker containerization
- [ ] Kubernetes deployment manifests
- [ ] Basic error handling and validation

## Tech Stack
- **Backend**: Go (Golang) with Gin web framework
- **Infrastructure**: Kubernetes (kind for local, EKS for production)
- **Cloud Provider**: AWS (EKS, ECR, ALB)
- **API**: RESTful API with JSON responses (stateless)
- **Testing**: Go testing package + testify, integration tests
- **CI/CD**: GitHub Actions with AWS deployment

## API Endpoints
- `POST /api/v1/qr/generate` - Generate single QR code
- `GET /health` - Health check endpoint

## System Design

### QR Code Generator Service
- Stateless service for generating QR codes on-demand
- Supports only URL QR code types
- No data persistence - generates and returns images directly
- No authentication or authorization

### Deployment Options

#### Local Development (kind)
- Local Kubernetes cluster using kind
- Docker images built locally
- Port forwarding for local access

#### Production (EKS)
- AWS EKS cluster with managed node groups
- Container images stored in ECR
- Application Load Balancer for ingress

## Testing Strategy
- Integration tests for API endpoints
- Kubernetes deployment tests in kind cluster