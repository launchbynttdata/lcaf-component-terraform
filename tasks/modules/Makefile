SHELL := /bin/bash

################################################################################
# Binaries
# All binary paths can be overridden via environment variables or CLI arguments
# Example: make tfmodule/lint TERRAFORM=/custom/path/terraform
################################################################################

TERRAFORM ?= terraform
RM ?= rm -rf
CONFTEST ?= conftest
REGULA ?= regula
TFLINT ?= tflint
FIND ?= find
GREP ?= grep
GIT ?= git
AWK ?= awk
CUT ?= cut
UNIQ ?= uniq

# Binary Detection
TERRAFORM_INSTALLED = $(shell which $(TERRAFORM) > /dev/null 2>&1; echo $$?)
CONFTEST_INSTALLED = $(shell which $(CONFTEST) > /dev/null 2>&1; echo $$?)
REGULA_INSTALLED = $(shell which $(REGULA) > /dev/null 2>&1; echo $$?)
TFLINT_INSTALLED = $(shell which $(TFLINT) > /dev/null 2>&1; echo $$?)
FIND_INSTALLED = $(shell which $(FIND) > /dev/null 2>&1; echo $$?)
GREP_INSTALLED = $(shell which $(GREP) > /dev/null 2>&1; echo $$?)
GIT_INSTALLED = $(shell which $(GIT) > /dev/null 2>&1; echo $$?)

################################################################################
# Configuration Variables
# Precedence chain: ENV VAR > CLI option > file config > default value
#
# Examples:
#   Override via environment: export TFLINT_CONFIG=custom.hcl
#   Override via CLI: make tfmodule/lint TFLINT_CONFIG=custom.hcl
#   Override via this file: modify the defaults below
################################################################################

# Terraform Configuration
TERRAFORM_BACKEND_CONFIG ?= false
TERRAFORM_INPUT ?= false
TERRAFORM_PARALLELISM ?= 10
VAR_FILE ?= test.tfvars

# Linting Configuration
TFLINT_CONFIG ?= .tflint.hcl
TFLINT_LOG_LEVEL ?= info
TFLINT_EXTRA_FLAGS ?=

# Policy Configuration
POLICY_DIRECTORY ?= components/policy
REGULA_SEVERITY ?= off
REGULA_INPUT_TYPE ?= tf-plan
REGULA_EXTRA_FLAGS ?=
CONFTEST_NAMESPACE ?= --all-namespaces
CONFTEST_EXTRA_FLAGS ?=
CUSTOM_POLICY_DIR ?= $(MODULE_DIR)/custom_policy

# AWS Configuration (for provider generation)
AWS_PROFILE ?= default
AWS_REGION ?= us-east-2
AWS_GLOBAL_REGION ?= us-east-1

# Internal Variables
ALL_TF_MODULES = $(shell $(call list_terraform_modules))
ALL_EXAMPLES = $(shell $(call list_examples))
CURRENT_DIR = $(notdir $(shell pwd))
################################################################################
# Functions
# All functions use only configurable variables - no hard-coded values
################################################################################

define check_terraform_fmt
	@echo && echo "Formatting Terraform files ...";
	$(TERRAFORM) fmt -recursive;
endef

define clean_terraform_module
	@echo "Cleaning $(1)...";
	$(RM) $(1)/.terraform* $(1)/terraform.*;
endef

define conftest_terraform_module
	@echo && echo "Running Conftest on $(1) ...";
	@echo $(CONFTEST) test $(1)/terraform.tfplan.json $(CONFTEST_NAMESPACE) -p $(POLICY_DIRECTORY) -p $(CUSTOM_POLICY_DIR)/policy $(CONFTEST_EXTRA_FLAGS);
	$(CONFTEST) test $(1)/terraform.tfplan.json $(CONFTEST_NAMESPACE) -p $(POLICY_DIRECTORY) -p $(CUSTOM_POLICY_DIR)/policy $(CONFTEST_EXTRA_FLAGS);
endef

