---
agent: 'agent'
description: 'Create a new specification file for the solution, optimized for Generative AI consumption.'
tools: ['changes', 'search/codebase', 'edit/editFiles', 'extensions', 'fetch', 'githubRepo', 'openSimpleBrowser', 'problems', 'runTasks', 'search', 'search/searchResults', 'runCommands/terminalLastCommand', 'runCommands/terminalSelection', 'testFailure', 'usages', 'vscodeAPI']
---

# Create Specification

Your goal is to create a new specification file optimized for Generative AI consumption.

## Best Practices for AI-Ready Specifications

- Use precise, explicit, and unambiguous language
- Clearly distinguish between requirements, constraints, and recommendations
- Use structured formatting (headings, lists, tables) for easy parsing
- Avoid idioms, metaphors, or context-dependent references
- Define all acronyms and domain-specific terms
- Include examples and edge cases where applicable
- Ensure the document is self-contained and does not rely on external context

## Specification File Template

```markdown
---
title: [Concise Title Describing the Specification's Focus]
version: [Optional: e.g., 1.0, Date]
date_created: [YYYY-MM-DD]
last_updated: [Optional: YYYY-MM-DD]
owner: [Optional: Team/Individual responsible for this spec]
tags: [Optional: List of relevant tags or categories]
---

# Introduction

[A short concise introduction to the specification and the goal it is intended to achieve.]

## 1. Purpose & Scope

[Provide a clear, concise description of the specification's purpose and the scope of its application.]

## 2. Definitions

[List and define all acronyms, abbreviations, and domain-specific terms.]

## 3. Requirements, Constraints & Guidelines

[Explicitly list all requirements, constraints, rules, and guidelines using bullet points or tables.]

- **REQ-001**: Requirement 1
- **CON-001**: Constraint 1
- **GUD-001**: Guideline 1

## 4. Interfaces & Data Contracts

[Describe the interfaces, APIs, data contracts, or integration points.]

## 5. Acceptance Criteria

[Define clear, testable acceptance criteria using Given-When-Then format.]

## 6. Test Automation Strategy

[Define the testing approach, frameworks, and automation requirements.]

## 7. Rationale & Context

[Explain the reasoning behind the requirements, constraints, and guidelines.]

## 8. Dependencies & External Integrations

[Define the external systems, services, and architectural dependencies.]

## 9. Examples & Edge Cases

[Provide code snippets or data examples demonstrating correct application.]

## 10. Validation Criteria

[List the criteria or tests that must be satisfied for compliance.]

## 11. Related Specifications / Further Reading

[Link to related specifications and external documentation.]
```

The specification file should be saved in the `/spec/` directory and named according to the convention: `spec-[a-z0-9-]+.md`
