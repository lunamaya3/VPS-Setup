---
agent: 'agent'
description: 'Create an llms.txt file from scratch based on repository structure following the llms.txt specification at https://llmstxt.org/'
tools: ['changes', 'search/codebase', 'edit/editFiles', 'extensions', 'fetch', 'githubRepo', 'openSimpleBrowser', 'problems', 'runTasks', 'search', 'search/searchResults', 'runCommands/terminalLastCommand', 'runCommands/terminalSelection', 'testFailure', 'usages', 'vscodeAPI']
---

# Create LLMs.txt File from Repository Structure

Create a new `llms.txt` file from scratch in the root of the repository following the official llms.txt specification at https://llmstxt.org/. This file provides high-level guidance to large language models (LLMs) on where to find relevant content for understanding the repository's purpose and specifications.

## Primary Directive

Create a comprehensive `llms.txt` file that serves as an entry point for LLMs to understand and navigate the repository effectively. The file must comply with the llms.txt specification and be optimized for LLM consumption while remaining human-readable.

## Analysis and Planning

### Step 1: Review llms.txt Specification
- Review https://llmstxt.org/ to ensure full compliance
- Understand the required format structure and guidelines
- Note the specific markdown structure requirements

### Step 2: Repository Structure Analysis
- Examine the complete repository structure
- Identify the primary purpose and scope
- Catalog all important directories and their purposes
- List key files valuable for LLM understanding

### Step 3: Content Discovery
- Identify README files and their locations
- Find documentation files (`.md` files in `/docs/`, `/spec/`, etc.)
- Locate specification files and their purposes
- Discover configuration files and their relevance
- Find example files and code samples

### Step 4: Create Implementation Plan
- Repository purpose and scope summary
- Priority-ordered list of essential files
- Secondary files that provide additional context
- Organizational structure for the llms.txt file

## Implementation Requirements

### Format Compliance

The `llms.txt` file must follow this exact structure per the specification:

1. **H1 Header**: Single line with repository/project name (required)
2. **Blockquote Summary**: Brief description in blockquote format (optional but recommended)
3. **Additional Details**: Zero or more markdown sections without headings for context
4. **File List Sections**: Zero or more H2 sections containing markdown lists of links

### Content Requirements

**Required Elements:**
- Project Name: Clear, descriptive title as H1
- Summary: Concise blockquote explaining the repository's purpose
- Key Files: Essential files organized by category (H2 sections)

**File Link Format:**
Each file link must follow: `[descriptive-name](relative-url): optional description`

**Section Organization:**
- **Documentation**: Core documentation files
- **Specifications**: Technical specifications and requirements
- **Examples**: Sample code and usage examples
- **Configuration**: Setup and configuration files
- **Optional**: Secondary files that can be skipped for shorter context

### Content Guidelines

**Language and Style:**
- Use concise, clear, unambiguous language
- Avoid jargon without explanation
- Write for both human and LLM readers
- Be specific and informative in descriptions

**File Selection Criteria:**
Include files that:
- Explain the repository's purpose and scope
- Provide essential technical documentation
- Show usage examples and patterns
- Define interfaces and specifications
- Contain configuration and setup instructions

Exclude files that:
- Are purely implementation details
- Contain redundant information
- Are build artifacts or generated content
- Are not relevant to understanding the project

## Quality Assurance

### Format Validation
- ✅ H1 header with project name
- ✅ Blockquote summary (if included)
- ✅ H2 sections for file lists
- ✅ Proper markdown link format
- ✅ No broken or invalid links
- ✅ Consistent formatting throughout

### Specification Compliance
- ✅ Follows https://llmstxt.org/ format exactly
- ✅ Uses required markdown structure
- ✅ File located at repository root (`/llms.txt`)
