---
agent: 'agent'
description: 'Update an existing specification file for the solution, optimized for Generative AI consumption based on new requirements or updates to any existing code.'
tools: ['changes', 'search/codebase', 'edit/editFiles', 'extensions', 'fetch', 'githubRepo', 'openSimpleBrowser', 'problems', 'runTasks', 'search', 'search/searchResults', 'runCommands/terminalLastCommand', 'runCommands/terminalSelection', 'testFailure', 'usages', 'vscodeAPI']
---

# Update Specification

Your goal is to update the existing specification file based on new requirements or updates to any existing code.

The specification file must define the requirements, constraints, and interfaces for the solution components in a manner that is clear, unambiguous, and structured for effective use by Generative AIs.

## Best Practices for AI-Ready Specifications

- Use precise, explicit, and unambiguous language
- Clearly distinguish between requirements, constraints, and recommendations
- Use structured formatting (headings, lists, tables) for easy parsing
- Avoid idioms, metaphors, or context-dependent references
- Define all acronyms and domain-specific terms
- Include examples and edge cases where applicable
- Ensure the document is self-contained and does not rely on external context

## Update Process

1. Review the existing specification file
2. Identify sections that need updates based on new requirements or code changes
3. Update the frontmatter (version, last_updated, etc.)
4. Modify relevant sections with new information
5. Ensure consistency and clarity throughout the document
6. Update examples and acceptance criteria as needed
7. Validate the updated specification against current code

## Key Sections to Consider Updating

- **Purpose & Scope**: Ensure scope still aligns with current project
- **Requirements**: Add new REQ-XXX entries for new requirements
- **Constraints**: Update or add new CON-XXX entries
- **Interfaces & Data Contracts**: Update based on code changes
- **Acceptance Criteria**: Ensure criteria reflect current implementation
- **Dependencies**: Update external system and service dependencies
- **Examples**: Refresh examples to match current behavior
- **Validation Criteria**: Update test requirements and acceptance standards

Always maintain backward compatibility information and note breaking changes clearly.
