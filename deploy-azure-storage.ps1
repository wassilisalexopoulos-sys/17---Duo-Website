<#
.SYNOPSIS
    Deploys this static site to Azure Blob Storage static website hosting.

.DESCRIPTION
    Requires: Azure CLI (https://learn.microsoft.com/cli/azure/install-azure-cli-windows)
    Run once: az login
    First-time: .\deploy-azure-storage.ps1 -StorageAccountName "youruniquename" -ResourceGroup "rg-duo-web"

    Update existing site only (no new resources): use -SkipInfra, or run .\update-azure-storage.ps1

    Storage account name must be globally unique, 3-24 characters, lowercase letters and numbers only.

.EXAMPLE
    .\deploy-azure-storage.ps1 -StorageAccountName "duocoffeeevents001" -ResourceGroup "rg-duo-website" -Location "westeurope"

.EXAMPLE
    .\deploy-azure-storage.ps1 -StorageAccountName "duocoffeeevents001" -ResourceGroup "rg-duo-website" -SkipInfra
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string] $StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [string] $Location = "westeurope",

    [switch] $SkipInfra
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI ('az') not found. Install from https://learn.microsoft.com/cli/azure/install-azure-cli-windows then run 'az login'."
}

$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not logged in. Run: az login"
}

if (-not $SkipInfra) {
    Write-Host "Ensuring resource group '$ResourceGroup'..."
    az group create --name $ResourceGroup --location $Location | Out-Null

    $exists = az storage account show --name $StorageAccountName --resource-group $ResourceGroup 2>$null
    if (-not $exists) {
        Write-Host "Creating storage account '$StorageAccountName'..."
        az storage account create `
            --name $StorageAccountName `
            --resource-group $ResourceGroup `
            --location $Location `
            --sku Standard_LRS `
            --kind StorageV2 `
            --allow-blob-public-access true | Out-Null
    }

    Write-Host "Enabling static website (index.html, 404 -> index.html)..."
    az storage blob service-properties update `
        --account-name $StorageAccountName `
        --static-website `
        --index-document index.html `
        --404-document index.html | Out-Null
}

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("duo-web-deploy-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $staging -Force | Out-Null
try {
    Copy-Item -Path (Join-Path $root "*.html") -Destination $staging -Force
    Copy-Item -Path (Join-Path $root "*.css") -Destination $staging -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $root "*.js") -Destination $staging -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $root "*.svg") -Destination $staging -Force -ErrorAction SilentlyContinue
    $images = Join-Path $root "images"
    if (Test-Path $images) {
        Copy-Item -Path $images -Destination (Join-Path $staging "images") -Recurse -Force
    }

    Write-Host "Uploading site to '`$web' container..."
    az storage blob upload-batch `
        --account-name $StorageAccountName `
        --auth-mode login `
        --destination '$web' `
        --source $staging `
        --overwrite `
        --no-progress | Out-Null

    $url = az storage account show `
        --name $StorageAccountName `
        --resource-group $ResourceGroup `
        --query "primaryEndpoints.web" `
        --output tsv

    Write-Host ""
    Write-Host "Done. Your site URL:" -ForegroundColor Green
    Write-Host $url
}
finally {
    Remove-Item -Path $staging -Recurse -Force -ErrorAction SilentlyContinue
}
