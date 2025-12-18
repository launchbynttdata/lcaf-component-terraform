# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

################################################################################
# Configuration File Include
# Include custom values from .lcafenv. Repository root is assumed to be the working directory.
# Precedence chain: ENV VAR > .lcafenv file > CLI option > defaults below
################################################################################
LCAF_ENV_FILE ?= .lcafenv
-include $(LCAF_ENV_FILE)

################################################################################
# Repository Configuration
# All variables can be overridden via:
#   1. Environment variables (highest precedence)
#   2. .lcafenv file
#   3. CLI arguments: make configure REPO_BRANCH=refs/tags/2.0.0
#   4. Defaults below (lowest precedence)
################################################################################

# Source repository for repo manifests
REPO_MANIFESTS_URL ?= https://github.com/launchbynttdata/launch-common-automation-framework.git

# Branch of source repository for repo manifests. Other tags not currently supported.
# TODO: replace with git tag when supported
REPO_BRANCH ?= refs/tags/1.0.0

# Path to seed manifest in repository referenced in REPO_MANIFESTS_URL
REPO_MANIFEST ?= manifests/terraform_modules/seed/manifest.xml

# Settings to pull in Nexient version of (google) repo utility that supports environment substitution
REPO_URL ?= https://github.com/launchbynttdata/git-repo.git

# Branch of the repository referenced by REPO_URL to use
# TODO: replace with git tag when supported
REPO_REV ?= main
export REPO_REV REPO_URL

# Example variable to substituted after init, but before sync in repo manifests
GITBASE ?= https://github.com/launchbynttdata/

# TODO: replace with git tag when supported
GITREV ?= main
export GITBASE GITREV

################################################################################
# Pipeline and Authentication Configuration
################################################################################

# Set to true in a pipeline context
IS_PIPELINE ?= false

# Set to true when authentication is required
IS_AUTHENTICATED ?= false

# Git configuration for pipeline jobs
JOB_NAME ?= job
JOB_EMAIL ?= job@job.job

################################################################################
# Internal Variables and Detection
# These variables are for internal use and dependency detection
################################################################################

COMPONENTS_DIR ?= components
-include $(COMPONENTS_DIR)/Makefile

MODULE_DIR ?= ${COMPONENTS_DIR}/module

# Binaries
GIT ?= git
PRE_COMMIT ?= pre-commit
PIP3 ?= pip3
REPO ?= repo

# Dependency detection
GIT_INSTALLED = $(shell which $(GIT) > /dev/null 2>&1; echo $$?)
PYTHON3_INSTALLED = $(shell which python3 > /dev/null 2>&1; echo $$?)
PRE_COMMIT_INSTALLED = $(shell which $(PRE_COMMIT) > /dev/null 2>&1; echo $$?)
MISE_INSTALLED = $(shell which mise > /dev/null 2>&1; echo $$?)
ASDF_INSTALLED = $(shell which asdf > /dev/null 2>&1; echo $$?)
REPO_INSTALLED = $(shell which $(REPO) > /dev/null 2>&1; echo $$?)
GIT_USER_SET ?= $(shell $(GIT) config --get user.name > /dev/null 2>&1; echo $$?)
GIT_EMAIL_SET ?= $(shell $(GIT) config --get user.email > /dev/null 2>&1; echo $$?)

.PHONY: configure-git-hooks
configure-git-hooks: configure-dependencies
ifeq ($(PYTHON3_INSTALLED), 0)
ifeq ($(PRE_COMMIT_INSTALLED), 1)
	@echo "pre-commit not found, installing via $(PIP3)..."
	$(PIP3) install pre-commit
	@echo "pre-commit installed successfully"
endif
	@echo "Installing pre-commit hooks..."
	$(PRE_COMMIT) install
	@echo "✓ Pre-commit hooks installed"
else
	$(error Missing python3, which is required for pre-commit. Install python3 and rerun.)
