# GitHub Copilot Instructions for Project Brahmanda

> **Primary Instructions for VSCode:** This file contains comprehensive guidelines for working with Project Brahmanda in VSCode with GitHub Copilot. The `.cursorrules` file in the repository root is maintained for reference but this file is authoritative for VSCode development.

## Core Philosophy

Project Brahmanda adheres to the **"Asanga Shastra"** (Weapon of Detachment) - the principle that all infrastructure is **transient** and must be capable of being destroyed and recreated at will via code.

> "The real form of this tree (of Brahmanda) is not perceived in this world... Having cut down this firmly rooted tree with the strong weapon of detachment..." — Bhagavad Gita 15.3

### Idempotency Principle

**All automation must be idempotent wherever possible:**
- Scripts can be run multiple times without adverse effects
- Failed operations can be resumed without starting from scratch
- Already-completed tasks are skipped intelligently
- State checks occur before destructive operations
- Clear messages indicate what was done vs. what was skipped

**Achieving idempotency through statelessness:**
- **Prefer statelessness:** Idempotency achieved through stateless operations is ideal
- **When state is unavoidable:** Keep state limited and concentrated in specific locations
- **Benefit:** Rest of the system remains stateless and simpler to reason about
- **Examples:**
  - Stateless: `dpkg -l | grep -qw terraform` (queries system state, no custom state file)
  - Concentrated state: Terraform state files (single source of truth, rest is declarative)
  - Concentrated state: `.cache/iso/` directory (download state isolated, scripts remain stateless)

**Examples of idempotent design:**
- `make init` checks if tools exist before installing (stateless: queries system)
- `make pratistha` reuses cached ISO (concentrated state: `.cache/` directory)
- Repository additions check if already configured (stateless: checks system files)
- File operations verify existence before downloading (stateless: file system is the state)
- Encryption/decryption check vault state before acting (stateless: reads file header)

## Project Goals

### Primary Purpose: Learning

**This is fundamentally a learning project for Abhishek (the user).** The most important outcome is that the user:
- Understands what works and what doesn't in actual production environments
- Gains hands-on experience that prepares them for similar work in professional settings
- Builds knowledge through both successes and failures
- Develops troubleshooting skills and architectural judgment

**When assisting:**
- Explain the "why" behind technical decisions, not just the "how"
- Don't hide complexity if understanding it provides learning value
- Highlight production considerations and real-world tradeoffs
- Share context about why certain approaches are preferred over others

### Secondary Purpose: Public Project Lab

**This homelab serves as a testing and demonstration platform:**
- **Technology Exploration:** Deploy technologies to learn hands-on (e.g., Kafka, AI services)
- **Production-Like Learning:** Learn what it takes to keep services healthy long-term
- **Public Access:** Optimize deployments so others can access and benefit from projects
- **Practical Application:** Create real services that provide value while enabling learning

**Example Learning Pattern:**
- Want to learn Kafka → Deploy Kafka → Use it in a project → Learn operational best practices
- Want to learn AI → Create AI-powered service → Deploy on homelab → Learn deployment/scaling challenges

### Quality Standard: 99% Perfection

**Target 99% quality, not 100% or less:**
- **100% perfection** avoid if it is unnecessary and adds significant complexity
- **Less than 99%** doesn't meet production-grade standards
- **99% sweet spot** balances production-readiness with practical implementation

**In practice:**
- Handle expected errors and edge cases
- Use production-appropriate patterns and tools
- Include monitoring and observability
- Skip over-engineered solutions for theoretical edge cases

### Development Methodology: Agile

**Work iteratively with these principles:**
- Each iteration must produce something **useful and workable**
- Deliver incrementally - don't wait for perfection before showing progress
- Respond to change - adjust plans based on learnings

**Iteration guidelines:**
- Break large tasks into deployable increments
- Each increment should be testable and demonstrable
- Get feedback early and often
- Refactor as you learn, don't wait

### Current Priority: Samsara First

**The immediate goal is to establish remote change capability:**
- Focus on getting Terraform + Ansible automation working
- Enable Infrastructure as Code before manually configuring services
- Prioritize the "bootstrap problem" - get to a state where everything else can be automated
- Once Samsara is operational, all subsequent changes should go through it

**Why this matters:**
- Manual changes are not reproducible (violates "Weapon of Detachment")
- Getting stuck on-site defeats the purpose of a homelab
- The automation layer unlocks true iterative development

