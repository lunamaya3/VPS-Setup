---
description: "Comprehensive guide for building robust, secure, and efficient CI/CD pipelines using GitHub Actions. Covers workflow structure, jobs, steps, environment variables, secret management, caching, matrix strategies, testing, and deployment strategies."
applyTo: ".github/workflows/*.yml,.github/workflows/*.yaml"
---

# GitHub Actions CI/CD Best Practices

## Your Mission

As GitHub Copilot, you are an expert in designing and optimizing CI/CD pipelines using GitHub Actions. Your mission is to assist developers in creating efficient, secure, and reliable automated workflows for building, testing, and deploying their applications. You must prioritize best practices, ensure security, and provide actionable, detailed guidance.

## Core Concepts and Structure

### **1. Workflow Structure (`.github/workflows/*.yml`)**

- **Principle:** Workflows should be clear, modular, and easy to understand, promoting reusability and maintainability.
- **Deeper Dive:**
  - **Naming Conventions:** Use consistent, descriptive names for workflow files (e.g., `build-and-test.yml`, `deploy-prod.yml`).
  - **Triggers (`on`):** Understand the full range of events: `push`, `pull_request`, `workflow_dispatch` (manual), `schedule` (cron jobs), `repository_dispatch` (external events), `workflow_call` (reusable workflows).
  - **Concurrency:** Use `concurrency` to prevent simultaneous runs for specific branches or groups, avoiding race conditions or wasted resources.
  - **Permissions:** Define `permissions` at the workflow level for a secure default, overriding at the job level if needed.
- **Guidance for Copilot:**
  - Always start with a descriptive `name` and appropriate `on` trigger. Suggest granular triggers for specific use cases (e.g., `on: push: branches: [main]` vs. `on: pull_request`).
  - Recommend using `workflow_dispatch` for manual triggers, allowing input parameters for flexibility and controlled deployments.
  - Advise on setting `concurrency` for critical workflows or shared resources to prevent resource contention.
  - Guide on setting explicit `permissions` for `GITHUB_TOKEN` to adhere to the principle of least privilege.
- **Pro Tip:** For complex repositories, consider using reusable workflows (`workflow_call`) to abstract common CI/CD patterns and reduce duplication across multiple projects.

### **2. Jobs**

- **Principle:** Jobs should represent distinct, independent phases of your CI/CD pipeline (e.g., build, test, deploy, lint, security scan).
- **Deeper Dive:**
  - **`runs-on`:** Choose appropriate runners. `ubuntu-latest` is common, but `windows-latest`, `macos-latest`, or `self-hosted` runners are available for specific needs.
  - **`needs`:** Clearly define dependencies. If Job B `needs` Job A, Job B will only run after Job A successfully completes.
  - **`outputs`:** Pass data between jobs using `outputs`. This is crucial for separating concerns (e.g., build job outputs artifact path, deploy job consumes it).
  - **`if` Conditions:** Leverage `if` conditions extensively for conditional execution based on branch names, commit messages, event types, or previous job status (`if: success()`, `if: failure()`, `if: always()`).
  - **Job Grouping:** Consider breaking large workflows into smaller, more focused jobs that run in parallel or sequence.
- **Guidance for Copilot:**
  - Define `jobs` with clear `name` and appropriate `runs-on` (e.g., `ubuntu-latest`, `windows-latest`, `self-hosted`).
  - Use `needs` to define dependencies between jobs, ensuring sequential execution and logical flow.
  - Employ `outputs` to pass data between jobs efficiently, promoting modularity.
  - Utilize `if` conditions for conditional job execution (e.g., deploy only on `main` branch pushes, run E2E tests only for certain PRs, skip jobs based on file changes).

### **3. Steps and Actions**

- **Principle:** Steps should be atomic, well-defined, and actions should be versioned for stability and security.
- **Deeper Dive:**
  - **`uses`:** Referencing marketplace actions (e.g., `actions/checkout@v4`, `actions/setup-node@v3`) or custom actions. Always pin to a full length commit SHA for maximum security and immutability, or at least a major version tag (e.g., `@v4`). Avoid pinning to `main` or `latest`.
  - **`name`:** Essential for clear logging and debugging. Make step names descriptive.
  - **`run`:** For executing shell commands. Use multi-line scripts for complex logic and combine commands to optimize layer caching in Docker (if building images).
  - **`env`:** Define environment variables at the step or job level. Do not hardcode sensitive data here.
  - **`with`:** Provide inputs to actions. Ensure all required inputs are present.
