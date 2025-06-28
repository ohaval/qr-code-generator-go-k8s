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
├── .dockerignore                # Docker build exclusions
├── Makefile                     # Build, format, lint, test, Docker, and Kubernetes targets
├── .github/workflows/           # CI/CD workflows
│   ├── linting.yaml             # Go linting workflow
│   └── tests.yaml               # Unit and integration test workflow
├── k8s/                         # Kubernetes manifests
│   ├── deployment.yaml          # Application deployment with 3 replicas and health checks
│   └── service.yaml             # ClusterIP and LoadBalancer services
├── scripts/                     # Automation scripts
│   └── setup-k8s-local.sh      # Complete local Kubernetes environment setup
└── docs/                        # Project documentation
    ├── PROJECT_PLAN.md          # Combined project plan, architecture, and development phases
    └── STRUCTURE.md             # Current project structure (this file)
```

## Current Endpoints
- `GET /` - API info message ("QR Code Generator API")
- `GET /health` - Health check endpoint (returns JSON status)
- `POST /api/v1/qr/generate?text=<text>` - Generate QR code (returns PNG image)
- All other paths return 404 Not Found
