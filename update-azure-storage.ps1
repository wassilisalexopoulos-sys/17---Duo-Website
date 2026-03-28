<#
.SYNOPSIS
    Uploads the current site files to an existing Azure Storage static website (no new resources).

.DESCRIPTION
    Same requirements as deploy-azure-storage.ps1: Azure CLI installed, `az login` done.

    Option A — save settings once: copy azure-site.config.json.example to azure-site.config.json
    and fill storageAccountName + resourceGroup, then run:
        .\update-azure-storage.ps1

    Option B — pass names each time:
        .\update-azure-storage.ps1 -StorageAccountName "yourstorage" -ResourceGroup "your-rg"

    If you used Azure Static Web Apps (GitHub) instead of Storage, redeploy from Git or use
    the SWA workflow in the Azure portal — this script is for Storage static websites only.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string] $StorageAccountName,

    [string] $ResourceGroup
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$configPath = Join-Path $root "azure-site.config.json"

if (-not $StorageAccountName -or -not $ResourceGroup) {
    if (Test-Path $configPath) {
        $cfg = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        if (-not $StorageAccountName) { $StorageAccountName = $cfg.storageAccountName }
        if (-not $ResourceGroup) { $ResourceGroup = $cfg.resourceGroup }
    }
}

if (-not $StorageAccountName -or -not $ResourceGroup) {
    Write-Error @"
Missing storage account or resource group.

Either create azure-site.config.json (see azure-site.config.json.example) or run:

  .\update-azure-storage.ps1 -StorageAccountName 'yourname' -ResourceGroup 'your-rg'

Find them in Azure Portal: Storage account -> Overview (name), and Resource group at the top.
"@
}

& (Join-Path $root "deploy-azure-storage.ps1") `
    -StorageAccountName $StorageAccountName `
    -ResourceGroup $ResourceGroup `
    -SkipInfra