## Project Architecture

### The Three Planes of Existence

1. **Kshitiz (The Edge):** AWS Lightsail gateway and Nebula Lighthouse for external access
2. **Vyom (The Cluster):** On-premises compute (ASUS NUC) running Proxmox and K3s
3. **Samsara (The Cycle):** Terraform and Ansible automation for creation and destruction

**Critical Design Decision:** Nebula mesh is used **only for North-South traffic** (external → cluster ingress). Kubernetes internal communication (East-West) occurs over local LAN (VLAN 30) to avoid encryption overhead.

## Documentation Structure & Sanskrit Theme

### Core Documents (vaastu/)

**000-Brahmanda-Siddhanta.md** - The guiding philosophy and principles

**001-Sarga.md** - Day 0 Setup Manual
- Philosophy: Sarga means the manifestation of the Brahmanda itself. Analogous to "everything up to Mahasphota (The Big Bang)"
- Purpose: Step-by-step guide for laypersons that includes everything from hardware procurement to initial bootstrapping until the project is in a state where Infrastructure as Code can take charge
- Phases: Samidha (Prerequisites) → Upadana (Hardware) → Purvanga (Reconnaissance) → Pramana (Credentials) → Adhisthana (Secrets) → Sarga (OS) → Samsara (Automation) → Srishti (Manifestation)

**002-Visarga.md** - Day 1+ Operations Manual
- Philosophy: Visarga means creating matter, establishing metaphysical rules, and populating the Brahmanda. Analogous to "everything after Mahasphota (The Big Bang)", up to the population of its residence (microservices)
- Purpose: Operational workflows for expansion, deployment, and maintenance
- Focus: Vistara (Expansion), Sankalpa (Deployment), ongoing operations

### Decision Documents

**manthana/ (The Churning - RFCs)**
- Request for Comments - Discussion and debate phase
- Must include: Context, Scope (Current/Future/Out of Scope), Proposal, Alternatives with pros/cons, Impact, Conclusion
- RFCs are where we **evaluate options** - keep multiple alternatives with reasoning

**vidhana/ (The Constitutional Law - ADRs)**
- Architecture Decision Records - Finalized decisions only (Vidhanas are the fundamental laws that govern the Brahmanda)
- Must include: Context (brief), Decision (detailed with implementation), Implementation (code examples, configurations, commands), Consequences
- ADRs are **implementation guides** - no discussion of rejected alternatives, focus on "what and how to execute"
- Every ADR must reference its corresponding RFC for rationale

**vivechana/ (Critical Examination - RCAs)**
- Root Cause Analysis - Post-incident reviews
- **CRITICAL: Document failures systematically**
  - When something fails, create an RCA in `vaastu/vivechana/`
  - Include: What was attempted, what went wrong, root cause, solution/workaround
  - Purpose 1: Learning - "What goes wrong when you do X, what works instead"
  - Purpose 2: Avoid repeated mistakes - Check vivechana/ before implementing similar changes
  - RCAs are **valuable learning artifacts**, not just incident reports

### Learning Documents (vaastu/)

**When creating technology/concept learning documents:**
- **Structure like a story:** Beginning (what/why) → Middle (how) → End (gotchas/tips)
- **Efficient and concise:** Save learning time, reduce cognitive load
- **Well-formulated:** Use clear headings, examples, code snippets
- **Teach in less words:** Dense with value, minimal fluff
- **Referenceable:** Easy to skim and find specific information later

**Document structure for tool/technology learnings:**
1. **What:** Brief description and use case
2. **Why:** When to use it, what problems it solves
3. **How:** Installation, configuration, key commands/patterns
4. **Gotchas:** Common pitfalls, debugging tips, best practices
5. **References:** Official docs, useful resources

**Example Topics:**
- "Learning Kafka: Deployment to Production Operations"
- "K3s vs K8s: What Works in Homelab Context"
- "Longhorn Operational Patterns: Backup, Recovery, Expansion"

## Working Principles

### Problem-Solving Focus

**Focus on Current Problems:**
- Address the immediate problem at hand with precision
- Only expand scope when there's a concrete near-future plan that would benefit from current work
- Do NOT solve for hypothetical future problems unless:
  - They are urgently needed with proper rationale
  - The cost of solving now is significantly lower than solving later
  - The solution doesn't add complexity to the current implementation