endif

ifeq ($(IS_PIPELINE),true)
.PHONY: git-config
git-config:
ifneq ($(GIT_INSTALLED), 0)
	$(error Git binary '$(GIT)' not found in PATH. Please install git and rerun.)
else ifeq ($(JOB_NAME),CHANGEME)
	@echo "Warning: JOB_NAME is set to 'CHANGEME'. Skipping git user.name configuration."
	@echo "Please set JOB_NAME to a valid value via environment variable or .lcafenv file."
else ifeq ($(JOB_EMAIL),CHANGEME)
	@echo "Warning: JOB_EMAIL is set to 'CHANGEME'. Skipping git user.email configuration."
	@echo "Please set JOB_EMAIL to a valid value via environment variable or .lcafenv file."
else
	@set -ex; \
	$(GIT) config --global user.name "$(JOB_NAME)"; \
	$(GIT) config --global user.email "$(JOB_EMAIL)"; \
	$(GIT) config --global color.ui false
	@echo "✓ Git configured for pipeline with user: $(JOB_NAME) <$(JOB_EMAIL)>"
endif

configure: git-config
endif

ifeq ($(IS_AUTHENTICATED),true)
GIT_AUTH_HEADER_PREFIX ?= Bearer
GIT_REPO_URL ?= https://gerrit.googlesource.com/git-repo/
HTTP_VERSION ?= HTTP/1.1

.PHONY: git-auth
git-auth:
	$(call config,$(GIT_AUTH_HEADER_PREFIX) $(GIT_TOKEN))

define config
	@set -ex; \
	git config --global http.extraheader "AUTHORIZATION: $(1)"; \
	git config --global http.$(GIT_REPO_URL).extraheader ''; \
	git config --global http.version $(HTTP_VERSION);
endef

configure: git-auth
endif

.PHONY: configure-dependencies
configure-dependencies:
ifeq ($(MISE_INSTALLED), 0)
	@echo "Installing dependencies using mise"
	@awk -F'[ #]' '$$NF ~ /https/ {system("mise plugin install " $$1 " " $$NF " --yes")} $$1 ~ /./ {system("mise install " $$1 " " $$2 " --yes")}' ./.tool-versions
else ifeq ($(ASDF_INSTALLED), 0)
	@echo "Installing dependencies using asdf-vm"
	@awk -F'[ #]' '$$NF ~ /https/ {system("asdf plugin add " $$1 " " $$NF)} $$1 ~ /./ {system("asdf plugin add " $$1 "; asdf install " $$1 " " $$2)}' ./.tool-versions