define regula_terraform_module
	@echo && echo "Running Regula on $(1) ...";
	@echo $(REGULA) run $(1)/terraform.tfplan.json --input-type $(REGULA_INPUT_TYPE) --severity $(REGULA_SEVERITY) --include $(POLICY_DIRECTORY) --include $(CUSTOM_POLICY_DIR)/policy $(REGULA_EXTRA_FLAGS)
	$(REGULA) run $(1)/terraform.tfplan.json --input-type $(REGULA_INPUT_TYPE) --severity $(REGULA_SEVERITY) --include $(POLICY_DIRECTORY) --include $(CUSTOM_POLICY_DIR)/policy $(REGULA_EXTRA_FLAGS)
endef

define init_terraform_module
	@echo && echo "Initializing $(1) ...";
	$(TERRAFORM) -chdir=$(1) init -backend=$(TERRAFORM_BACKEND_CONFIG) -input=$(TERRAFORM_INPUT);
endef

define list_terraform_modules
	$(FIND) . -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -not -path '*examples*' -exec dirname {} \;;

endef

define list_examples
	$(FIND) ./examples -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -exec dirname {} \; 2>/dev/null
endef

define aws_provider
provider \"aws\" {\n  region  = \"$(AWS_REGION)\"\n  profile = \"$(AWS_PROFILE)\"\n}\n\nprovider \"aws\" {\n  alias   = \"global\"\n  region  = \"$(AWS_GLOBAL_REGION)\"\n  profile = \"$(AWS_PROFILE)\"\n}\n
endef

define azurerm_provider
provider \"azurerm\" {\n  skip_provider_registration = true\n  features {\n    resource_group {\n      prevent_deletion_if_contains_resources = false\n    }\n  }\n}\n
endef

define azapi_provider
provider \"azapi\" {\n  use_cli = true\n  use_msi = false\n}\n
endef

define azuredevops_provider
provider \"azuredevops\" {}\n
endef

define provider_file_path
$(1)/provider.tf
endef

define add_provider_details
	$(if $(findstring hashicorp/aws,$(2)),grep -qs "aws" $(1) || bash -c 'echo -e "$(call aws_provider)"' >> $(1),)
	$(if $(findstring azure/azapi,$(2)),grep -qs "azapi" $(1) || bash -c 'echo -e "$(call azapi_provider)"' >> $(1),)
	$(if $(findstring microsoft/azuredevops,$(2)),grep -qs "azuredevops" $(1) || bash -c 'echo -e "$(call azuredevops_provider)"' >> $(1),)
	$(if $(findstring hashicorp/azurerm,$(2)),grep -qs "azurerm" $(1) || bash -c 'echo -e "$(call azurerm_provider)"' >> $(1),)
endef

define create_example_providers
	$(eval PROVIDER_FILE_PATH:=$(call provider_file_path,$(1)))
	$(foreach PROVIDER,$(shell terraform providers | sed -re 's/.+\[(.+\/.+\/.+)\].+/\1/g' | grep registry | sort | uniq),$(call add_provider_details,$(PROVIDER_FILE_PATH),$(PROVIDER)))
endef

define plan_terraform_module
	@echo && echo "Planning $(1) ...";
	$(TERRAFORM) -chdir=$(1) plan -input=$(TERRAFORM_INPUT) -parallelism=$(TERRAFORM_PARALLELISM) -out=terraform.tfplan -var-file $(VAR_FILE);
	@echo && echo "Creating JSON plan output for $(1) ...";
	cd $(1) && $(TERRAFORM) show -json ./terraform.tfplan > ./terraform.tfplan.json;
endef

define tflint_terraform_module
	@echo && echo "Linting $(1) ...";
	(cd $(1) && TF_LOG=$(TFLINT_LOG_LEVEL) $(TFLINT) -c $(TFLINT_CONFIG) $(TFLINT_EXTRA_FLAGS) || TF_LOG=$(TFLINT_LOG_LEVEL) $(TFLINT) -c ../../$(TFLINT_CONFIG) $(TFLINT_EXTRA_FLAGS)) || exit 1;
endef

define validate_terraform_module
	echo && echo "Validating $(1) ...";
	$(TERRAFORM) -chdir=$(1) validate || exit 1;

endef

################################################################################
# Validation and Help
################################################################################