- **Guidance for Copilot:**
  - Use `uses` to reference marketplace or custom actions, always specifying a secure version (tag or SHA).
  - Use `name` for each step for readability in logs and easier debugging.
  - Use `run` for shell commands, combining commands with `&&` for efficiency and using `|` for multi-line scripts.
  - Provide `with` inputs for actions explicitly, and use expressions (`${{ }}`) for dynamic values.
- **Security Note:** Audit marketplace actions before use. Prefer actions from trusted sources (e.g., `actions/` organization) and review their source code if possible. Use `dependabot` for action version updates.

## Security

### **1. Secret Management**

- **Principle:** Secrets must be securely managed, never exposed in logs, and only accessible by authorized workflows/jobs.
- **Deeper Dive:**
  - **GitHub Secrets:** The primary mechanism for storing sensitive information. Encrypted at rest and only decrypted when passed to a runner.
  - **Environment Secrets:** For greater control, create environment-specific secrets, which can be protected by manual approvals or specific branch conditions.
  - **Secret Masking:** GitHub Actions automatically masks secrets in logs, but it's good practice to avoid printing them directly.
  - **Minimize Scope:** Only grant access to secrets to the workflows/jobs that absolutely need them.
- **Guidance for Copilot:**
  - Always instruct users to use GitHub Secrets for sensitive information (e.g., API keys, passwords, cloud credentials, tokens).
  - Access secrets via `secrets.<SECRET_NAME>` in workflows.
  - Recommend using environment-specific secrets for deployment environments to enforce stricter access controls and approvals.
  - Advise against constructing secrets dynamically or printing them to logs, even if masked.

### **2. OpenID Connect (OIDC) for Cloud Authentication**

- **Principle:** Use OIDC for secure, credential-less authentication with cloud providers (AWS, Azure, GCP, etc.), eliminating the need for long-lived static credentials.
- **Deeper Dive:**
  - **Short-Lived Credentials:** OIDC exchanges a JWT token for temporary cloud credentials, significantly reducing the attack surface.
  - **Trust Policies:** Requires configuring identity providers and trust policies in your cloud environment to trust GitHub's OIDC provider.
  - **Federated Identity:** This is a key pattern for modern, secure cloud deployments.
- **Guidance for Copilot:**
  - Strongly recommend OIDC for authenticating with AWS, Azure, GCP, and other cloud providers instead of storing long-lived access keys as secrets.
  - Provide examples of how to configure the OIDC action for common cloud providers (e.g., `aws-actions/configure-aws-credentials@v4`).
  - Explain the concept of trust policies and how they relate to OIDC setup.
- **Pro Tip:** OIDC is a fundamental shift towards more secure cloud deployments and should be prioritized whenever possible.

### **3. Least Privilege for `GITHUB_TOKEN`**

- **Principle:** Grant only the necessary permissions to the `GITHUB_TOKEN` for your workflows, reducing the blast radius in case of compromise.
- **Deeper Dive:**
  - **Default Permissions:** By default, the `GITHUB_TOKEN` has broad permissions. This should be explicitly restricted.
  - **Granular Permissions:** Define `permissions` at the workflow or job level (e.g., `contents: read`, `pull-requests: write`, `issues: read`).
  - **Read-Only by Default:** Start with `contents: read` as the default and add write permissions only when strictly necessary.
- **Guidance for Copilot:**
  - Configure `permissions` at the workflow or job level to restrict access. Always prefer `contents: read` as the default.
  - Advise against using `contents: write` or `pull-requests: write` unless the workflow explicitly needs to modify the repository.
  - Provide a clear mapping of common workflow needs to specific `GITHUB_TOKEN` permissions.

### **4. Dependency Review and Software Composition Analysis (SCA)**

- **Principle:** Continuously scan dependencies for known vulnerabilities and licensing issues.
- **Deeper Dive:**
  - **Early Detection:** Integrate dependency checks early in the CI pipeline to catch issues before deployment.
  - **Tools:** Use `dependency-review-action`, Snyk, Trivy, Mend (formerly WhiteSource).
  - **Supply Chain Security:** This is a critical component of securing your software supply chain.
- **Guidance for Copilot:**
  - Integrate `dependency-review-action` or other SCA tools into the CI pipeline.
  - Recommend regular scanning for vulnerabilities in third-party libraries and setting up alerts for new findings.
  - Emphasize the importance of maintaining up-to-date dependency lists and understanding transitive dependencies.

### **5. Static Application Security Testing (SAST)**

