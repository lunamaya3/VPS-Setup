---
description: 'Prompt and workflow for generating conventional commit messages using a structured XML format. Guides users to create standardized, descriptive commit messages in line with the Conventional Commits specification, including instructions, examples, and validation.'
tools: ['runCommands/runInTerminal', 'runCommands/getTerminalOutput']
---

### Instructions

This file contains a prompt template for generating conventional commit messages. It provides instructions, examples, and formatting guidelines to help users write standardized, descriptive commit messages in accordance with the Conventional Commits specification.

### Workflow

**Follow these steps:**

1. Run `git status` to review changed files.
2. Run `git diff` or `git diff --cached` to inspect changes.
3. Stage your changes with `git add <file>`.
4. Construct your commit message using the following structure.
5. After generating your commit message, execute the commit in your terminal.

### Commit Message Structure

```
type(scope): description
[optional: body]
[optional: footer]
```

### Commit Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that don't affect code meaning (formatting, semicolons, etc.)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Code change that improves performance
- **test**: Adding or updating tests
- **build**: Changes to build system or dependencies
- **ci**: Changes to CI/CD configuration
- **chore**: Other changes that don't modify code or tests
- **revert**: Reverts a previous commit

### Examples

- `feat(parser): add ability to parse arrays`
- `fix(ui): correct button alignment`
- `docs: update README with usage instructions`
- `refactor: improve performance of data processing`
- `chore: update dependencies`
- `feat!: send email on registration (BREAKING CHANGE: email service required)`

### Validation

- **Type**: Must be one of the allowed types listed above
- **Scope**: Optional but recommended for clarity
- **Description**: Required. Use imperative mood (e.g., "add", not "added")
- **Body**: Optional. Use for additional context
- **Footer**: Use for breaking changes or issue references

### Final Step

Replace with your constructed message. Include body and footer if needed.
