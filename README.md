# Copilot kit: evaluate and migrate Azure Artifacts

Lets GitHub Copilot (agent mode in VS Code on the VDI) inventory your Azure Artifacts feeds, find every repo and pipeline that uses them, and write a migration plan to GitHub on `cencora.ghe.com`. It sits next to the timeline kit (`copilot-timeline`) and uses the same MCP setup.

## How it works

Copilot cannot read Azure Artifacts directly (the ADO MCP server has no packages tools), so the kit gives it two read-only PowerShell scripts to run in the VS Code terminal. Copilot then reads the CSV output, applies the rules in `docs/artifacts/migration-options.md`, and writes the reports.

```
/artifacts-inventory  → runs the scripts, writes docs/artifacts/inventory/<date>-inventory.md
/artifacts-plan       → writes docs/artifacts/migration-plan.md (target per package, consumer changes, timeline, decisions)
/package-migrate      → for one package: dry-run script + consumer diffs
```

## Files

| File | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Standing rules: data sources, GHE.com package facts, read-only and token safety, how to classify packages |
| `.github/prompts/artifacts-inventory.prompt.md` | `/artifacts-inventory` |
| `.github/prompts/artifacts-plan.prompt.md` | `/artifacts-plan` |
| `.github/prompts/package-migrate.prompt.md` | `/package-migrate` |
| `scripts/Get-AdoArtifactsInventory.ps1` | Feeds, upstreams, views, permissions, retention, packages, versions; optional download metrics, provenance and build artifacts |
| `scripts/Find-FeedConsumers.ps1` | Scans local clones for feed URLs, auth tasks, Universal Package and pipeline artifact tasks, Terraform git sources |
| `docs/artifacts/migration-options.md` | Options A to G, the recommendation, version cut policy, consumer changes. **The team edits this; Copilot follows it** |
| `docs/artifacts/inventory-template.md` | Layout of the inventory report |
| `.vscode/mcp.json` | Same ADO and GitHub MCP servers as the timeline kit |

## Setup (about 15 minutes)

1. Copy this folder into the same repo as the timeline kit (for example `ADHPlatform/Platform` or a `migration-reporting` repo). The two `.github/prompts` folders merge; merge the two `copilot-instructions.md` files into one, or move this one to `.github/instructions/artifacts.instructions.md` with `applyTo: "docs/artifacts/**,scripts/**"` at the top.
2. Confirm the ADO org name in `.github/copilot-instructions.md` and `docs/artifacts/migration-options.md`.
3. Create an ADO PAT with **Packaging (Read)**, **Build (Read)** and **Project and Team (Read)**. In the VS Code terminal: `$env:ADO_PAT = "<pat>"` (or use `az login` and let Copilot pass `-UseAzCli`). Never paste it into chat.
4. Clone the ADO repos into one folder, for example `C:\src\ado`, for the consumer scan.
5. If PowerShell blocks the scripts: `Set-ExecutionPolicy -Scope Process Bypass`.
6. In Copilot Chat, switch to **Agent** and type `/artifacts-inventory`.

The scripts were written against the Azure DevOps REST API 7.1 docs but have not been run against your org yet. If a call fails, it is logged in `errors.csv` and the run continues; ask Copilot to read the error and fix the script.

## The recommendation in one paragraph

GitHub has no Azure Artifacts equivalent, and on GHE.com GitHub Packages covers NuGet, npm and containers only (Maven/Gradle are unavailable there, PyPI and Universal Packages do not exist). So the plan is hybrid: NuGet and npm go to GitHub Packages in `ADHPlatform`, Terraform modules become one repo per module in `ADHPlatform-Modules` with semver git tags and release-please, other Universal packages become git tags, release assets or OCI artifacts depending on what they contain, packages cached from nuget.org/npmjs are not migrated, and Maven/PyPI stay in Azure Artifacts (read from Actions through OIDC) until the team decides between a small leftover ADO org and JFrog/Nexus. Only latest-per-major, pinned, recently downloaded and `@Release` versions move; the rest is archived. Details in `docs/artifacts/migration-options.md`.

## Quick one-off prompts (no setup files needed)

**Which feeds matter**
> Read docs/artifacts/inventory/raw/feeds.csv and packages.csv. Which feeds hold internal packages (not upstream cache), by type? Which have had no publish in 12 months? Give a table and three sentences.

**Who breaks if a feed goes away**
> Using consumers.csv, list every repo and file that would break if feed `<name>` were switched off today, grouped by repo, with the change each needs for GitHub.

**npm rename check**
> For every npm package in packages.csv, show its current name, its `@adhplatform/` name, and whether any two packages collide after renaming.

**Module tag backfill preview**
> For Universal package `<name>` in feed `<feed>`, using versions.csv provenance, list each version with the commit it was built from and the `git tag` command to create. Mark versions with no provenance. Do not run anything.

## Sources
- GHE.com feature overview (Maven/Gradle unavailable, Container registry at `containers.SUBDOMAIN.ghe.com`): https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/feature-overview-for-github-enterprise-cloud-with-data-residency
- NuGet registry (GHE.com URL, classic PAT only, optional repo link): https://docs.github.com/en/enterprise-cloud@latest/packages/working-with-a-github-packages-registry/working-with-the-nuget-registry
- npm registry (GHE.com URL, scoped packages only): https://docs.github.com/en/enterprise-cloud@latest/packages/working-with-a-github-packages-registry/working-with-the-npm-registry
- Azure Artifacts REST API (feeds, packages, provenance, metrics): https://learn.microsoft.com/en-us/rest/api/azure/devops/artifacts/
