# Project Plan

## Development Plan

### Phase 1: Core API Development
- [x] Set up Go project structure with proper modules
- [x] Add QR code generation library dependency
- [x] Implement core QR code generation function
- [x] Set up HTTP server with basic configuration (using net/http)
- [x] Implement `GET /health` endpoint
- [x] Implement `POST /api/v1/qr/generate` endpoint
- [x] Add simple request validation
- [x] Add proper error handling and HTTP status codes
- [x] Add basic logging
- [x] Write unit tests for QR generation
- [x] Test API manually with curl

### Phase 2: Containerization & Deployment
- [x] Create Dockerfile with multi-stage build
- [x] Build and test Docker image locally
- [x] Create Kubernetes deployment manifest
- [x] Create Kubernetes service manifest
- [x] Set up kind cluster locally
- [x] Deploy and test in kind cluster

### Phase 3: CI/CD & Quality Assurance
- [x] Set up GitHub Actions workflows
- [x] Implement automated linting workflow
- [x] Implement automated testing workflow (unit + integration)
- [x] Add end-to-end integration tests

### Phase 4: EKS Production Deployment
- [x] Create EKS automation setup script
- [x] Set up ECR repository for container images
- [x] Configure AWS Load Balancer Controller
- [x] Create EKS-specific Kubernetes manifests with Ingress
- [x] Create automated deployment script
- [x] Deploy application to EKS cluster
- [x] Inspect deployment status and health
- [x] Run end-to-end tests against EKS deployment
- [x] Validate production readiness

### Phase 5: Performance Testing & Monitoring
- [x] Install and configure k6 load testing tool
- [x] Create comprehensive load test scripts (health & QR generation endpoints)
- [ ] Configure Horizontal Pod Autoscaler (HPA) for automatic scaling
- [ ] Implement pod resource monitoring during load tests
- [ ] Run baseline performance tests to establish current capacity
- [ ] Analyze response time percentiles (p50, p95, p99) and error rates
- [ ] Set up CloudWatch monitoring for ALB and EKS metrics
- [ ] Create performance test automation scripts
- [ ] Document performance characteristics and scaling behavior
- [ ] Establish performance benchmarks and SLA targets
- [ ] Test HPA scaling behavior under different load patterns

## MVP Goals
- [x] Basic text/URL QR code generation
- [x] REST API with core endpoints
- [x] Docker containerization
- [x] Kubernetes deployment manifests
- [x] Basic error handling and validation
- [x] Automated CI/CD pipeline
- [x] Production-ready EKS deployment automation
- [x] Comprehensive e2e testing (local and production)

## Tech Stack
- **Backend**: Go (Golang) with standard net/http package
- **Infrastructure**: Kubernetes (kind for local, EKS for production)
- **Cloud Provider**: AWS (EKS, ECR, ALB)
- **API**: RESTful API with JSON responses (stateless)
- **Testing**: Go testing package + testify, integration tests
- **CI/CD**: GitHub Actions with automated linting and testing

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
- Application Load Balancer for ingress with AWS Load Balancer Controller

## Testing Strategy
- Unit tests for QR code generation functionality
- End-to-end integration tests for API endpoints
- Kubernetes deployment tests in kind cluster
- Automated CI/CD pipeline with GitHub Actions