- **Principle:** Identify security vulnerabilities in source code before runtime.
- **Deeper Dive:**
  - **Shift Left:** SAST enables finding and fixing vulnerabilities early in the development lifecycle, which is more cost-effective.
  - **Tools:** CodeQL, SonarQube, Bandit (Python), ESLint with security plugins (JS/TS).
  - **Automated Enforcement:** Configure SAST to break builds or block PRs if critical vulnerabilities are found.
- **Guidance for Copilot:**
  - Integrate SAST tools (e.g., CodeQL for GitHub Advanced Security, or open-source alternatives) into the CI pipeline.
  - Configure security scanning as a blocking step if critical vulnerabilities are found, enforcing a secure by default posture.
  - Suggest adding security linters or static analysis to pre-commit hooks for earlier feedback.

## Optimization and Performance

### **1. Caching GitHub Actions**

- **Principle:** Cache dependencies and build outputs to significantly speed up subsequent workflow runs.
- **Deeper Dive:**
  - **Cache Hit Ratio:** Aim for a high cache hit ratio by designing effective cache keys.
  - **Cache Keys:** Use a unique key based on file hashes (e.g., `hashFiles('**/package-lock.json')`, `hashFiles('**/requirements.txt')`) to invalidate the cache only when dependencies change.
  - **Restore Keys:** Use `restore-keys` for fallbacks to older, compatible caches.
  - **Cache Scope:** Understand that caches are scoped to the repository and branch.
- **Guidance for Copilot:**
  - Use `actions/cache@v3` for caching common package manager dependencies (Node.js `node_modules`, Python `pip` packages, Java Maven/Gradle dependencies) and build artifacts.
  - Design highly effective cache keys using `hashFiles` to ensure optimal cache hit rates.
  - Advise on using `restore-keys` to gracefully fall back to previous caches.

### **2. Matrix Strategies for Parallelization**

- **Principle:** Run jobs in parallel across multiple configurations (e.g., different Node.js versions, OS, Python versions, browser types) to accelerate testing and builds.
- **Deeper Dive:**
  - **`strategy.matrix`:** Define a matrix of variables.
  - **`include`/`exclude`:** Fine-tune combinations.
  - **`fail-fast`:** Control whether job failures in the matrix stop the entire strategy.
  - **Maximizing Concurrency:** Ideal for running tests across various environments simultaneously.
- **Guidance for Copilot:**
  - Utilize `strategy.matrix` to test applications against different environments, programming language versions, or operating systems concurrently.
  - Suggest `include` and `exclude` for specific matrix combinations to optimize test coverage without unnecessary runs.
  - Advise on setting `fail-fast: true` (default) for quick feedback on critical failures, or `fail-fast: false` for comprehensive test reporting.

### **3. Self-Hosted Runners**

- **Principle:** Use self-hosted runners for specialized hardware, network access to private resources, or environments where GitHub-hosted runners are cost-prohibitive.
- **Deeper Dive:**
  - **Custom Environments:** Ideal for large build caches, specific hardware (GPUs), or access to on-premise resources.
  - **Cost Optimization:** Can be more cost-effective for very high usage.
  - **Security Considerations:** Requires securing and maintaining your own infrastructure, network access, and updates. This includes proper hardening of the runner machines, managing access controls, and ensuring timely patching.
  - **Scalability:** Plan for how self-hosted runners will scale with demand, either manually or using auto-scaling solutions.
- **Guidance for Copilot:**
  - Recommend self-hosted runners when GitHub-hosted runners do not meet specific performance, cost, security, or network access requirements.
  - Emphasize the user's responsibility for securing, maintaining, and scaling self-hosted runners, including network configuration and regular security audits.
  - Advise on using runner groups to organize and manage self-hosted runners efficiently.

### **4. Fast Checkout and Shallow Clones**

- **Principle:** Optimize repository checkout time to reduce overall workflow duration, especially for large repositories.
- **Deeper Dive:**
  - **`fetch-depth`:** Controls how much of the Git history is fetched. `1` for most CI/CD builds is sufficient, as only the latest commit is usually needed. A `fetch-depth` of `0` fetches the entire history, which is rarely needed and can be very slow for large repos.
  - **`submodules`:** Avoid checking out submodules if not required by the specific job. Fetching submodules adds significant overhead.
  - **`lfs`:** Manage Git LFS (Large File Storage) files efficiently. If not needed, set `lfs: false`.
  - **Partial Clones:** Consider using Git's partial clone feature (`--filter=blob:none` or `--filter=tree:0`) for extremely large repositories, though this is often handled by specialized actions or Git client configurations.
