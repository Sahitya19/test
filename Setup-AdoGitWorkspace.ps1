<#
.SYNOPSIS
  Arranges the three Copilot kits (copilot-timeline, copilot-artifacts, copilot-migration) into one
  VS Code workspace at C:\repos\ADO-GIT so Copilot Chat finds the prompts and instructions.

.DESCRIPTION
  Only unzips and copies. Nothing is deleted or overwritten outside the workspace folder.
  Run it from a PowerShell or VS Code terminal:
    Set-ExecutionPolicy -Scope Process Bypass
    C:\repos\ADO-GIT\Setup-AdoGitWorkspace.ps1
#>
[CmdletBinding()]
param([string]$Workspace = 'C:\repos\ADO-GIT')

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Workspace)) { throw "Folder $Workspace not found. Create it and put the kit zips or folders in it." }
Set-Location $Workspace

function Copy-Tree($from, $to) {
  if (Test-Path $from) { robocopy $from $to /E /NJH /NJS /NFL /NDL | Out-Null }
}

# 1. Unzip any kit zips sitting in the folder
Get-ChildItem -Filter *.zip | ForEach-Object {
  Write-Host "Unzipping $($_.Name)"
  Expand-Archive $_.FullName -DestinationPath $Workspace -Force
}

# 2. Merge the kits into the workspace root
New-Item -ItemType Directory -Force .github\prompts, .github\instructions, .vscode | Out-Null
$kits = 'copilot-timeline', 'copilot-artifacts', 'copilot-migration'
foreach ($k in $kits) {
  if (-not (Test-Path $k)) { Write-Warning "$k not found in $Workspace (skipped)"; continue }
  Write-Host "Merging $k"
  Copy-Tree "$k\.github\prompts" '.github\prompts'
  Copy-Tree "$k\scripts" 'scripts'
  Copy-Tree "$k\docs" 'docs'
  if (Test-Path "$k\.vscode\mcp.json") { Copy-Item "$k\.vscode\mcp.json" .vscode -Force }
}
if (Test-Path copilot-migration) {
  Copy-Item copilot-migration\.github\copilot-instructions.md .github -Force
  Copy-Tree 'copilot-migration\.github\workflows' '.github\workflows'
  Copy-Tree 'copilot-migration\rulesets' 'rulesets'
  Copy-Tree 'copilot-migration\templates' 'templates'
  if (Test-Path copilot-migration\START-HERE.md) { Copy-Item copilot-migration\START-HERE.md . -Force }
}

# 3. The other two kits' rules become extra instruction files
foreach ($k in 'artifacts', 'timeline') {
  $src = "copilot-$k\.github\copilot-instructions.md"
  if (Test-Path $src) {
    "---`napplyTo: `"**`"`n---`n`n" + (Get-Content $src -Raw) | Set-Content ".github\instructions\$k.instructions.md" -Encoding UTF8
  }
}

# 4. Report
$prompts = @(Get-ChildItem .github\prompts -Filter *.prompt.md)
Write-Host ""
Write-Host "Prompts installed: $($prompts.Count)"
$prompts | ForEach-Object { '  /' + ($_.Name -replace '\.prompt\.md$', '') } | Write-Host
foreach ($p in '.github\copilot-instructions.md', '.github\instructions\artifacts.instructions.md', '.github\instructions\timeline.instructions.md', '.vscode\mcp.json', 'scripts', 'docs\migration\plan-12-week.md') {
  $ok = Test-Path $p
  Write-Host ("  {0,-50} {1}" -f $p, $(if ($ok) { 'OK' } else { 'MISSING' }))
}
if ((Get-Content .github\copilot-instructions.md -Raw) -match 'AnalyticsDataHub \(confirm\)') {
  Write-Warning "Edit .github\copilot-instructions.md: replace 'AnalyticsDataHub (confirm)' with your ADO organization name."
}
Write-Host ""
Write-Host "Next: in VS Code, Ctrl+Shift+P > Reload Window, open Copilot Chat in Agent mode, type / and check /plan-chart is listed."
