# Makefile for process-dashboard
# Defines high-level tasks: lint, test, build, and docker-push.

# -------------------------------
# PHONY Targets
# -------------------------------
.PHONY: all lint test build-agent build-central docker-push fmt

# Default target
all: lint test

# -------------------------------
# Linting
# -------------------------------
# Lint all Bash scripts with shellcheck.
lint:
	@echo "Running ShellCheck on all Bash scripts..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "ShellCheck not found. Please install shellcheck."; exit 1; }
	@shellcheck scripts/agents/*.sh

# -------------------------------
# Testing
# -------------------------------
# Run Bats tests and Go tests.
test:
	@echo "Running Bats tests..."
	@command -v bats >/dev/null 2>&1 || { echo "Bats not found. Please install bats-core."; exit 1; }
	@cd tests/bats && bats .
	@echo "Running Go unit tests..."
	@cd scripts/central && go test ./...

# -------------------------------
# Formatting
# -------------------------------
# (Optional) Format Go code
fmt:
	@echo "Formatting Go code..."
	@cd scripts/central && go fmt ./...

# -------------------------------
# Build Agent (Bash)
# -------------------------------
# Placeholder: we can later package into a container.
build-agent:
	@echo "No build needed for Bash agent. Use Dockerfile.agent for containerization."

# -------------------------------
# Build Central Services (Go)
# -------------------------------
# Builds collector, notifier, and api_server binaries.
build-central:
	@echo "Building central Go binaries..."
	@cd scripts/central && \
		CGO_ENABLED=0 GOOS=linux go build -o collector collector.go && \
		CGO_ENABLED=0 GOOS=linux go build -o notifier notifier.go && \
		CGO_ENABLED=0 GOOS=linux go build -o api_server api_server.go

# -------------------------------
# Docker Images
# -------------------------------
# Build and push Docker images for agent and central components.
docker-push:
	@echo "Building and pushing Docker images..."
	@VERSION=$$(git rev-parse --short HEAD); \
	docker build -f docker/Dockerfile.agent -t myregistry.com/proc-dash/agent:$$VERSION .; \
	docker push myregistry.com/proc-dash/agent:$$VERSION; \
	docker build -f docker/Dockerfile.central -t myregistry.com/proc-dash/central:$$VERSION .; \
	docker push myregistry.com/proc-dash/central:$$VERSION

