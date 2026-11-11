# Azure Artifacts to GitHub: migration options and recommendation

Copilot uses this file as the decision rules when it writes the migration plan. Edit it when the team decides something; Copilot never edits it.

- Source: Azure DevOps org `AnalyticsDataHub` (confirm), 5 feeds at the 28 Oct 2026 assessment
- Target: `cencora.ghe.com`, org `ADHPlatform`; Terraform modules in `ADHPlatform-Modules` (proposed)

## What GitHub offers on cencora.ghe.com

GitHub has no single product that matches Azure Artifacts. On GHE.com (data residency) specifically:

| Package type | GitHub Packages on cencora.ghe.com? | Registry URL |
|---|---|---|
| NuGet | Yes | `https://nuget.cencora.ghe.com/ADHPlatform/index.json` |
| npm | Yes, **scoped packages only** (`@adhplatform/<name>`) | `https://npm.cencora.ghe.com` |
| Containers / OCI (Docker, Helm, any OCI artifact) | Yes | `containers.cencora.ghe.com` |
| Maven / Gradle | **No, currently unavailable on GHE.com** | n/a |
| PyPI (Python) | No (not a GitHub Packages registry anywhere) | n/a |
| Universal Packages | No equivalent | n/a |
| Upstream proxy / cache of nuget.org, npmjs, PyPI | No | n/a |

Other facts that shape the plan:
- Outside Actions, GitHub Packages accepts only a **classic PAT** (`read:packages`, `write:packages`). Fine-grained PATs do not work. Inside Actions use `GITHUB_TOKEN` with `permissions: packages: read|write`, and grant the consuming repo access in the package's settings.
- A published version is immutable. You cannot overwrite it, only delete it and publish a new one.
- npm packages must carry the org scope. An unscoped `my-lib` or a `@cencora/my-lib` becomes `@adhplatform/my-lib`, which is a breaking rename for every consumer (mitigation: npm alias, see below).
- Enterprise Managed Users can publish only to an org namespace, not a personal one.

## The options

| # | Option | Good for | Watch out for |
|---|---|---|---|
| A | **GitHub Packages** (org `ADHPlatform`) | NuGet, npm, container images | No Maven/PyPI/Universal on GHE.com; classic PAT for local dev; npm rename |
| B | **Git tags + per-module semver** (`v1.4.2`), optionally a GitHub Release with changelog | Terraform modules, pipeline templates, scripts, config bundles: anything that is really source code | Only works if consumers can pull from git (`?ref=v1.4.2`). Needs a tag policy and release-please (or similar) so versions stay consistent |
| C | **GitHub Release assets** attached to a tag | Built binaries, zips, installers, Universal packages up to 2 GiB per file | Not a package manager: no dependency resolution, consumers download by URL |
| D | **OCI artifacts in the Container registry** (`oras push`) | Universal packages, large binaries, Helm charts, anything versioned that is not source | Consumers need `oras` or `helm`; less familiar to teams |
| E | **Keep Azure Artifacts** (consumed from GitHub Actions through OIDC, no PAT) | Maven, PyPI, upstream caching of public registries, a bridge during the waves | Keeps part of the ADO org alive and billed after decommission; two systems to govern |
| F | **Third-party registry** (JFrog Artifactory, Sonatype Nexus, Cloudsmith) | One registry for every format, proxy caching, retention and security scanning | Licence cost, procurement, another platform to run |
| G | **Actions artifacts** (`actions/upload-artifact`) | Pipeline build outputs passed between jobs or kept for a short time | Retention is days, not years. Not a place for anything that must be kept |

## Recommendation (hybrid, by package type)

