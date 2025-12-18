# Launch Common Automation Framework - Terraform Module Component

This repository provides the core automation framework component for Terraform module development within the Launch Common Automation Framework (LCAF). It includes standardized Makefiles, configuration templates, and tooling to streamline Terraform module development, testing, and validation workflows.

## Overview

This component serves as the foundation for Terraform module repositories, providing:

- **Automated Dependency Management**: Syncs required components and policies using Google's repo tool
- **Standardized Testing**: Go-based testing harness with Terratest integration
- **Policy Validation**: Built-in support for Conftest and Regula policy testing
- **Linting & Formatting**: Integrated TFLint and golangci-lint configuration
- **Configuration Flexibility**: Environment-based configuration with clear precedence chains
- **Cross-Platform Support**: Works on Linux, macOS, and Windows (with WSL/Git Bash)

## Repository Structure

```text
lcaf-component-terraform/
├── Makefile                       # Root automation orchestrator
│                                  # - Repository initialization via `repo` tool
│                                  # - Dependency management (mise/asdf)
│                                  # - Pre-commit hook setup
│                                  # - Git configuration for CI/CD
│
├── linkfiles/                     # Configuration templates to be linked/copied into target repos
│   ├── .golangci.yaml            # golangci-lint configuration for Go test code
│   ├── .pre-commit-config.yaml   # Pre-commit hooks configuration
│   ├── .tflint.hcl               # TFLint configuration for Terraform validation
│   └── Makefile                   # Placeholder/reference Makefile
│
├── tasks/                         # Task-specific Makefiles (included by target repos)
│   ├── golang/                    # Go testing automation
│   │   └── Makefile              # - Run Terratest suites
│   │                             # - golangci-lint validation
│   │                             # - Test filtering (readonly vs full tests)
│   │                             # - Cloud provider environment setup
│   │
│   └── modules/                   # Terraform module automation
│       └── Makefile              # - terraform init/validate/plan
│                                 # - TFLint scanning
│                                 # - Policy validation (Conftest/Regula)
│                                 # - Provider generation for examples
│                                 # - Format checking
│
├── .pre-commit-config.yaml        # Pre-commit hooks for this repository
├── .gitignore                     # Git ignore patterns
├── CODEOWNERS                     # GitHub code ownership definitions
├── LICENSE                        # Apache 2.0 License
├── NOTICE                         # Legal notices
└── README.md                      # This file
```

## Key Features

### 1. Configuration Precedence Chain

All configuration follows a consistent precedence hierarchy:

```text
Environment Variables > .lcafenv file > CLI Arguments > Default Values
```

This allows flexible configuration management across local development, CI/CD pipelines, and team standards.

### 2. Binary Validation

Before executing any tasks, the framework validates that required tools are installed:

- **Required**: terraform, tflint, go, golangci-lint
- **Optional**: conftest, regula (for policy testing)
- **Auto-install**: pre-commit (via pip3 if missing)

### 3. Smart Timeout Resolution (Go Linting)

The Go linting Makefile implements intelligent timeout handling:

- Compares timeout values between configuration file and environment variables
- Uses the **larger** timeout value between config file and CLI/environment
- Only passes `--timeout` flag when overriding config file
- Preserves all other configuration file settings

### 4. Multi-Cloud Support

Built-in environment setup for:

- **AWS**: Profile and region configuration
- **Azure**: Subscription ID auto-detection via `az` CLI
- **GCP**: Configurable project settings

## Usage

### Quick Start

1. **Initial Setup**:

   ```bash
   make configure
   ```

   This will:
   - Install tool dependencies (via mise or asdf)
   - Set up pre-commit hooks
   - Sync required components via repo tool

2. **View Available Commands**:

   ```bash
   make help              # Root-level help
   make tfmodule/help     # Terraform module tasks
   make go/help           # Go testing tasks
   ```

3. **Run Terraform Validation**:

   ```bash
   make tfmodule/lint     # Format, validate, and lint Terraform
   make tfmodule/plan     # Generate plans for examples
   ```

4. **Run Go Tests**:

   ```bash
   make go/test           # Run all tests (excludes readonly)
   make go/readonly_test  # Run only readonly tests
   make go/lint           # Lint Go test code
   ```

### Configuration

Create a `.lcafenv` file in your repository root to customize settings:

```makefile
# Repository configuration
REPO_BRANCH = refs/tags/2.0.0
GITBASE = https://github.com/myorg/
# Terraform settings
TFLINT_CONFIG = custom-tflint.hcl
REGULA_SEVERITY = high
AWS_PROFILE = production
AWS_REGION = us-west-2
# Go testing settings
GO_LINT_TIMEOUT = 30m
GO_TEST_TIMEOUT = 3h
GO_TEST_DIRECTORIES = tests integration-tests
```

### CI/CD Integration

For pipeline environments, set:

```bash
export IS_PIPELINE=true
export JOB_NAME="GitHub Actions"
export JOB_EMAIL="actions@github.com"
make configure
```

## Component Contents

### Root Makefile

The root `Makefile` provides repository initialization and dependency management:

**Key Targets**:

- `configure`: Full repository setup (dependencies, hooks, repo sync)
- `configure-dependencies`: Install tool dependencies via mise/asdf
- `configure-git-hooks`: Install pre-commit hooks
- `clean`: Remove synced components
- `validate`: Validate configuration and dependencies
- `help`: Display usage information

**Configurable Variables**:

- `REPO_MANIFESTS_URL`: Source for repo manifests
- `REPO_BRANCH`: Branch/tag to use
- `GITBASE`: Base URL for git repositories
- `IS_PIPELINE`: Enable pipeline mode
- `IS_AUTHENTICATED`: Enable authentication headers

### Tasks - Golang Makefile

Located at `tasks/golang/Makefile`, provides Go testing automation:

**Key Targets**:

- `go/test`: Run Go tests (excludes readonly tests)
- `go/readonly_test`: Run only readonly tests
- `go/lint`: Run golangci-lint on test code
- `go/list`: List test directories
- `go/validate`: Validate Go environment

**Configurable Variables**:

- `GO_TEST_DIRECTORIES`: Directories containing tests
- `GO_TEST_TIMEOUT`: Test execution timeout
- `GO_LINT_TIMEOUT`: Linter timeout
- `GO_LINT_CONFIG`: Path to golangci-lint config
- `GO_TEST_READONLY_DIRECTORY`: Name of readonly test directory

### Tasks - Modules Makefile

Located at `tasks/modules/Makefile`, provides Terraform automation:

**Key Targets**:

- `tfmodule/init`: Initialize all modules and examples
- `tfmodule/lint`: Format, validate, and lint Terraform code
- `tfmodule/plan`: Generate Terraform plans
- `tfmodule/test/conftest`: Run Conftest policy tests
- `tfmodule/test/regula`: Run Regula policy tests
- `tfmodule/validate`: Validate Terraform environment

**Configurable Variables**:

- `TFLINT_CONFIG`: TFLint configuration file
- `VAR_FILE`: Terraform variables file for planning
- `POLICY_DIRECTORY`: Directory containing policy files
- `REGULA_SEVERITY`: Severity level for Regula (off/low/medium/high)
- `AWS_PROFILE`, `AWS_REGION`: AWS configuration

### Linkfiles

Configuration templates that should be linked or copied into target repositories:

- **`.golangci.yaml`**: Comprehensive golangci-lint configuration with timeout settings
- **`.tflint.hcl`**: TFLint configuration with rule sets
- **`.pre-commit-config.yaml`**: Pre-commit hooks for Terraform, Go, and general file checks

## Development

### Contributing

When making changes to this component:

1. Test changes in a consuming repository
2. Update documentation for new features
3. Follow the established configuration precedence pattern
4. Ensure backward compatibility when possible
5. Run pre-commit hooks: `pre-commit run --all-files`

### Debugging

Enable verbose output for troubleshooting:

```bash
# Terraform operations
make tfmodule/lint TFLINT_LOG_LEVEL=debug
# Go linting
make go/lint GO_LINT_VERBOSE="-v --print-issued-lines=false"
# See actual commands being run
make tfmodule/plan
```

## Requirements

### Core Tools

- **bash**: Shell (or compatible: zsh, Git Bash on Windows)
- **make**: GNU Make 3.81+
- **git**: Version control

### Terraform Tools

- **terraform**: 1.0+
- **tflint**: Latest version recommended

### Go Tools (if using Go tests)

- **go**: 1.21+
- **golangci-lint**: Latest version recommended

### Policy Tools (optional)

- **conftest**: For OPA policy testing
- **regula**: For Terraform policy scanning

### Dependency Managers (choose one)

- **mise**: Recommended (https://mise.jdx.dev/)
- **asdf**: Alternative (https://asdf-vm.com/)

### Python Tools (for pre-commit)

- **python3**: 3.8+
- **pip3**: For installing pre-commit

## License

Apache License 2.0 - See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please refer to the main Launch Common Automation Framework repository.
