SHELL := /bin/bash

################################################################################
# Binaries
# All binary paths can be overridden via environment variables or CLI arguments
# Example: make go/lint GOLANGCI_LINT=/custom/path/golangci-lint
################################################################################

GO ?= go
GOLANGCI_LINT ?= golangci-lint
TEE ?= tee
GREP ?= grep
FIND ?= find

################################################################################
# Configuration Variables
# Precedence chain: ENV VAR > CLI option > file config > default value
#
# Examples:
#   Override via environment: export GO_LINT_TIMEOUT=5m
#   Override via CLI: make go/lint GO_LINT_TIMEOUT=5m
#   Override via this file: modify the defaults below
################################################################################

# Go Test Configuration
GO_TEST_DIRECTORIES ?= tests
GO_TEST_TIMEOUT ?= 2h
GO_TEST_READONLY_DIRECTORY ?= post_deploy_functional_readonly
GO_TEST_COUNT ?= 1
GO_TEST_VERBOSE ?= -v
GO_TEST_EXTRA_FLAGS ?=

# Go Lint Configuration
GO_LINT_TIMEOUT ?= 15m
GO_LINT_CONFIG ?= .golangci.yaml
GO_LINT_VERBOSE ?= -v
GO_LINT_EXTRA_FLAGS ?=

# Test Filtering (for readonly vs non-readonly tests)
TEST_RUN_ONLY_READONLY ?=
TEST_RUN_EXCLUDE_READONLY ?= -v

# Feature Flags
DISABLE_MAKE_CHECK_LINT ?= false

# Internal Variables
CURRENT_DIR = $(notdir $(shell pwd))

# If ARM_SUBSCRIPTION_ID is not already set by the environment, we'll try to use the `az` command
# to retrieve it. If `az` isn't found, we'll silently continue here and catch that case elsewhere.
export ARM_SUBSCRIPTION_ID ?= $(shell command -v az >/dev/null 2>&1 && az account show | jq -r .id)

################################################################################
# Functions
################################################################################

# Runs golangci-lint on a directory if Go files exist
# Uses only configurable variables - no hard-coded values
# Arguments:
#   $(1) - Directory to lint (e.g., "tests")
# https://golangci-lint.run/usage/quick-start/
define go_lint
	@if $(FIND) $(1)/ -name '*.go' 2>/dev/null | $(GREP) -q '\.go'; then \
		echo "Running golangci-lint on ./$(1)/..."; \
		$(GOLANGCI_LINT) run \
			$$(test -n "$(GO_LINT_TIMEOUT)" && echo "--timeout $(GO_LINT_TIMEOUT)") \
			$$(test -f "$(GO_LINT_CONFIG)" && echo "-c $(GO_LINT_CONFIG)") \
			$(GO_LINT_VERBOSE) \
			$(GO_LINT_EXTRA_FLAGS) \
			./$(1)/...; \
	else \
		echo "No Go files found in $(1)/, skipping lint"; \
	fi
endef

# Runs Go tests on a directory if Go files exist
# Uses only configurable variables - no hard-coded values
# Arguments:
#   $(1) - Directory to test (e.g., "tests")
#   $(2) - GREP filter for readonly directory (empty to include only, -v to exclude)
define go_test
	@if $(FIND) $(1)/ -name '*.go' 2>/dev/null | $(GREP) $(2) $(GO_TEST_READONLY_DIRECTORY) | $(GREP) -q '\.go'; then \
		echo "Running Go tests on ./$(1)/... (readonly filter: $(2))"; \
		$(GO) test \
			$(GO_TEST_VERBOSE) \
			-count=$(GO_TEST_COUNT) \
			-timeout=$(GO_TEST_TIMEOUT) \
			$(GO_TEST_EXTRA_FLAGS) \
			$$($(GO) list ./$(1)/... | $(GREP) $(2) $(GO_TEST_READONLY_DIRECTORY)); \
	else \
		echo "No matching Go test files found in $(1)/, skipping tests"; \
	fi
endef

################################################################################
# Validation and Help
################################################################################