.PHONY: tfmodule/help
tfmodule/help:
	@echo "Terraform Module Testing Makefile"
	@echo "================================="
	@echo ""
	@echo "Available targets:"
	@echo "  tfmodule/all              - Run all linting (default target)"
	@echo "  tfmodule/clean            - Clean Terraform state files"
	@echo "  tfmodule/fmt              - Format Terraform files"
	@echo "  tfmodule/init             - Initialize all modules and examples"
	@echo "  tfmodule/lint             - Run linting on all modules"
	@echo "  tfmodule/list             - List all modules and examples"
	@echo "  tfmodule/plan             - Create Terraform plans for examples"
	@echo "  tfmodule/pre_deploy_test  - Run pre-deployment tests"
	@echo "  tfmodule/test/conftest    - Run Conftest policy tests"
	@echo "  tfmodule/test/regula      - Run Regula policy tests"
	@echo "  tfmodule/validate         - Validate configuration"
	@echo "  tfmodule/help             - Show this help message"
	@echo ""
	@echo "Configuration variables (precedence: ENV > CLI > file > default):"
	@echo "  TFLINT_CONFIG            - TFLint config file (default: $(TFLINT_CONFIG))"
	@echo "  VAR_FILE                 - Terraform variables file (default: $(VAR_FILE))"
	@echo "  POLICY_DIRECTORY         - Policy directory (default: $(POLICY_DIRECTORY))"
	@echo "  REGULA_SEVERITY          - Regula severity level (default: $(REGULA_SEVERITY))"
	@echo "  AWS_PROFILE              - AWS profile (default: $(AWS_PROFILE))"
	@echo "  AWS_REGION               - AWS region (default: $(AWS_REGION))"
	@echo "  TFLINT_EXTRA_FLAGS       - Additional TFLint flags"
	@echo "  CONFTEST_EXTRA_FLAGS     - Additional Conftest flags"
	@echo "  REGULA_EXTRA_FLAGS       - Additional Regula flags"
	@echo ""
	@echo "Examples:"
	@echo "  make tfmodule/lint TFLINT_CONFIG=custom.hcl"
	@echo "  make tfmodule/plan VAR_FILE=prod.tfvars AWS_PROFILE=production"
	@echo "  export REGULA_SEVERITY=high && make tfmodule/test/regula"

.PHONY: tfmodule/validate
tfmodule/validate:
	@echo "Validating Terraform module configuration..."
	@echo "Checking required binaries..."
ifneq ($(TERRAFORM_INSTALLED), 0)
	$(error Terraform binary '$(TERRAFORM)' not found in PATH. Please install Terraform and ensure it is in your PATH.)
