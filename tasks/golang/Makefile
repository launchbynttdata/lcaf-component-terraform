SHELL := /bin/bash

# Binaries

GO ?= go
GOLANGCI_LINT ?= golangci-lint
TEE ?= tee
GREP ?= grep
FIND ?= find

# Variables

GO_TEST_DIRECTORIES ?= tests
GO_LINT_TIMEOUT ?= 5m
GO_TEST_TIMEOUT ?= 2h
GO_TEST_READONLY_DIRECTORY ?= post_deploy_functional_readonly
TEST_RUN_ONLY_READONLY = #intentionally empty
TEST_RUN_EXCLUDE_READONLY = -v
GOLANGCI_LINT_CONFIG ?= .golangci.yaml
DISABLE_MAKE_CHECK_LINT ?= false
CURRENT_DIR = $(notdir $(shell pwd))

# If ARM_SUBSCRIPTION_ID is not already set by the environment, we'll try to use the `az` command 
# to retrieve it. If `az` isn't found, we'll silently continue here and catch that case elsewhere.
export ARM_SUBSCRIPTION_ID ?= $(shell command -v az >/dev/null 2>&1 && az account show | jq -r .id)

# Functions

# Checks for Go files in the GO_TEST_DIRECTORIES. If they exist, runs the default configuration for golangci-lint
# https://golangci-lint.run/usage/quick-start/
define go_lint
	$(FIND) $(1)/ -name '*.go' | $(GREP) -q '\.go' || exit 0; $(GOLANGCI_LINT) run -c $(GOLANGCI_LINT_CONFIG) -timeout=$(GO_LINT_TIMEOUT) -v ./$(1)/...;

endef

# Check for Go files. If they exist, run tests. Either runs only readonly tests(default) or tests except readonly ones
define go_test
	$(FIND) $(1)/ -name '*.go' |$(GREP) $(2) $(GO_TEST_READONLY_DIRECTORY) | $(GREP) -q '\.go' || exit 0; $(GO) test -v -count=1 -timeout=$(GO_TEST_TIMEOUT) $$($(GO) list ./$(1)/...|$(GREP) $(2)  $(GO_TEST_READONLY_DIRECTORY)) ;

endef

# Tasks
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
go/lint :
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_lint,$(test_dir)))

.PHONY: go/test
go/test : go/test/environment
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_test,$(test_dir),$(TEST_RUN_EXCLUDE_READONLY)))

go/readonly_test:
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
