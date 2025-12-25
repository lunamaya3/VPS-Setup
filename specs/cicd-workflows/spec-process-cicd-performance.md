---
title: CI/CD Workflow Specification - Performance Benchmarking
version: 1.0
date_created: 2025-12-25
last_updated: 2025-12-25
owner: DevOps Team
tags: [process, cicd, github-actions, automation, performance, benchmarking, profiling]
---

## Workflow Overview

**Purpose**: Automated performance regression detection through provisioning benchmarks, resource usage profiling, and comparison against baseline metrics

**Trigger Events**:
- Successful CI test completion on `main` branch
- Manual workflow dispatch with commit comparison
- Scheduled nightly runs at 01:00 UTC
- Git tag creation (release benchmarking)

**Target Environments**: Self-hosted runner with Debian 13 VM, consistent hardware specs

## Execution Flow Diagram

```mermaid
graph TD
    A[Trigger Event] --> B{Runner Available?}
    B -->|Yes| C[Provision Clean VM]
    B -->|No| W[Queue Job]
    W --> B
    C --> D[Baseline Capture]
    D --> E[Run Full Provision]
    E --> F[Measure Metrics]
    F --> G[Idempotent Re-run]
    G --> H[Measure Re-run]
    H --> I[Profile Hot Paths]
    I --> J[Compare vs Baseline]
    J --> K{Regression?}
    K -->|Yes >10%| L[Fail & Alert]
    K -->|Yes 5-10%| M[Warn PR]
    K -->|No| N[Update Baseline]
    N --> O[Generate Report]
    M --> O
    O --> P[Upload Artifacts]
    P --> Q[Publish Results]
    Q --> R[Success]
    
    E -->|Timeout| S[Collect State]
    S --> T[Debug Report]
    T --> L
    
    style A fill:#e1f5fe
    style R fill:#e8f5e8
    style L fill:#ffebee
    style K fill:#fff9c4
```

See complete specification with all sections at this location.