endif
ifneq ($(TFLINT_INSTALLED), 0)
	$(error TFLint binary '$(TFLINT)' not found in PATH. Please install TFLint (https://github.com/terraform-linters/tflint) and ensure it is in your PATH.)
endif
ifneq ($(FIND_INSTALLED), 0)
	$(error Find utility '$(FIND)' not found in PATH. Please ensure find is installed and in your PATH.)
endif
ifneq ($(GREP_INSTALLED), 0)
	$(error Grep utility '$(GREP)' not found in PATH. Please ensure grep is installed and in your PATH.)
endif
ifneq ($(GIT_INSTALLED), 0)
	@echo "Warning: Git binary '$(GIT)' not found in PATH. Some features may not work properly."
endif
ifneq ($(CONFTEST_INSTALLED), 0)
	@echo "Warning: Conftest binary '$(CONFTEST)' not found in PATH. Policy testing targets will fail."
endif
ifneq ($(REGULA_INSTALLED), 0)
	@echo "Warning: Regula binary '$(REGULA)' not found in PATH. Policy testing targets will fail."
endif
	@echo "✓ Required binaries validated"
	@echo "Checking configuration..."
	@test -n "$(VAR_FILE)" || { echo "Error: VAR_FILE is empty"; exit 1; }
	@if [ -n "$(TFLINT_CONFIG)" ] && [ ! -f "$(TFLINT_CONFIG)" ]; then \
		echo "Warning: TFLint config file '$(TFLINT_CONFIG)' not found, TFLint will use defaults"; \
	fi
	@echo "✓ Terraform: $$($(TERRAFORM) version | head -n1)"
	@echo "✓ TFLint: $$($(TFLINT) --version 2>/dev/null || echo 'version unknown')"
	@echo "✓ Variables file: $(VAR_FILE)"
	@echo "✓ Policy directory: $(POLICY_DIRECTORY)"
	@echo "✓ Configuration validated successfully"

################################################################################
# Tasks
################################################################################

.PHONY: tfmodule/all
tfmodule/all: lint

.PHONY: tfmodule/clean
tfmodule/clean :
	@$(foreach module,$(ALL_TF_MODULES),$(call clean_terraform_module,$(module)))

.PHONY: tfmodule/fmt
tfmodule/fmt :
	$(TERRAFORM) fmt -recursive;

.PHONY: tfmodule/init
tfmodule/init :
	@$(foreach module,$(ALL_TF_MODULES),$(call init_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call init_terraform_module,$(module)))

.PHONY: tfmodule/lint
tfmodule/lint : tfmodule/validate tfmodule/init
	@$(call check_terraform_fmt)
	@$(foreach module,$(ALL_TF_MODULES),$(call tflint_terraform_module,$(module)))
	@$(foreach module,$(ALL_TF_MODULES),$(call validate_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call tflint_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call validate_terraform_module,$(module)))

.PHONY: tfmodule/list
tfmodule/list :
	@echo -n "Modules: "
	@echo $(ALL_TF_MODULES) | tr ' ' '\n' | sort
	@echo -n "Examples: "
	@echo $(ALL_EXAMPLES) | tr ' ' '\n' | sort

.PHONY: tfmodule/plan
tfmodule/plan : tfmodule/init
	@$(foreach module,$(ALL_EXAMPLES),$(call plan_terraform_module,$(module)))

.PHONY: tfmodule/test/regula
tfmodule/test/regula : tfmodule/validate
ifneq ($(REGULA_INSTALLED), 0)
	$(error Regula binary '$(REGULA)' not found in PATH. Please install Regula (https://github.com/fugue/regula) to run policy tests.)
endif
	@$(foreach module,$(ALL_EXAMPLES),$(call regula_terraform_module,$(module)))

.PHONY: tfmodule/test/conftest
tfmodule/test/conftest : tfmodule/validate
ifneq ($(CONFTEST_INSTALLED), 0)
	$(error Conftest binary '$(CONFTEST)' not found in PATH. Please install Conftest (https://www.conftest.dev/) to run policy tests.)
endif
	@$(foreach module,$(ALL_EXAMPLES),$(call conftest_terraform_module,$(module)))

.PHONY: tfmodule/pre_deploy_test
tfmodule/pre_deploy_test : tfmodule/clone_custom_rules
	@$(foreach example,$(ALL_EXAMPLES),$(call init_terraform_module,$(example)))
	@$(foreach example,$(ALL_EXAMPLES),$(call plan_terraform_module,$(example)))
	@$(foreach example,$(ALL_EXAMPLES),$(call conftest_terraform_module,$(example)))
	@$(foreach example,$(ALL_EXAMPLES),$(call regula_terraform_module,$(example)))

.PHONY: tfmodule/post_deploy_test
tfmodule/post_deploy_test :

.PHONY: tfmodule/clone_custom_rules
tfmodule/clone_custom_rules :
	-$(RM) $(CUSTOM_POLICY_DIR)
ifeq ($(origin CUSTOM_POLICY_REPO),undefined)
	@echo "No CUSTOM_POLICY_REPO defined, creating empty policy directory"
	mkdir -p $(CUSTOM_POLICY_DIR)/policy
else
ifneq ($(GIT_INSTALLED), 0)
	$(error Git binary '$(GIT)' not found in PATH. Git is required to clone CUSTOM_POLICY_REPO.)
endif
	@echo "Cloning custom policy from $(CUSTOM_POLICY_REPO)"
	$(GIT) clone $(CUSTOM_POLICY_REPO) $(CUSTOM_POLICY_DIR)
endif

.PHONY: tfmodule/create_example_providers
tfmodule/create_example_providers : tfmodule/init
	@$(if $(findstring aws.global,$(shell grep -se "\\s*provider\\s*=" *.tf || true)),$(call create_example_providers,.),)
	@$(foreach example,$(ALL_EXAMPLES),$(call create_example_providers,$(example)))

.PHONY: lint
lint::
	$(MAKE) tfmodule/create_example_providers
	$(MAKE) tfmodule/lint

.PHONY: test
test::
	$(MAKE) tfmodule/clone_custom_rules
	$(MAKE) tfmodule/create_example_providers
	$(MAKE) tfmodule/plan
	$(MAKE) tfmodule/test/conftest
	$(MAKE) tfmodule/test/regula
