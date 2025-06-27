# Current Project Structure

```
qr-code-generator-go-k8s/
├── README.md                    # Basic project description
├── go.mod                       # Go module definition and dependencies
├── go.sum                       # Dependency lock file
├── main.go                      # Main application with QR code generation functionality
├── main_test.go                 # Unit tests for QR code generation
├── Makefile                     # Build, format, lint, and test targets
└── docs/                        # Project documentation
    ├── PROJECT_PLAN.md          # Combined project plan, architecture, and development phases
    └── STRUCTURE.md             # Current project structure (this file)
```

## Current Endpoints
- `GET /` - API info message
- `GET /test-qr?text=<text>` - Generate QR code for testing (returns PNG image)
- All other paths return 404 Not Found
