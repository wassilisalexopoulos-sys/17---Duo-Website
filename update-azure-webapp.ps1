<#
.SYNOPSIS
    Pushes the current site to an existing Azure Web App (zip deploy only).

.DESCRIPTION
    Requires Azure CLI and `az login`.

    Option A — copy azure-webapp.config.json.example to azure-webapp.config.json,
    set resourceGroup and webAppName, then:
        .\update-azure-webapp.ps1

    Option B:
        .\update-azure-webapp.ps1 -ResourceGroup "your-rg" -WebAppName "your-app"
#>
[CmdletBinding()]
param(
    [string] $ResourceGroup,
    [string] $WebAppName
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$configPath = Join-Path $root "azure-webapp.config.json"

if (-not $ResourceGroup -or -not $WebAppName) {
    if (Test-Path $configPath) {
        $cfg = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        if (-not $ResourceGroup) { $ResourceGroup = $cfg.resourceGroup }
        if (-not $WebAppName) { $WebAppName = $cfg.webAppName }
    }
}

if (-not $ResourceGroup -or -not $WebAppName) {
    Write-Error @"
Missing resource group or Web App name.

Create azure-webapp.config.json from azure-webapp.config.json.example, or run:

  .\update-azure-webapp.ps1 -ResourceGroup 'your-rg' -WebAppName 'your-app'

In Azure Portal: App Service -> Overview -> Resource group / Name.
"@
}

& (Join-Path $root "deploy-azure-webapp.ps1") `
    -ResourceGroup $ResourceGroup `
    -WebAppName $WebAppName `
    -SkipInfra
