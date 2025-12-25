---
title: CI/CD Workflow Specification - Security Scanning
version: 1.0
date_created: 2025-12-25
last_updated: 2025-12-25
owner: Security & DevOps Team
tags: [process, cicd, github-actions, automation, security, sast, sca, secrets, vulnerability]
---

## Workflow Overview

**Purpose**: Automated security vulnerability detection through static analysis, dependency scanning, secret detection, and container scanning

**Trigger Events**:
- Pull requests to `main` branch
- Push to `main` branch  
- Push to branches matching `feature/*`, `fix/*`
- Scheduled weekly scans (Sunday 02:00 UTC)
- Manual workflow dispatch

**Target Environments**: Ubuntu 22.04 runners with security scanning tools

## Execution Flow Diagram

```mermaid
graph TD
    A[Trigger Event] --> B[Setup Scanners]
    B --> C[Secret Scan]
    B --> D[SAST Analysis]
    B --> E[Dependency Scan]
    B --> F[Shell Script Security]
    
    C --> G{Secrets Found?}
    D --> H{Critical Issues?}
    E --> I{HIGH+ CVEs?}
    F --> J{Security Warnings?}
    
    G -->|Yes| Z[Block & Alert]
    G -->|No| K[Aggregate Results]
    H -->|Yes| Z
    H -->|No| K
    I -->|Yes| Z
    I -->|No| K
    J -->|Yes| L[Review Required]
    J -->|No| K
    
    K --> M[Generate Report]
    L --> M
    M --> N[Upload SARIF]
    N --> O[Create Issues]
    O --> P[Notify Team]
    P --> Q[Success]
    
    style A fill:#e1f5fe
    style Q fill:#e8f5e8
    style Z fill:#ffebee
    style G fill:#fff9c4
    style H fill:#fff9c4
    style I fill:#fff9c4
```

See complete specification with all sections at this location.