| What the inventory finds | Target | Option |
|---|---|---|
| Internal NuGet packages | GitHub Packages, `ADHPlatform` | A |
| Internal npm packages | GitHub Packages as `@adhplatform/<name>` | A |
| Container images (if any are in feeds or ACR-adjacent) | `containers.cencora.ghe.com/adhplatform/<name>` | A |
| Terraform modules (as Universal packages, or consumed from ADO git) | One repo per module in `ADHPlatform-Modules`, semver git tags, release-please, changelog | B |
| Universal packages that are source (scripts, templates, config) | Git tags in the owning repo, plus a Release | B |
| Universal packages that are binaries | Release assets (under 2 GiB) or OCI artifact | C or D |
| Maven / Gradle | Keep Azure Artifacts for now, consumed via OIDC; decide JFrog vs keep before Decommission | E then F |
| PyPI | Same as Maven | E then F |
| Packages cached from upstream (nuget.org, npmjs.com, PyPI) | **Do not migrate.** Point consumers at the public registry, or keep the feed as a proxy if the build agents have no internet | none / E |
| Pipeline build artifacts | Do not migrate history. New builds use Actions artifacts for hand-offs and Releases for anything kept. Archive builds with `keepForever` or retained by a release to blob storage if audit needs them | G + C |

Why hybrid: it puts most packages next to the code with no new licence, reuses the module-org design already proposed, and avoids forcing Maven or Python onto a registry GHE.com does not offer. If the inventory shows a large Maven or PyPI footprint, option F becomes the better single answer and should go to management as a decision.

## Which versions to move

Do not copy every version by default. Move a version if any of these is true:
1. It is the latest version of each major line (for example latest 1.x, latest 2.x).
2. A consumer found by `Find-FeedConsumers.ps1` pins it, or a lock file references it.
3. It was downloaded in the last 90 days (needs `-IncludeMetrics`).
4. It is in the `@Release` view.

Everything else: export to an archive storage account (cheap, kept for audit) and do not republish. Record the cut in the plan.

## Per-module versioning and git tags (option B detail)

- **Repo per module** (current proposal): `ADHPlatform-Modules/terraform-azurerm-<module>`, tags `v<major>.<minor>.<patch>`, consumers use `source = "git::https://cencora.ghe.com/ADHPlatform-Modules/terraform-azurerm-keyvault.git?ref=v1.4.2"`.
- **Monorepo alternative**: one repo, tags `<module>/v1.4.2`, consumers use `//modules/<module>?ref=<module>/v1.4.2`. release-please manifest mode supports this. Fewer repos, but every module shares one permission set and one CI.
- **Backfilling tags from existing package versions**: for each published version, use its provenance (the pipeline run that published it) to find the commit, then create tag `v<version>` on that commit. Where provenance is missing, tag the commit closest to the publish date and mark it "approximate" in the plan. Never invent a version number that was not published.
- From then on, versions come from Conventional Commits and release-please, not hand-typed.

## Moving consumers

| Consumer | Change |
|---|---|
| `nuget.config` | Replace the `pkgs.dev.azure.com/.../nuget/v3/index.json` source with `https://nuget.cencora.ghe.com/ADHPlatform/index.json`; keep nuget.org as its own source; add `packageSourceMapping` so internal IDs only come from GitHub |
| `.npmrc` | `@adhplatform:registry=https://npm.cencora.ghe.com` and `//npm.cencora.ghe.com/:_authToken=${NODE_AUTH_TOKEN}`. Keep old import names working with an alias: `"my-lib": "npm:@adhplatform/my-lib@^2.0.0"` |
| ADO tasks `NuGetAuthenticate@`, `npmAuthenticate@` | In GitHub Actions: `actions/setup-dotnet` / `actions/setup-node` with `GITHUB_TOKEN`, `permissions: packages: read` |
| `UniversalPackages@` download | `gh release download`, `oras pull`, or a git `?ref=` source |
| Feeds kept in Azure Artifacts (option E) | `azure/login` with OIDC, then `az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798` and pass the token to the package tool |

## Bridge during the waves

While some pipelines still run in ADO, publish new versions to **both** places from the GitHub workflow (GitHub Packages or tag, plus the old Azure Artifacts feed), so ADO consumers keep working. Remove the second publish when the last ADO consumer of that package has moved. The consumer scan tells you when that is.

## Decisions to take to management

1. Hybrid (recommended) vs one third-party registry for everything.
2. What happens to Maven and PyPI feeds at ADO decommission (keep a small ADO org for Artifacts, or buy JFrog/Nexus).
3. Version cut policy (above) and how long archived versions are kept.
4. Who owns package permissions in GitHub (package admins per org).
