# 🚀 Quick Reference: Using Awesome Copilot Collections

## One-Minute Quick Start

### For VPS Provisioning Planning
```
1. Ask Copilot: "@task-planner - Break down VPS provisioning into implementation tasks"
2. Then: "Use @create-implementation-plan to create detailed implementation plan"
3. Then: "Create GitHub issues from this plan"
```

### For Infrastructure Design
```
1. Ask: "@terraform-azure-planning - Design infrastructure for VPS provisioning"
2. Then: "@terraform-azure-implement - Generate Terraform code from the plan"
3. Check: Use #terraform-azure instructions for best practices
```

### For Cost Optimization
```
1. Ask: "@az-cost-optimize - Analyze Azure resource costs and generate optimizations"
2. Review: The recommendations will include priority scores and savings estimates
3. Create: GitHub issues for each optimization opportunity
```

### For Security Hardening
```
1. Load: #security-and-owasp
2. Load: #devops-core-principles
3. Apply: Guidelines to VPS provisioning scripts
```

---

## Agent Reference Quick Guide

### Planning & Project Management
| Agent | Best For | Quick Command |
|-------|----------|---------------|
| **@task-planner** | Breaking down complex tasks | "Break down VPS setup into implementation tasks" |
| **@task-researcher** | Researching technical unknowns | "Research how to implement multi-user RDP sessions" |
| **@implementation-plan** | Creating detailed implementation plans | "Create implementation plan for..." |
| **@research-technical-spike** | Validating assumptions | "Create a technical spike for RDP configuration" |
| **@prd** | Writing product requirements | "Create PRD for VPS developer environment" |
| **@planner** | General planning | "Plan the VPS provisioning approach" |
| **@plan** | Detailed planning | "Create detailed plan for Debian 13 configuration" |

### Azure & Infrastructure
| Agent | Best For | Quick Command |
|-------|----------|---------------|
| **@azure-principal-architect** | Architecture decisions | "Review architecture for VPS infrastructure" |
| **@azure-saas-architect** | Multi-tenant patterns | "Design multi-user VPS access patterns" |
| **@terraform-azure-planning** | Infrastructure planning | "Plan Azure infrastructure for VPS deployment" |
| **@terraform-azure-implement** | IaC code generation | "Generate Terraform code from infrastructure plan" |
| **@azure-verified-modules-terraform** | AVM implementation | "Use AVM modules for this infrastructure" |
| **@azure-verified-modules-bicep** | Bicep IaC | "Create Bicep templates for infrastructure" |
| **@azure-logic-apps-expert** | Logic Apps workflows | "Design workflow for provisioning automation" |

---

## Instructions Quick Reference

### Load Instructions in Copilot
Use `#instruction-name` syntax in your prompts:

```
#devops-core-principles - CALMS framework & DORA metrics
#terraform-azure - Azure-specific Terraform best practices
#security-and-owasp - Security hardening guidance
#azure-devops-pipelines - CI/CD pipeline best practices
#containerization-docker-best-practices - Docker optimization
#kubernetes-deployment-best-practices - K8s patterns
#performance-optimization - Performance tuning
#a11y - Accessibility guidelines
#object-calisthenics - Code quality patterns
#task-implementation - Task execution best practices
#spec-driven-workflow-v1 - Specification-driven development
```

### Most Used Instructions for VPS Project
1. `#devops-core-principles` - Foundation for all work
2. `#security-and-owasp` - VPS hardening
3. `#terraform-azure` - Infrastructure code
4. `#azure-devops-pipelines` - Automation & deployment
5. `#containerization-docker-best-practices` - If using containers

---

## Prompt Reference Quick Guide

### Use Prompts for Specific Outputs

| Prompt | Output | Use Case |
|--------|--------|----------|
| **create-implementation-plan** | Detailed implementation markdown | Planning feature work |
| **update-implementation-plan** | Updated plan file | Modifying existing plans |
| **create-github-issues-feature-from-implementation-plan** | GitHub issues from plan | Tracking work items |
| **breakdown-feature-implementation** | Task breakdown | Decompose features |
| **breakdown-feature-prd** | PRD from features | Requirements documentation |
| **breakdown-epic-arch** | Architecture breakdown | Infrastructure epics |
| **breakdown-epic-pm** | PM breakdown | Product epics |
| **create-technical-spike** | Spike document | Research & validation |
| **azure-resource-health-diagnose** | Diagnostics report | Troubleshooting |
| **az-cost-optimize** | Cost analysis with GitHub issues | Financial optimization |
| **multi-stage-dockerfile** | Optimized Dockerfile | Container optimization |

---

## Workflow Templates

### Workflow 1: Complete Feature from Concept to Deployment
```
1. Use @prd to write product requirements
2. Use @task-planner to break down feature
3. Use @create-implementation-plan to plan implementation
4. Use create-github-issues-feature-from-implementation-plan for tracking
5. Use @terraform-azure-planning if infrastructure needed
6. Use @terraform-azure-implement to generate IaC
7. Use #azure-devops-pipelines to add CI/CD
8. Use #security-and-owasp to harden security
```

### Workflow 2: Infrastructure Deployment
```
1. Use @azure-principal-architect to design
2. Use @terraform-azure-planning to plan
3. Use @terraform-azure-implement to code
4. Use #terraform-azure for best practices
5. Use #azure-devops-pipelines to automate
6. Use @az-cost-optimize to analyze costs
```