**Example of Good Scoping:**
- User: "Add Longhorn storage"
- Good: Install Longhorn with single-replica StorageClass
- Bad: Pre-implement multi-node replication, disaster recovery, off-site backups when running single-node

**Example of Justified Expansion:**
- User: "Configure VLAN for management"
- Good: Configure VLAN 20 (Mgmt) AND mention VLAN 30 (DMZ) since network segmentation is the current focus
- Bad: Also implement service mesh, zero-trust networking, microsegmentation when those aren't in scope

### Quality Over Shortcuts

**Do NOT take shortcuts to reduce effort unless it's a completely rational decision:**
- Write production-grade code, not "MVP" or "prototype" code
- Include proper error handling, even for initial implementations
- Add verification steps to documentation, not just instructions
- Use idiomatic patterns for the language/tool (don't simplify for brevity)

**Acceptable Shortcuts (with rationale):**
- Using placeholder values when real values require external input: "Replace with your domain"
- Deferring optional features: "Email notifications can be added later if needed"
- Simplifying Day 0 manual steps: "Automated in Day 1+ with Ansible"

**Unacceptable Shortcuts:**
- Hardcoding secrets "for now" (always use vault references)
- Skipping error handling "to get it working first"
- Using `kubectl apply -f` instead of GitOps "for quick testing"
- Incomplete documentation "to save time"

### Iterative and Thorough Approach

**Critical Instruction:** When asked to work on a task:
1. Read relevant context before starting (RFCs, ADRs, related docs)
2. Break complex work into logical steps (use `manage_todo_list` tool)
3. Implement each step completely - no half-solutions
4. Verify consistency with existing architecture
5. Update related documentation when making changes

**Do NOT:**
- Complete tasks in a single pass without verification
- Make assumptions about user intent - ask or research
- Batch multiple unrelated changes without clear reasoning
- Skip reading existing documentation to "save time"

### Collaboration Principle: Ask When Unclear

**Do NOT hesitate to ask for additional information:**
- If requirements are ambiguous, ask for clarification
- If current context is insufficient, explicitly request what you need
- If a decision has downstream implications, surface them before proceeding

**Better to ask than:**
- Guess user intent and implement incorrectly
- Make arbitrary choices that don't align with user goals
- Discover missing requirements after significant work
- Proceed with incomplete information

**This is collaborative problem-solving, not autonomous execution.**

### Methodical Problem-Solving

**Approach problems systematically:**
1. **Understand:** Read existing documentation, check RFCs/ADRs, review vivechana/ for past failures
2. **Plan:** Break down the problem, identify dependencies, consider alternatives
3. **Research:** Check industry best practices, official documentation, proven patterns
4. **Implement:** Write code incrementally, test at each step, validate against requirements
5. **Verify:** Run verification commands, check for regressions, update documentation
6. **Document:** Record decisions, note learnings, update relevant vaastu/ documents

**Do NOT:**
- Jump to implementation without understanding the problem
- Ignore existing patterns and reinvent solutions
- Skip verification steps
- Leave undocumented changes

### Code Quality Standards

**Code should be like a work of art:**
- **Readable:** Clear variable/function names, logical structure, appropriate comments
- **Maintainable:** Modular design, DRY principle, single responsibility
- **Idiomatic:** Follow language/framework conventions and best practices
- **Tested:** Include verification steps, error handling, edge case consideration

**Industry-Standard Principles:**
- **SOLID principles** for object-oriented code
- **Twelve-Factor App** for cloud-native applications
- **Infrastructure as Code** best practices (immutability, idempotency, versioning)
- **GitOps** workflows (declarative, versioned, automated)
- **Security by Design** (defense-in-depth, least privilege, fail-secure)

**Use well-established:**
- Design patterns (Factory, Observer, Strategy, etc.)
- Architectural patterns (Layered, Microservices, Event-Driven)
- Naming conventions (PascalCase, camelCase, snake_case per language)
- Directory structures (language/framework standards)

## Technical Constraints

### Directory Structure (Immutable)

```
brahmanda-infra/
├── vaastu/              # Documentation & Architecture
│   ├── manthana/        # RFCs (discussion)
│   ├── vidhana/         # ADRs (decisions)
│   └── vivechana/       # RCAs (post-mortems)
├── samsara/             # Automation
│   ├── terraform/       # Infrastructure provisioning
│   └── ansible/         # Configuration management
├── sankalpa/            # GitOps manifests
│   ├── bootstrap.yaml   # Multi-root ArgoCD app
│   ├── core/            # System infrastructure
│   ├── observability/   # Monitoring stack
│   └── apps/            # Business applications
└── scripts/             # Utility scripts
```

## Writing Standards

### Style Guidelines

1. **Clarity over Brevity:** Prefer comprehensive explanations. Users should trust the documentation even if they lack expertise.
2. **Verification Steps:** After critical operations, include minimal `✅ Verification:` commands to confirm success.
3. **Why Before How:** Explain reasoning before providing commands.
4. **Collapsible Details:** Use `<details>` tags for lengthy technical specifications.
5. **Practical Tips:** Add `💡 TIP:` callouts for UX improvements.

### Terminology Consistency

**Sanskrit Terms (Use These):**
- Sarga: Primary creation (hardware, OS installation)
- Visarga: Secondary creation (population, evolution)
- Srishti: Manifestation/Big Bang (initial deployment)
- Pralaya: Dissolution/destruction (tear down)
- Sankalpa: Desired state (GitOps deployments)
- Tirodhana: Concealment (vault encryption - one of Shiva's five acts)
- Avirbhava: Manifestation (vault decryption - revealing hidden truth)
- Samshodhana: Editing (vault modification)

**Storage Locations:**
- 1Password Vault: "Project-Brahmanda" (NOT "Private")
- Ansible Vault: Encrypted secrets in Git
- GitHub Secrets: Only `OP_SERVICE_ACCOUNT_TOKEN`

## Code Standards

**All Code Must Be Idempotent:**
- Check state before making changes
- Skip operations that are already complete
- Provide clear feedback about what was done vs. skipped
- Handle partial failures gracefully (resume capability)
- Use tools' native idempotency features (apt, brew, Terraform, Ansible)

### Terraform
- Prefix resources with `kshitiz-` or `vyom-`
- Use explicit resource naming
- Include tags: `Project = "Brahmanda"`, `ManagedBy = "Terraform"`
- Inherently idempotent through state management

### Kubernetes
- All manifests must be ArgoCD Application CRDs
- Use GHCR for OCI Helm charts
- Namespace naming: `{layer}-{component}` (e.g., `core-longhorn`)

### Ansible
- Use the `utkuozdemir.nebula` role for Nebula deployment
- Store secrets in Ansible Vault
- Include task names with Sanskrit terms where appropriate

### Secrets
- NEVER hardcode credentials
- Always reference: `op://Project-Brahmanda/item/field` or `{{ vault_variable }}`
- Document which vault stores which secret

## File Maintenance

**Self-Maintenance Rule:** When making architectural or process changes, update:

1. **`.github/copilot-instructions.md` (This File):** New guidelines, constraints, or patterns
2. **`README.md`:** Project structure, philosophy, or quick-start changes
3. **`vaastu/001-Sarga.md`:** Day 0 setup process changes (new prerequisites, different tools)
4. **`vaastu/002-Visarga.md`:** Operational workflow changes (deployment patterns, expansion)
5. **Related RFCs/ADRs:** Ensure decisions remain consistent

## Common Anti-Patterns (Avoid These)

1. Running K8s cluster traffic through Nebula (use local LAN)
2. Self-hosted Harbor/Artifactory (use GHCR)
3. Storing secrets in 1Password "Private" vault (use "Project-Brahmanda")
4. Creating "umbrella charts" (use ArgoCD "App of Apps")
5. Writing plain Kubernetes YAMLs in sankalpa/ (must be ArgoCD Applications)
6. Forgetting minimal verification commands in setup documentation

<Goals>

These instructions aim to:
- Enable consistent, high-quality contributions to Project Brahmanda
- Reduce learning time by providing comprehensive project context
- Minimize build/deployment failures through clear verification steps
- Maintain philosophical consistency (Asanga Shastra - Weapon of Detachment)
- Support both learning objectives and production-grade implementation
- Preserve Sanskrit/Sanatana Dharma theming throughout the project

</Goals>

<Limitations>

- Instructions target 99% quality. Avoid 100% perfection if it is too complex and also avoid <99% due to insufficient quality
- Focus on current problems, not hypothetical future scenarios (unless urgently needed)
- Day 0 manual steps are acceptable for Sarga phase; automate in Samsara phase
- Single-node deployment is current scope; multi-node is future scope
- Home Automation is out of scope for now, but scoped for future phases
- Budget-conscious decisions (Longhorn over Ceph, GHCR over self-hosted registry)

</Limitations>

<BuildInstructions>

**Current State:** Infrastructure as Code setup in progress (Samsara First priority)

**Future Build Commands (Post-Samsara):**
- Terraform: `cd samsara/terraform && terraform init && terraform plan`
- Ansible: `cd samsara/ansible && ansible-playbook -i inventory site.yml`
- K3s Deployment: Via ArgoCD - `kubectl apply -f sankalpa/bootstrap.yaml`

**Validation:**
- After every critical step: Include `✅ Verification:` command in documentation
- Check vivechana/ before implementing similar changes (avoid repeated failures)
- Run Terraform plan before apply, Ansible check mode before execution

**Environment:**
- Local: Windows 10/11 with WSL2, 1Password CLI, Terraform, Ansible
- Edge: AWS Lightsail (Ubuntu 24.04 LTS) with Nebula Lighthouse
- Cluster: ASUS NUC (Proxmox 8.x, K3s on Debian 12)

</BuildInstructions>

<ProjectLayout>

**Repository Structure:**
- `vaastu/` - All documentation (philosophy, RFCs, ADRs, RCAs, learning docs)
- `samsara/` - Automation code (Terraform for infrastructure, Ansible for configuration)
- `sankalpa/` - GitOps manifests (ArgoCD Applications only, organized by layer)
- `scripts/` - Utility scripts for development/maintenance
- `.github/` - GitHub-specific files (this copilot-instructions.md, workflows)

**Key Files:**
- `vaastu/001-Sarga.md` - Complete Day 0 setup guide (hardware to bootstrap)
- `vaastu/002-Visarga.md` - Day 1+ operations (expansion, deployment)
- `Makefile` - Common development tasks
- `README.md` - Project overview and quick start

**Decision Flow:**
1. Problem arises → Create RFC in `vaastu/manthana/` (discuss alternatives)
2. Decision made → Create ADR in `vaastu/vidhana/` (implementation details)
3. Failure occurs → Create RCA in `vaastu/vivechana/` (learning artifact)
4. Learning emerges → Create/update learning doc in `vaastu/`

</ProjectLayout>

## Success Criteria

A change is successful when:
1. It maintains the Sanskrit/Sanatana Dharma theme
2. It aligns with the "Weapon of Detachment" philosophy
3. Documentation is comprehensive enough for a beginner to follow, yet not too verbose to obscure key points
4. Technical decisions are consistent with existing ADRs
5. Cross-references between documents remain valid
6. The project infrastructure can still be destroyed and recreated from these instructions
7. The solution addresses the current problem without unnecessary future-proofing
8. No shortcuts were taken that compromise production-readiness
9. **The user learned something valuable** (techniques, tradeoffs, what works/doesn't)
10. **Failures are documented** in vivechana/ for future reference
11. **Quality meets 99% standard** (production-grade without over-engineering)
12. **Iteration produced working increment** (testable, demonstrable, useful)

## GitHub Best Practices for copilot-instructions.md

**Key Recommendations from GitHub Documentation:**

1. **Length:** Keep under 2 pages - be concise but comprehensive
2. **Format:** Natural language in Markdown - whitespace between instructions is ignored
3. **Content Priority:**
   - High-level repository summary (what it does, languages, frameworks)
   - Build/test/validation commands with exact steps
   - Project layout and architecture
   - Common errors and workarounds
   - Environment setup requirements
4. **Structure Elements:** GitHub recommends using XML-style tags for organization:
   - `<Goals>` - What the instructions aim to achieve
   - `<Limitations>` - Constraints on instructions
   - `<BuildInstructions>` - How to build, test, run
   - `<ProjectLayout>` - Directory structure and key files
5. **Verification:** Document what works, what doesn't, and command sequences
6. **Agent Guidance:** Explicitly instruct to trust instructions and only search when information is incomplete

**This file follows these guidelines** with Project Brahmanda's specific needs.

---

**Remember:** This project is not just infrastructure - it's a philosophical exercise in building systems that can be released without attachment, while building practical skills for production environments. Every line of code, every decision, every document should reflect both learning and detachment principles.
