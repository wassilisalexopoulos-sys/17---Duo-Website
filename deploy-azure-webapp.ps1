<#
.SYNOPSIS
    Deploys this static site to Azure App Service (Web App) via zip deploy.

.DESCRIPTION
    Requires: Azure CLI — https://learn.microsoft.com/cli/azure/install-azure-cli-windows
    Run: az login

    Update an existing Web App (typical after first setup in the portal):
        .\deploy-azure-webapp.ps1 -ResourceGroup "your-rg" -WebAppName "your-app" -SkipInfra

    First-time from CLI (creates Linux plan + app if missing; PHP runtime is fine for static files):
        .\deploy-azure-webapp.ps1 -ResourceGroup "your-rg" -WebAppName "your-app" `
            -AppServicePlan "your-plan" -Location "westeurope"

    WebAppName is the app name (the part before .azurewebsites.net).
#>
[CmdletBinding(DefaultParameterSetName = "Update")]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $WebAppName,

    [Parameter(ParameterSetName = "Update", Mandatory = $true)]
    [switch] $SkipInfra,

    [Parameter(ParameterSetName = "Create", Mandatory = $true)]
    [string] $AppServicePlan,

    [Parameter(ParameterSetName = "Create")]
    [string] $Location = "westeurope",

    [Parameter(ParameterSetName = "Create")]
    [string] $Sku = "B1",

    [Parameter(ParameterSetName = "Create")]
    [string] $Runtime = "PHP|8.2"
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

function Copy-WebsiteFilesToStaging {
    param([string] $StagingPath)
    Copy-Item -Path (Join-Path $root "*.html") -Destination $StagingPath -Force
    Copy-Item -Path (Join-Path $root "*.css") -Destination $StagingPath -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $root "*.js") -Destination $StagingPath -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $root "*.svg") -Destination $StagingPath -Force -ErrorAction SilentlyContinue
    $images = Join-Path $root "images"
    if (Test-Path $images) {
        Copy-Item -Path $images -Destination (Join-Path $StagingPath "images") -Recurse -Force
    }
}

function New-SiteZipWithForwardSlashes {
    param(
        [string] $SourceDir,
        [string] $ZipPath
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $ZipPath) {
        Remove-Item -Path $ZipPath -Force
    }
    $sourceFull = (Resolve-Path -LiteralPath $SourceDir).Path
    if (-not $sourceFull.EndsWith([char][IO.Path]::DirectorySeparatorChar)) {
        $sourceFull += [IO.Path]::DirectorySeparatorChar
    }
    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($sourceFull.Length)
            $entryName = $rel.Replace('\', '/')
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entryName)
        }
    }
    finally {
        $zip.Dispose()
    }
}

if ($PSCmdlet.ParameterSetName -eq "Create") {
    Write-Host "Ensuring resource group '$ResourceGroup'..."
    az group create --name $ResourceGroup --location $Location | Out-Null

    $planMissing = -not (az appservice plan show --name $AppServicePlan --resource-group $ResourceGroup 2>$null)
    if ($planMissing) {
        Write-Host "Creating App Service plan '$AppServicePlan' ($Sku, Linux)..."
        az appservice plan create `
            --name $AppServicePlan `
            --resource-group $ResourceGroup `
            --location $Location `
            --sku $Sku `
            --is-linux | Out-Null
    }

    $appMissing = -not (az webapp show --name $WebAppName --resource-group $ResourceGroup 2>$null)
    if ($appMissing) {
        Write-Host "Creating Web App '$WebAppName' (runtime $Runtime)..."
        az webapp create `
            --resource-group $ResourceGroup `
            --plan $AppServicePlan `
            --name $WebAppName `
            --runtime $Runtime | Out-Null
    }
}

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("duo-webapp-" + [Guid]::NewGuid().ToString("N"))
$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) ("duo-webapp-" + [Guid]::NewGuid().ToString("N") + ".zip")
New-Item -ItemType Directory -Path $staging -Force | Out-Null
try {
    Copy-WebsiteFilesToStaging -StagingPath $staging
    Write-Host "Creating package..."
    New-SiteZipWithForwardSlashes -SourceDir $staging -ZipPath $zipPath

    Write-Host "Deploying to Web App '$WebAppName'..."
    az webapp deployment source config-zip `
        --resource-group $ResourceGroup `
        --name $WebAppName `
        --src $zipPath | Out-Null

    $hostName = az webapp show --name $WebAppName --resource-group $ResourceGroup --query defaultHostName -o tsv
    Write-Host ""
    Write-Host "Done. Site URL:" -ForegroundColor Green
    Write-Host ("https://" + $hostName)
}
finally {
    Remove-Item -Path $staging -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
}