### Workflow 3: Troubleshooting & Incident Response
```
1. Use azure-resource-health-diagnose for diagnostics
2. Use @task-researcher to research solutions
3. Use @implementation-plan to plan fixes
4. Use @azure-principal-architect for architectural review
5. Use create-github-issues-feature-from-implementation-plan to track
```

### Workflow 4: Cost Optimization Sprint
```
1. Use @az-cost-optimize to analyze
2. Review recommendations and priority scores
3. Use @implementation-plan to plan optimizations
4. Use create-github-issues-feature-from-implementation-plan for tracking
5. Execute using #azure-devops-pipelines
```

### Workflow 5: Security Hardening
```
1. Load #security-and-owasp
2. Use @task-planner to break down hardening tasks
3. Use @create-implementation-plan for detailed planning
4. Create GitHub issues from plan
5. Execute with #terraform-azure or Docker instructions
6. Validate with @azure-principal-architect
```

---

## Common Patterns & Examples

### Planning a Feature
```
You: "@task-planner - Break down implementing multi-session RDP for VPS"

Response: Gets list of tasks, dependencies, priorities
Then: "Use @create-implementation-plan to detail this plan"
Finally: "Create GitHub issues from this implementation plan"
```

### Designing Infrastructure
```
You: "@terraform-azure-planning - Plan infrastructure for multi-user RDP VPS"

Response: Infrastructure plan with resources, dependencies
Then: "@terraform-azure-implement - Generate Terraform code from this plan"
Check: Load #terraform-azure to validate code
```

### Analyzing Costs
```
You: "@az-cost-optimize - Analyze our Azure resource costs"

Response: Detailed analysis with recommendations
Includes: GitHub issues created automatically
Impact: Monthly savings estimates provided
```

### Hardening Security
```
You: "Load #security-and-owasp and review VPS provisioning for security"

Response: Security vulnerabilities and recommendations
Then: "@task-planner - Create security hardening tasks"
Result: Implementation plan for security improvements
```

---

## Key Metrics to Track (from DORA)

Use `#devops-core-principles` to understand:

1. **Deployment Frequency** - How often you deploy
   - Goal: Daily or multiple times per day
   - VPS: Each provisioning script update

2. **Lead Time for Changes** - Time from commit to production
   - Goal: Less than 1 hour
   - VPS: Provisioning script to deployed VPS

3. **Change Failure Rate** - % of changes that degrade service
   - Goal: 0-15%
   - VPS: Provisioning failures or broken features

4. **Mean Time to Recovery** - Time to fix issues
   - Goal: Less than 1 hour
   - VPS: Time to fix provisioning problems

---

## File Organization Reference

```
.github/
├── agents/
│   ├── @task-planner          ← Start here for planning
│   ├── @terraform-azure-*     ← Infrastructure design & code
│   ├── @azure-principal-*     ← Architecture validation
│   ├── @az-cost-optimize      ← Cost analysis (prompt-based)
│   └── @research-technical-* ← Research & validation
│
├── instructions/
│   ├── #devops-core-principles     ← Foundation
│   ├── #security-and-owasp        ← VPS hardening
│   ├── #terraform-azure           ← IaC patterns
│   ├── #azure-devops-pipelines    ← CI/CD setup
│   └── #performance-optimization  ← Tuning
│
└── prompts/
    ├── create-implementation-plan
    ├── create-github-issues-feature-from-implementation-plan
    ├── azure-resource-health-diagnose
    ├── az-cost-optimize
    └── multi-stage-dockerfile
```

---

## Pro Tips

### 1. Load Instructions First
Always load relevant instructions before detailed work:
```
You: "Load #devops-core-principles and #security-and-owasp, then review VPS provisioning"
```

### 2. Use Agents for Interaction
Agents maintain context and provide interactive dialog:
```
You: "@task-planner - Break down VPS provisioning"
Copilot: [Provides breakdown with options]
You: [Can refine, ask questions, iterate]
```

### 3. Use Prompts for Specific Outputs
Prompts generate particular document formats:
```
Use @create-implementation-plan → outputs .md file format
Use @az-cost-optimize → outputs GitHub issues + analysis
```

### 4. Combine Multiple Tools
Chain tools for maximum effectiveness:
```
@task-planner → @create-implementation-plan → create-github-issues-*
```

### 5. Reference External Context
When using agents/prompts, provide your spec files:
```
You: "Review specs/001-vps-dev-provision/spec.md and @task-planner break it down"
```

---

## Troubleshooting

### "Agent not found" error
- Check spelling of agent name with @
- Make sure it's in `.github/agents/` directory
- Try reloading Copilot

### "Instruction not found" error  
- Check spelling with # prefix
- Verify file exists in `.github/instructions/`
- Use full instruction name (with .instructions.md removed)

### "Too much output"
- Use prompts instead of agents for structured output
- Load only specific instructions needed
- Ask for abbreviated versions

### "Need more context"
- Load relevant instructions first
- Reference your spec files in prompts
- Provide specific constraints and requirements

---

## Quick Links

- 📋 **Terraform Azure**: `.github/instructions/terraform-azure.instructions.md`
- 🔒 **Security**: `.github/instructions/security-and-owasp.instructions.md`
- 🚀 **DevOps**: `.github/instructions/devops-core-principles.instructions.md`
- 📊 **Azure Pipelines**: `.github/instructions/azure-devops-pipelines.instructions.md`
- 📈 **Performance**: `.github/instructions/performance-optimization.instructions.md`

---

**Happy Copiloting! 🎉**

Remember to reference these tools early and often for the best results on your VPS provisioning project.

