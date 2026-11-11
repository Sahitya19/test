# Copilot kit: ADO to GitHub migration, end to end

Companion to the guide "ADO to GitHub: 12-week migration guide". Each step in the guide names a `/prompt` from this kit. Copilot (VS Code, Agent mode, on the VDI) runs read-only scripts, reads their CSV output and writes plans, commands and drafts under `docs/`. You review and run anything that changes ADO, GitHub or Azure.

## Setup (30 minutes)

1. Create a repo such as `ADHPlatform/migration-hub` and copy in this folder plus `copilot-timeline` and `copilot-artifacts`. Merge the three `copilot-instructions.md` files into one (or keep this one as `.github/copilot-instructions.md` and move the others to `.github/instructions/<name>.instructions.md`).
2. VS Code: set `github-enterprise.uri` to `https://cencora.ghe.com`, sign in, open Copilot Chat in **Agent** mode, start the servers in `.vscode/mcp.json`.
3. Tools: `gh auth login --hostname cencora.ghe.com`, `gh extension install github/gh-ado2gh`, `gh extension install github/gh-actions-importer`, `az login`. Optional: `git filter-repo` (module split), `gitleaks` (history scan); both need VDI approval.
4. Tokens in the terminal only: `$env:ADO_PAT`, `$env:GH_PAT`. ADO PAT scopes, all Read: Code, Build, Release, Service Connections, Variable Groups, Secure Files, Environment, Agent Pools, Task Groups, Packaging, Project and Team, Graph, Identity (Audit Log for the history export).
5. If PowerShell blocks scripts: `Set-ExecutionPolicy -Scope Process Bypass`.

## Prompts by step

| Step | Prompt | Writes |
|---|---|---|
| 1 Inventory | `/inventory-all`, `/plan-waves` | `docs/inventory/<date>-inventory.md`, `docs/migration/waves.md` |
| 2 Runners | `/runner-tools` | `docs/migration/runner-tools.md`, Dockerfile diff |
| 3 OIDC | `/oidc-plan` | `docs/security/oidc-plan.md`, `scripts/migration/oidc-<wave>.ps1` |
| 4 Library | `/library-plan` | `docs/security/library-plan.md`, `scripts/migration/set-variables-<wave>.ps1` |
| 5 Permissions | `/permissions-plan` | `docs/security/permissions-plan.md`, CODEOWNERS files |
| 6 Repos | `/repo-verify` | log rows |
| 7 Modules | `/module-split`, `/module-tags` | `docs/modules/module-plan.md`, tag commands |
| 8 Artifacts | Artifacts kit: `/artifacts-inventory`, `/artifacts-plan`, `/package-migrate` | `docs/artifacts/` |
| 9 Pipelines | `/pipeline-patterns`, `/pipeline-convert` | `docs/migration/pipeline-patterns.md`, `workflows-draft/` |
| 10 Security | `/scan-history`, `/security-report` | `docs/security/` |
| 11 Logs | `/migration-log` | `docs/migration/log.md` |
| 12 Cutover | `/cutover-check` | `docs/migration/cutover-<wave>.md` |
| Every week | `/weekly-update`, `/migration-timeline` | `docs/migration/status/` |

## Files

| Path | What |
|---|---|
| `scripts/Get-AdoMigrationInventory.ps1` | Service connections (+ usage), variable groups (names; plain values only with `-IncludePlainValues`), secure files, environments and checks, branch policies, security groups and members, build and release definitions (with task sequence per stage), task groups, agent pools and tools |
| `scripts/Get-ServiceConnectionRoles.ps1` | Azure roles and secret expiry for each Azure service connection's principal (`az`) |
| `scripts/Invoke-HistoryScan.ps1` | gitleaks over each clone, redacted reports |
| `scripts/Export-AdoHistory.ps1` | Build runs, release deployments with approvers, ADO audit log, for keeping after decommission |
| `scripts/AdoCommon.ps1` | Shared auth, retry and paging |
| `rulesets/` | Org ruleset for `main`, immutable `v*` tags for modules |
| `templates/module-repo/` | Module repo template: CI (fmt, validate, tflint, checkov, PR title), release-please, CODEOWNERS, README, Dependabot for consumers |
| `.github/workflows/actions-importer-audit.yml` | Runs Actions Importer audit and forecast on a GitHub-hosted runner when the VDI has no Docker |

All scripts are read-only, work on Windows PowerShell 5.1 and PowerShell 7, log failed calls to `errors.csv` and carry on. They were written against the Azure DevOps REST API 7.1 docs and have not been run against your org yet; if a call fails, ask Copilot to read `errors.csv` and fix the script.

## Runner kit change

`github-runner-aca` now supports `RUNNER_SCOPE=repo` with `GITHUB_REPO=<repo>` and a classic PAT from a repo admin, so the pilot is not blocked on org rights. See the "Repo-level runners" section of its README.