else
	$(error Missing supported dependency manager. Install asdf-vm (https://asdf-vm.com/) or mise (https://mise.jdx.dev/) and rerun)
endif

################################################################################
# Help and Validation Targets
################################################################################

.PHONY: help
help:
	@echo "LCAF Component Terraform Makefile"
	@echo "================================="
	@echo ""
	@echo "Available targets:"
	@echo "  configure                - Configure repository with dependencies and repo sync"
	@echo "  configure-dependencies   - Install tool dependencies via mise or asdf"
	@echo "  configure-git-hooks      - Install pre-commit hooks"
	@echo "  clean                    - Remove directories pulled in by repo"
	@echo "  init-clean               - Reset git repository"
	@echo "  validate                 - Validate configuration and dependencies"
	@echo "  help                     - Show this help message"
	@echo ""
	@echo "Configuration variables (precedence: ENV > .lcafenv > CLI > default):"
	@echo "  REPO_MANIFESTS_URL       - Source repository URL (default: $(REPO_MANIFESTS_URL))"
	@echo "  REPO_BRANCH              - Branch/tag to use (default: $(REPO_BRANCH))"
	@echo "  REPO_MANIFEST            - Manifest path (default: $(REPO_MANIFEST))"
	@echo "  GITBASE                  - Git base URL (default: $(GITBASE))"
	@echo "  GITREV                   - Git revision (default: $(GITREV))"
	@echo "  IS_PIPELINE              - Pipeline mode (default: $(IS_PIPELINE))"
	@echo "  IS_AUTHENTICATED         - Auth required (default: $(IS_AUTHENTICATED))"
	@echo ""
	@echo "Examples:"
	@echo "  make configure REPO_BRANCH=refs/tags/2.0.0"
	@echo "  export GITBASE=https://github.com/myorg/ && make configure"
	@echo "  make configure IS_PIPELINE=true JOB_NAME=\"CI Job\""

.PHONY: validate
validate:
	@echo "Validating configuration..."
	@test -n "$(REPO_MANIFESTS_URL)" || { echo "Error: REPO_MANIFESTS_URL is empty"; exit 1; }
	@test -n "$(REPO_BRANCH)" || { echo "Error: REPO_BRANCH is empty"; exit 1; }
	@test -n "$(REPO_MANIFEST)" || { echo "Error: REPO_MANIFEST is empty"; exit 1; }
	@test -n "$(GITBASE)" || { echo "Error: GITBASE is empty"; exit 1; }
	@test -n "$(GITREV)" || { echo "Error: GITREV is empty"; exit 1; }
ifeq ($(PYTHON3_INSTALLED), 1)
	@echo "Warning: python3 not found in PATH"
endif
ifeq ($(and $(MISE_INSTALLED), $(ASDF_INSTALLED)), 1)
	@echo "Warning: Neither mise nor asdf found in PATH"
endif
ifeq ($(REPO_INSTALLED), 1)
	@echo "Warning: repo not found in PATH"
endif
	@echo "✓ REPO_MANIFESTS_URL: $(REPO_MANIFESTS_URL)"
	@echo "✓ REPO_BRANCH: $(REPO_BRANCH)"
	@echo "✓ REPO_MANIFEST: $(REPO_MANIFEST)"
	@echo "✓ GITBASE: $(GITBASE)"
	@echo "✓ GITREV: $(GITREV)"
	@echo "✓ Configuration validated successfully"

.PHONY: configure
configure: configure-git-hooks
ifneq ($(and $(GIT_USER_SET), $(GIT_EMAIL_SET)), 0)
	$(error Git identities are not set! Set your user.name and user.email using 'git config' and rerun)
endif
ifeq ($(REPO_INSTALLED), 0)
	echo n | repo --color=never init --no-repo-verify \
		-u "$(REPO_MANIFESTS_URL)" \
		-b "$(REPO_BRANCH)" \
		-m "$(REPO_MANIFEST)"
	repo envsubst
	repo sync
else
	$(error Missing Repo, which is required for platform sync. Install Repo (https://gerrit.googlesource.com/git-repo) and rerun.)
endif

# The first line finds and removes all the directories pulled in by repo
# The second line finds and removes all the broken symlinks from removing things
# https://stackoverflow.com/questions/42828021/removing-files-with-rm-using-find-and-xargs
.PHONY: clean
clean:
ifeq ($(REPO_INSTALLED), 0)
	@echo "Cleaning directories pulled in by $(REPO)..."
	-$(REPO) list | awk '{ print $$1; }' | cut -d '/' -f1 | uniq | xargs rm -rf
	@echo "Cleaning broken symlinks..."
	find . -type l ! -exec test -e {} \; -print | xargs rm -rf
	@echo "✓ Clean completed"
else
	@echo "Warning: $(REPO) binary not found in PATH. Skipping repo directory cleanup."
	@echo "Cleaning broken symlinks only..."
	find . -type l ! -exec test -e {} \; -print | xargs rm -rf
endif

.PHONY: init-clean
init-clean:
	rm -rf .git
	git init --initial-branch=main
ifneq (,$(wildcard ./TEMPLATED_README.md))
	mv TEMPLATED_README.md README.MD
endif
