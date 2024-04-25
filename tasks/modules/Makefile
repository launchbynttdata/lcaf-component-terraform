SHELL := /bin/bash

# Binaries

TERRAFORM ?= terraform
RM ?= rm -rf
CONFTEST ?= conftest
REGULA ?= regula
TFLINT ?= tflint
FIND ?= find

# Variables

ALL_TF_MODULES = $(shell $(call list_terraform_modules))
ALL_EXAMPLES = $(shell $(call list_examples))
POLICY_DIRECTORY ?= components/policy
TFLINT_CONFIG ?= .tflint.hcl
VAR_FILE ?= test.tfvars
# Temporary value until we can relocate policies and validate; will be defaulted
# to 'high' in the future with the option to change this via .lcafenv
REGULA_SEVERITY ?= off 
CURRENT_DIR = $(notdir $(shell pwd))
AWS_PROFILE ?= default
AWS_REGION ?= us-east-2
# Functions

define check_terraform_fmt
	echo && echo "Formatting Terraform files ...";
	$(TERRAFORM) fmt -recursive;

endef

define clean_terraform_module
	$(RM) $(1)/.terraform* $(1)/terraform.*;

endef

define conftest_terraform_module
	echo && echo "Conftest $(1) ...";
	echo $(CONFTEST) test $(1)/terraform.tfplan.json --all-namespaces -p $(POLICY_DIRECTORY) -p $(MODULE_DIR)/custom_policy/policy;
	$(CONFTEST) test $(1)/terraform.tfplan.json --all-namespaces -p $(POLICY_DIRECTORY) -p $(MODULE_DIR)/custom_policy/policy;

endef

define regula_terraform_module
	echo && echo "Regula $(1) ...";
	echo $(REGULA) run $(1)/terraform.tfplan.json --input-type tf-plan --severity $(REGULA_SEVERITY) --include $(POLICY_DIRECTORY) --include $(MODULE_DIR)/custom_policy/policy
	$(REGULA) run $(1)/terraform.tfplan.json --input-type tf-plan --severity $(REGULA_SEVERITY) --include $(POLICY_DIRECTORY) --include $(MODULE_DIR)/custom_policy/policy

endef

define init_terraform_module
	echo && echo "Initializing $(1) ...";
	$(TERRAFORM) -chdir=$(1) init -backend=false -input=false;

endef

define list_terraform_modules
	$(FIND) . -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -not -path '*examples*' -exec dirname {} \;;

endef

define list_examples
	$(FIND) ./examples -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -exec dirname {} \; 2>/dev/null
endef

define aws_provider
provider \"aws\" {\n  region  = \"$(AWS_REGION)\"\n  profile = \"$(AWS_PROFILE)\"\n}\n\nprovider \"aws\" {\n  alias   = \"global\"\n  region  = \"us-east-1\"\n  profile = \"$(AWS_PROFILE)\"\n}\n
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
	$(if $(findstring hashicorp/aws,$(2)),grep -q "aws" $(1) || bash -c 'echo -e "$(call aws_provider)"' >> $(1),)
	$(if $(findstring azure/azapi,$(2)),grep -q "azapi" $(1) || bash -c 'echo -e "$(call azapi_provider)"' >> $(1),)
	$(if $(findstring microsoft/azuredevops,$(2)),grep -q "azuredevops" $(1) || bash -c 'echo -e "$(call azuredevops_provider)"' >> $(1),)
	$(if $(findstring hashicorp/azurerm,$(2)),grep -q "azurerm" $(1) || bash -c 'echo -e "$(call azurerm_provider)"' >> $(1),)
endef

define create_example_providers
	$(eval PROVIDER_FILE_PATH:=$(call provider_file_path,$(1)))
	$(foreach PROVIDER,$(shell terraform providers | sed -re 's/.+\[(.+\/.+\/.+)\].+/\1/g' | grep registry | sort | uniq),$(call add_provider_details,$(PROVIDER_FILE_PATH),$(PROVIDER)))
endef

define plan_terraform_module
	echo && echo "Planning $(1) ...";
	$(TERRAFORM) -chdir=$(1) plan -input=false -out=terraform.tfplan -var-file $(VAR_FILE);
	echo && echo "Creating JSON plan output for $(1) ...";
	cd $(1) && $(TERRAFORM) show -json ./terraform.tfplan > ./terraform.tfplan.json;

endef

define tflint_terraform_module
	echo && echo "Linting $(1) ...";
	(cd $(1) && TF_LOG=info $(TFLINT) -c $(TFLINT_CONFIG)) || exit 1;

endef

define validate_terraform_module
	echo && echo "Validating $(1) ...";
	$(TERRAFORM) -chdir=$(1) validate || exit 1;

endef

# Tasks

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
tfmodule/lint : tfmodule/init
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
tfmodule/test/regula : 
	@$(foreach module,$(ALL_EXAMPLES),$(call regula_terraform_module,$(module)))

.PHONY: tfmodule/test/conftest
tfmodule/test/conftest : 
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
	-rm -rf $(MODULE_DIR)/custom_policy
ifeq ($(origin CUSTOM_POLICY_REPO),undefined)
	mkdir -p $(MODULE_DIR)/custom_policy/policy
else
	git clone $(CUSTOM_POLICY_REPO) $(MODULE_DIR)/custom_policy
endif

.PHONY: tfmodule/create_example_providers
tfmodule/create_example_providers:
	@$(call create_example_providers,.)
	@$(foreach example,$(ALL_EXAMPLES),$(call create_example_providers,$(example)))

.PHONY: lint
lint::
	$(MAKE) tfmodule/lint

.PHONY: test
test::
	$(MAKE) tfmodule/clone_custom_rules
	$(MAKE) tfmodule/create_example_providers
	$(MAKE) tfmodule/plan
	$(MAKE) tfmodule/test/conftest
	$(MAKE) tfmodule/test/regula
