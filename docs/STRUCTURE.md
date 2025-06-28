# Current Project Structure

```
qr-code-generator-go-k8s/
├── README.md                    # Basic project description
├── go.mod                       # Go module definition and dependencies
├── go.sum                       # Dependency lock file
├── main.go                      # Main application with QR code generation functionality
├── main_test.go                 # Unit tests for QR code generation
├── e2e_test.go                  # End-to-end integration tests
├── Dockerfile                   # Multi-stage Docker build configuration
├── Makefile                     # Build, format, lint, test, Docker, and Kubernetes targets
├── k8s/                         # Kubernetes manifests
│   ├── kind/                    # Local development with kind
│   │   ├── deployment.yaml      # Application deployment for kind cluster
│   │   └── service.yaml         # Service configuration for kind cluster
│   └── eks/                     # Production deployment on EKS
│       ├── deployment.yaml      # Application deployment for EKS with ECR image
│       ├── service.yaml         # Service configuration for EKS
│       └── ingress.yaml         # ALB Ingress with AWS Load Balancer Controller
├── scripts/                     # Automation scripts
│   ├── setup-k8s-local.sh      # Local Kubernetes environment setup with kind
│   ├── setup-eks.sh            # Complete EKS cluster setup with ECR and ALB
│   └── deploy-app.sh            # Build, push to ECR, and deploy to EKS
└── docs/                        # Project documentation
    ├── PROJECT_PLAN.md          # Development phases and current progress
    └── STRUCTURE.md             # Current project structure (this file)
```

## Current Endpoints
- `GET /` - API info message ("QR Code Generator API")
- `GET /health` - Health check endpoint (returns JSON status)
- `POST /api/v1/qr/generate?text=<text>` - Generate QR code (returns PNG image)
- All other paths return 404 Not Found
