---
name: build-stream-lint
description: Validate BuildStream element configuration for compliance with project standards. Use this before committing any changes to .bst files.
---

# BuildStream Lint

This skill provides validation for BuildStream element files to ensure they meet our project's configuration standards.

## Usage

- **Validate Element**: 
  ```bash
  # Run linting on a specific .bst file or the entire elements/ directory
  <path-to-bst-lint>/scripts/lint_element.sh <element_path>
  ```
- **Compliance Check**: Use this to ensure:
  - All required YAML keys are present.
  - Dependencies are properly categorized (build-depends vs depends).
  - Variables are consistently defined.

Always run this before committing changes to any `.bst` file.
