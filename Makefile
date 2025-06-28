.PHONY: help fmt vet lt install-test-tools test run docker-build docker-run docker-stop docker-clean docker-dev

# Show available commands
help:
	@echo "Available commands:"
	@echo "  Development:"
	@echo "    run           - Run the application locally"
	@echo "    test          - Run tests"
	@echo "    fmt           - Format Go code"
	@echo "    vet           - Run go vet"
	@echo "    lt            - Run fmt and vet"
	@echo "  Docker:"
	@echo "    docker-build  - Build Docker image"
	@echo "    docker-run    - Run Docker container"
	@echo "    docker-stop   - Stop and remove container"
	@echo "    docker-clean  - Clean up images and containers"
	@echo "    docker-dev    - Build and run container (dev workflow)"

# Format Go source code according to Go's standard formatting rules
fmt:
	go fmt ./...

# Analyze Go code for suspicious constructs and potential bugs
vet:
	go vet ./...

# Combined linting target
lt: fmt vet

# Install linting tools
install-test-tools:
	go install gotest.tools/gotestsum@latest

# Run tests with colorful output (default)
test:
	gotestsum --format testname ./...

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
