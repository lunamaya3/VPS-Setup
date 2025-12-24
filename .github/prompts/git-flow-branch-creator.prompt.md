---
description: 'Intelligent Git Flow branch creator that analyzes git status/diff and creates appropriate branches following the nvie Git Flow branching model.'
tools: ['runCommands/runInTerminal', 'runCommands/getTerminalOutput']
agent: 'agent'
---

### Instructions

This prompt analyzes your current git changes using git status and git diff (or git diff --cached), then intelligently determines the appropriate branch type according to the Git Flow branching model and creates a semantic branch name.

Just run this prompt and Copilot will analyze your changes and create the appropriate Git Flow branch for you.

### Workflow

**Follow these steps:**

1. Run `git status` to review the current repository state and changed files.
2. Run `git diff` (for unstaged changes) or `git diff --cached` (for staged changes) to analyze the nature of changes.
3. Analyze the changes using the Git Flow Branch Analysis Framework below.
4. Determine the appropriate branch type based on the analysis.
5. Generate a semantic branch name following Git Flow conventions.
6. Create the branch and switch to it automatically.
7. Provide a summary of the analysis and next steps.

### Git Flow Branch Analysis Framework

**Branch Types:**

**Feature Branch:**
- Purpose: New features, enhancements, non-critical improvements
- Branch from: develop
- Merge to: develop
- Naming: feature/descriptive-name or feature/ticket-number-description
- Indicators: New functionality, UI/UX improvements, new API endpoints, database additions, new configuration options, performance improvements

**Release Branch:**
- Purpose: Release preparation, version bumps, final testing
- Branch from: develop
- Merge to: develop AND master
- Naming: release-X.Y.Z
- Indicators: Version changes, build config updates, documentation finalization, minor bug fixes, release notes, dependency version locks

**Hotfix Branch:**
- Purpose: Critical production bug fixes requiring immediate deployment
- Branch from: master
- Merge to: develop AND master
- Naming: hotfix-X.Y.Z or hotfix/critical-issue-description
- Indicators: Security vulnerability fixes, critical production bugs, data corruption fixes, service outage resolution, emergency configuration changes

### Branch Naming Conventions

**Feature Branches:** feature/[ticket-number-]descriptive-name
- feature/user-authentication
- feature/PROJ-123-shopping-cart
- feature/api-rate-limiting

**Release Branches:** release-X.Y.Z
- release-1.2.0
- release-2.1.0

**Hotfix Branches:** hotfix-X.Y.Z OR hotfix/critical-description
- hotfix-1.2.1
- hotfix/security-patch

### Analysis Process

1. **Change Nature Analysis** - Examine file types and nature of changes
2. **Git Flow Classification** - Map changes to appropriate Git Flow branch type
3. **Branch Name Generation** - Create semantic, descriptive branch name using kebab-case

### Edge Cases and Validation

- Mixed changes: Prioritize the most significant change type
- No changes detected: Inform user and suggest checking git status
- Already on a feature/hotfix/release branch: Analyze if new branch is needed
- Conflicting names: Append suffix or suggest alternative

### Final Execution

1. Provide analysis summary with git status/diff output
2. Explain why the specific branch type was chosen
3. Create the branch: `git checkout -b [branch-name] [source-branch]`
4. Verify branch creation and provide next steps