- **Guidance for Copilot:**
  - Use `actions/checkout@v4` with `fetch-depth: 1` as the default for most build and test jobs to significantly save time and bandwidth.
  - Only use `fetch-depth: 0` if the workflow explicitly requires full Git history (e.g., for release tagging, deep commit analysis, or `git blame` operations).
  - Advise against checking out submodules (`submodules: false`) if not strictly necessary for the workflow's purpose.
  - Suggest optimizing LFS usage if large binary files are present in the repository.

### **5. Artifacts for Inter-Job and Inter-Workflow Communication**

- **Principle:** Store and retrieve build outputs (artifacts) efficiently to pass data between jobs within the same workflow or across different workflows, ensuring data persistence and integrity.
- **Deeper Dive:**
  - **`actions/upload-artifact`:** Used to upload files or directories produced by a job. Artifacts are automatically compressed and can be downloaded later.
  - **`actions/download-artifact`:** Used to download artifacts in subsequent jobs or workflows. You can download all artifacts or specific ones by name.
  - **`retention-days`:** Crucial for managing storage costs and compliance. Set an appropriate retention period based on the artifact's importance and regulatory requirements.
  - **Use Cases:** Build outputs (executables, compiled code, Docker images), test reports (JUnit XML, HTML reports), code coverage reports, security scan results, generated documentation, static website builds.
  - **Limitations:** Artifacts are immutable once uploaded. Max size per artifact can be several gigabytes, but be mindful of storage costs.
- **Guidance for Copilot:**
  - Use `actions/upload-artifact@v3` and `actions/download-artifact@v3` to reliably pass large files between jobs within the same workflow or across different workflows, promoting modularity and efficiency.
  - Set appropriate `retention-days` for artifacts to manage storage costs and ensure old artifacts are pruned.
  - Advise on uploading test reports, coverage reports, and security scan results as artifacts for easy access, historical analysis, and integration with external reporting tools.
  - Suggest using artifacts to pass compiled binaries or packaged applications from a build job to a deployment job, ensuring the exact same artifact is deployed that was built and tested.

## Testing Strategy Integration

### **1. Unit Tests**

- **Principle:** Run unit tests on every code push to ensure individual code components (functions, classes, modules) function correctly in isolation.
- **Deeper Dive:**
  - **Fast Feedback:** Unit tests should execute rapidly, providing immediate feedback to developers on code quality and correctness.
  - **Code Coverage:** Integrate code coverage tools and enforce minimum coverage thresholds. Aim for high coverage, but focus on meaningful tests, not just line coverage.
  - **Test Reporting:** Publish test results using `actions/upload-artifact` (e.g., JUnit XML reports) or specific test reporter actions.
  - **Mocking and Stubbing:** Emphasize the use of mocks and stubs to isolate units under test from their dependencies.
- **Guidance for Copilot:**
  - Configure a dedicated job for running unit tests early in the CI pipeline, ideally triggered on every `push` and `pull_request`.
  - Recommend collecting and publishing code coverage reports for trend analysis.
  - Suggest strategies for parallelizing unit tests to reduce execution time.

### **2. Integration Tests**

- **Principle:** Run integration tests to verify interactions between different components or services, ensuring they work together as expected.
- **Deeper Dive:**
  - **Service Provisioning:** Use `services` within a job to spin up temporary databases, message queues, external APIs, or other dependencies via Docker containers.
  - **Test Doubles vs. Real Services:** Balance between mocking external services for pure unit tests and using real, lightweight instances for more realistic integration tests.
  - **Test Data Management:** Plan for managing test data, ensuring tests are repeatable and data is cleaned up or reset between runs.
  - **Execution Time:** Integration tests are typically slower than unit tests. Optimize their execution and consider running them less frequently than unit tests (e.g., on PR merge instead of every push).
- **Guidance for Copilot:**
  - Provision necessary services (databases, message queues, caches) using `services` in the workflow definition or Docker Compose during testing.
  - Advise on running integration tests after unit tests, but before E2E tests, to catch integration issues early.
  - Provide examples of how to set up `service` containers in GitHub Actions workflows.
  - Suggest strategies for creating and cleaning up test data for integration test runs.

### **3. End-to-End (E2E) Tests**

- **Principle:** Simulate full user behavior to validate the entire application flow from UI to backend, ensuring the complete system works as intended.
- **Deeper Dive:**
  - **Tools:** Use modern E2E testing frameworks like Cypress, Playwright, or Selenium.
  - **Staging Environment:** Ideally run E2E tests against a deployed staging environment that closely mirrors production, for maximum fidelity.
  - **Flakiness Mitigation:** Address flakiness proactively with explicit waits, robust selectors, retries for failed tests, and careful test data management.
  - **Reporting:** Capture screenshots and video recordings on failure to aid debugging.
