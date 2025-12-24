---
description: 'Comprehensive technology-agnostic prompt for analyzing and documenting project folder structures. Auto-detects project types (.NET, Java, React, Angular, Python, Node.js, Flutter), generates detailed blueprints with visualization options, naming conventions, file placement patterns, and extension templates for maintaining consistent code organization across diverse technology stacks.'
agent: 'agent'
---

# Project Folder Structure Blueprint Generator

## Overview

This prompt analyzes your project's folder structure and creates a comprehensive `Project_Folders_Structure_Blueprint.md` document that serves as a definitive guide for maintaining consistent code organization.

## Analysis Approach

### Initial Auto-detection Phase

1. Scan the folder structure for key files that identify the project type:
   - Solution/project files (.sln, .csproj) for .NET projects
   - Build files (pom.xml, build.gradle) for Java projects
   - package.json for JavaScript/TypeScript projects
   - Framework files (angular.json, next.config.js) for specific frameworks
   - requirements.txt or setup.py for Python projects
   - pubspec.yaml for Flutter projects

2. Determine if this is a monorepo by looking for:
   - Multiple distinct projects with their own configuration files
   - Workspace configuration files (lerna.json, nx.json, turborepo.json)
   - Cross-project references and shared dependency patterns

3. Check for microservices architecture indicators:
   - Multiple service directories with similar structures
   - Service-specific Dockerfiles or deployment configurations
   - Inter-service communication patterns
   - API gateway configuration files

## Output Format

The generated document includes:

### 1. Structural Overview
- High-level overview of project organization principles
- Main organizational patterns (by feature, by layer, by domain)
- Architecture reflection in the folder structure

### 2. Directory Visualization
- ASCII tree or markdown list representation of folder hierarchy
- File organization patterns at each level

### 3. Key Directory Analysis
- Purpose and contents of significant directories
- File patterns and conventions
- Language-specific structure patterns

### 4. File Placement Patterns
- Where different types of files should be placed
- Configuration file locations
- Model/entity definitions location
- Business logic organization
- Test file patterns

### 5. Naming and Organization Conventions
- File naming patterns (PascalCase, camelCase, kebab-case)
- Folder naming conventions
- Namespace/module patterns
- Organizational patterns (code co-location, feature encapsulation)

### 6. Navigation and Development Workflow
- Entry points and key starting files
- Common development tasks and where to perform them
- Where to add new features
- Dependency patterns and flow

### 7. Build and Output Organization
- Build configuration locations
- Build process organization
- Output structure and deployment organization
- Environment-specific build patterns

### 8. Technology-Specific Organization
- Language and framework-specific patterns
- Best practice organization for detected technologies

### 9. Extension and Evolution
- How to add new modules/features while maintaining conventions
- Scalability patterns and refactoring approaches

### 10. Structure Enforcement
- Tools/scripts that enforce structure
- How structural changes are documented
- Architecture decision recording

## Success Criteria

The generated blueprint should:
1. Clearly explain the project's organization principles
2. Provide both visual and textual representation of structure
3. Define naming conventions and file placement rules
4. Guide new developers on where to add code
5. Document how the structure handles growth and evolution
6. Be maintainable and update-friendly