.PHONY: go/help
go/help:
	@echo "Go Testing and Linting Targets"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo "  go/lint              - Run golangci-lint on all test directories"
	@echo "  go/test              - Run Go tests (excludes readonly tests)"
	@echo "  go/readonly_test     - Run only readonly tests"
	@echo "  go/list              - List all test directories"
	@echo "  go/validate          - Validate configuration"
	@echo "  go/help              - Show this help message"
	@echo ""
	@echo "Configuration variables (precedence: ENV > CLI > file > default):"
	@echo "  GO_TEST_DIRECTORIES  - Directories to test (default: $(GO_TEST_DIRECTORIES))"
	@echo "  GO_TEST_TIMEOUT      - Test timeout (default: $(GO_TEST_TIMEOUT))"
	@echo "  GO_LINT_TIMEOUT      - Lint timeout (default: $(GO_LINT_TIMEOUT))"
	@echo "  GO_LINT_CONFIG       - Lint config file (default: $(GO_LINT_CONFIG))"
	@echo "  GO_LINT_EXTRA_FLAGS  - Additional lint flags"
	@echo "  GO_TEST_EXTRA_FLAGS  - Additional test flags"
	@echo ""
	@echo "Examples:"
	@echo "  make go/lint GO_LINT_TIMEOUT=5m"
	@echo "  make go/test GO_TEST_TIMEOUT=1h GO_TEST_EXTRA_FLAGS='-race'"
	@echo "  export GO_LINT_CONFIG=.golangci.yml && make go/lint"

.PHONY: go/validate
go/validate:
	@echo "Validating Go configuration..."
	@command -v $(GO) >/dev/null 2>&1 || { echo "Error: Go binary '$(GO)' not found in PATH"; exit 1; }
	@command -v $(GOLANGCI_LINT) >/dev/null 2>&1 || { echo "Error: golangci-lint binary '$(GOLANGCI_LINT)' not found in PATH"; exit 1; }
	@test -n "$(GO_TEST_DIRECTORIES)" || { echo "Error: GO_TEST_DIRECTORIES is empty"; exit 1; }
	@if [ -n "$(GO_LINT_CONFIG)" ] && [ ! -f "$(GO_LINT_CONFIG)" ]; then \
		echo "Warning: Lint config file '$(GO_LINT_CONFIG)' not found, golangci-lint will use defaults"; \
	fi
	@echo "✓ Go binary: $$($(GO) version)"
	@echo "✓ golangci-lint: $$($(GOLANGCI_LINT) version 2>/dev/null || echo 'version unknown')"
	@echo "✓ Test directories: $(GO_TEST_DIRECTORIES)"
	@echo "✓ Configuration validated successfully"

################################################################################
# Tasks
################################################################################

.PHONY: go/test/environment/az
go/test/environment/az:
ifeq (,$(ARM_SUBSCRIPTION_ID))
	$(error "ARM_SUBSCRIPTION_ID was not set and `az` was not found in your PATH.")
else
	@echo "Terratest will use Azure Subscription ID $$ARM_SUBSCRIPTION_ID"
endif

.PHONY: go/test/environment/aws
go/test/environment/aws:
	@echo "No environment configuration for AWS is defined."

.PHONY: go/test/environment/gcp
go/test/environment/gcp:
	@echo "No environment configuration for GCP is defined."

# Performs any environmental setup required for a cloud provider based on the name of the repository.
.PHONY: go/test/environment
go/test/environment:
ifneq (,$(findstring tf-aws,$(CURRENT_DIR)))
	$(MAKE) go/test/environment/aws
else ifneq (,$(findstring tf-az,$(CURRENT_DIR)))
	$(MAKE) go/test/environment/az
else ifneq (,$(findstring tf-gcp,$(CURRENT_DIR)))
	$(MAKE) go/test/environment/gcp
else
	@echo "Unrecognized module type, no environmental setup will be performed."
endif


.PHONY: go/list
go/list :
	@echo -n "Test dirs: "
	@echo $(GO_TEST_DIRECTORIES) | tr ' ' '\n' | sort

.PHONY: go/lint
go/lint : go/validate
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_lint,$(test_dir)))

.PHONY: go/test
go/test : go/validate go/test/environment
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_test,$(test_dir),$(TEST_RUN_EXCLUDE_READONLY)))

.PHONY: go/readonly_test
go/readonly_test: go/validate go/test/environment
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_test,$(test_dir),$(TEST_RUN_ONLY_READONLY)))

.PHONY: lint
lint::
ifeq ($(DISABLE_MAKE_CHECK_LINT),false)
	$(MAKE) go/lint
else
	$(info "make go/lint has been disabled!")
endif

.PHONY: test
test:: tfmodule/plan
	$(MAKE) go/test
