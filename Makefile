.PHONY: help fmt vet lt install-test-tools test run docker-build docker-run docker-stop docker-clean docker-dev k8s-setup k8s-status k8s-logs k8s-clean e2e-test eks-setup eks-deploy eks-destroy e2e-test-eks

# Show available commands
help:
	@echo "Available commands:"
	@echo "  Development:"
	@echo "    run           - Run the application locally"
	@echo "    test          - Run tests"
	@echo "    lt            - Run go fmt and go vet"
	@echo "  Docker:"
	@echo "    docker-build  - Build Docker image"
	@echo "    docker-run    - Run Docker container"
	@echo "    docker-stop   - Stop and remove container"
	@echo "    docker-clean  - Clean up images and containers"
	@echo "    docker-dev    - Build and run container (dev workflow)"
	@echo "  Kubernetes (Local):"
	@echo "    k8s-setup     - Complete local Kubernetes setup with kind cluster"
	@echo "    k8s-status    - Show deployment status"
	@echo "    k8s-logs      - Show application logs"
	@echo "    k8s-clean     - Remove kind cluster completely"
	@echo "  EKS (Production):"
	@echo "    eks-setup     - Set up EKS cluster, ECR, and AWS Load Balancer Controller"
	@echo "    eks-deploy    - Build, push to ECR, and deploy application to EKS"
	@echo "    eks-destroy   - Completely destroy EKS cluster and all related resources"
	@echo "  Testing:"
	@echo "    e2e-test      - Run end-to-end tests (requires service running with port forwarding)"
	@echo "    e2e-test-eks  - Run end-to-end tests against EKS (auto-detects ALB URL, requires auth)"

# Combined linting target
lt:
	go fmt ./...
	go vet ./...

# Install linting tools
install-test-tools:
	go install gotest.tools/gotestsum@latest

# Run tests with colorful output (default)
test:
	@echo "🧪 Running unit tests..."
	gotestsum --format testname -- -tags="!e2e" ./...

# Run the application
run:
	go run main.go

# Docker commands
IMAGE_NAME := qr-generator
CONTAINER_NAME := qr-generator-container
PORT := 8080

# Build Docker image
docker-build:
	docker build -t $(IMAGE_NAME) .

# Run Docker container
docker-run:
	docker run -d --name $(CONTAINER_NAME) -p $(PORT):$(PORT) $(IMAGE_NAME)
	@echo "Container started at http://localhost:$(PORT)"
	@echo "Health check: curl http://localhost:$(PORT)/health"
	@echo "Generate QR: curl -X POST 'http://localhost:$(PORT)/api/v1/qr/generate?text=hello' --output qr.png"

# Stop and remove Docker container
docker-stop:
	-docker stop $(CONTAINER_NAME)
	-docker rm $(CONTAINER_NAME)

# Clean up Docker images and containers
docker-clean: docker-stop
	-docker rmi $(IMAGE_NAME)
	-docker system prune -f

# Build and run (for development)
docker-dev: docker-stop docker-build docker-run

# Kubernetes commands
k8s-setup:
	# Complete setup of local Kubernetes environment with kind cluster
	./scripts/setup-k8s-local.sh

k8s-status:
	kubectl get pods,services,deployments -l app=qr-generator

k8s-logs:
	kubectl logs -l app=qr-generator --tail=50 -f

k8s-clean:
	# Remove kind cluster completely
	kind delete cluster --name qr-generator

# E2E testing
e2e-test:
	# Run end-to-end tests against specified target
	# Usage: make e2e-test (uses localhost:8080)
	# Usage: E2E_BASE_URL=http://your-service.com make e2e-test
	@echo "🧪 Running E2E tests..."
	@if [ -n "$(E2E_BASE_URL)" ]; then \
		echo "🎯 Target: $(E2E_BASE_URL)"; \
	else \
		echo "🎯 Target: http://localhost:8080 (default)"; \
		echo "⚠️  For localhost testing, make sure service is running with port forwarding:"; \
		echo "   kubectl port-forward service/qr-generator-service 8080:80"; \
	fi
	gotestsum --format testname -- -tags="e2e" ./...

# EKS E2E testing
e2e-test-eks:
	# Run end-to-end tests against EKS deployment
	# Dynamically fetches the ALB endpoint from the ingress resource
	@echo "🧪 Running E2E tests against EKS deployment..."
	@echo "🔍 Fetching ALB endpoint from ingress..."
	@INGRESS_HOST=$$(kubectl get ingress qr-generator-ingress -n qr-generator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	if [ -z "$$INGRESS_HOST" ]; then \
		echo "❌ Could not fetch ingress hostname. Make sure:"; \
		echo "   1. You're authenticated"; \
		echo "   2. The EKS cluster is accessible"; \
		echo "   3. The ingress resource exists: kubectl get ingress -n qr-generator"; \
		exit 1; \
	fi; \
	echo "🎯 Target: http://$$INGRESS_HOST"; \
	E2E_BASE_URL="http://$$INGRESS_HOST" gotestsum --format testname -- -tags="e2e" ./...

# EKS commands
eks-setup:
	# Set up complete EKS environment with cluster, ECR, and Load Balancer Controller
	./scripts/setup-eks.sh

eks-deploy:
	# Build, push to ECR, and deploy application to EKS cluster
	./scripts/deploy-app.sh

eks-destroy:
	# Completely destroy EKS cluster and all related resources
	./scripts/teardown-eks.sh