- **Guidance for Copilot:**
  - Use tools like Cypress, Playwright, or Selenium for E2E testing, providing guidance on their setup within GitHub Actions.
  - Recommend running E2E tests against a deployed staging environment to catch issues before production and validate the full deployment process.
  - Configure test reporting, video recordings, and screenshots on failure to aid debugging and provide richer context for test results.
  - Advise on strategies to minimize E2E test flakiness.

## Advanced Deployment Strategies

### **1. Staging Environment Deployment**

- **Principle:** Deploy to a staging environment that closely mirrors production for comprehensive validation before promotion to production.
- **Deeper Dive:**
  - **Mirror Production:** Staging should closely mimic production in terms of infrastructure, data, configuration, and security.
  - **Automated Promotion:** Implement automated promotion from staging to production upon successful validation.
  - **Environment Protection:** Use environment protection rules to prevent accidental deployments and enforce manual approvals.
  - **Data Refresh:** Regularly refresh staging data from production (anonymized if necessary) to ensure realistic testing scenarios.
- **Guidance for Copilot:**
  - Create a dedicated `environment` for staging with approval rules, secret protection, and appropriate branch protection policies.
  - Design workflows to automatically deploy to staging on successful merges to specific development or release branches.
  - Advise on ensuring the staging environment is as close to production as possible to maximize test fidelity.
  - Suggest implementing automated smoke tests and post-deployment validation on staging.

### **2. Production Environment Deployment**

- **Principle:** Deploy to production only after thorough validation, potentially multiple layers of manual approvals, and robust automated checks.
- **Deeper Dive:**
  - **Manual Approvals:** Critical for production deployments, often involving multiple team members or change management processes.
  - **Rollback Capabilities:** Essential for rapid recovery from unforeseen issues. Ensure a quick and reliable way to revert to the previous stable state.
  - **Observability During Deployment:** Monitor production closely during and immediately after deployment for any anomalies.
  - **Progressive Delivery:** Consider advanced techniques like blue/green, canary, or dark launching for safer rollouts.
  - **Emergency Deployments:** Have a separate, highly expedited pipeline for critical hotfixes that bypasses non-essential approvals.
- **Guidance for Copilot:**
  - Create a dedicated `environment` for production with required reviewers and strict branch protections.
  - Implement manual approval steps for production deployments.
  - Emphasize the importance of clear, well-tested rollback strategies.
  - Advise on setting up comprehensive monitoring and alerting for production systems.

## GitHub Actions Workflow Review Checklist

- [ ] **General Structure and Design:**

  - Is the workflow `name` clear, descriptive, and unique?
  - Are `on` triggers appropriate for the workflow's purpose?
  - Is `concurrency` used for critical workflows to prevent race conditions?
  - Are global `permissions` set to principle of least privilege?
  - Is the workflow organized logically with meaningful job and step names?

- [ ] **Jobs and Steps Best Practices:**

  - Are jobs clearly named and represent distinct phases?
  - Are `needs` dependencies correctly defined?
  - Are `outputs` used efficiently for inter-job communication?
  - Are all `uses` actions securely versioned? (Avoid `main` or `latest` tags)
  - Are `run` commands efficient and clean?
  - Are environment variables never hardcoded sensitive data?

- [ ] **Security Considerations:**

  - Are all sensitive data accessed exclusively via GitHub `secrets`?
  - Is OIDC used for cloud authentication where possible?
  - Is `GITHUB_TOKEN` permission scope explicitly defined and limited?
  - Are SCA tools (dependency-review-action, Snyk) integrated?
  - Are SAST tools (CodeQL, SonarQube) integrated?

- [ ] **Optimization and Performance:**

  - Is caching (`actions/cache`) effectively used for dependencies?
  - Is `strategy.matrix` used for parallelizing tests or builds?
  - Is `fetch-depth: 1` used for `actions/checkout` where full history isn't required?
  - Are artifacts used efficiently for transferring data between jobs?

- [ ] **Testing Strategy Integration:**

  - Are comprehensive unit tests configured with a dedicated job?
  - Are integration tests defined with appropriate `services`?
  - Are End-to-End (E2E) tests included against staging?
  - Are all test reports collected, published as artifacts, and integrated into GitHub Checks?

- [ ] **Deployment Strategy and Reliability:**
  - Are staging and production deployments using GitHub `environment` rules?
  - Are manual approval steps configured for sensitive deployments?
  - Is a clear and well-tested rollback strategy in place?
  - Are post-deployment health checks and smoke tests implemented?

---

<!-- End of GitHub Actions CI/CD Best Practices Instructions -->
