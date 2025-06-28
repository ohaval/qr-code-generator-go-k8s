.PHONY: fmt vet lint lt install-tools test

# Format code
fmt:
	go fmt ./...

# Run go vet
vet:
	go vet ./...

# Run golangci-lint
lint:
	golangci-lint run

# Combined linting target
lt: fmt vet lint

# Install linting tools
install-tools:
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install honnef.co/go/tools/cmd/staticcheck@latest
	go install gotest.tools/gotestsum@latest

# Run tests with colorful output (default)
test:
	gotestsum --format testname ./...
