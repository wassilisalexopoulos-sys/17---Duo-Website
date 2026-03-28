<#
.SYNOPSIS
    Adds a second Git remote and pushes branch main to another GitHub repository.

.DESCRIPTION
    1. On GitHub, create a new empty repository (no README if you want a clean mirror of this history).
    2. Run (HTTPS example):
         .\push-to-other-repo.ps1 -RepositoryUrl "https://github.com/YOU/NEW-REPO.git"
       Or SSH:
         .\push-to-other-repo.ps1 -RepositoryUrl "git@github.com:YOU/NEW-REPO.git"

    Uses remote name "publish" by default. To change URL later:
         git remote set-url publish https://github.com/YOU/NEW-REPO.git

    Your existing origin is unchanged.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RepositoryUrl,

    [string] $RemoteName = "publish",

    [string] $Branch = "main"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path -LiteralPath ".git")) {
    Write-Error "Not a git repository. Run 'git init' in this folder first."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not on PATH."
}

$remotes = @(git remote)
if ($remotes -contains $RemoteName) {
    $current = (git remote get-url $RemoteName).Trim()
    if ($current -ne $RepositoryUrl.Trim()) {
        Write-Host "Updating remote '$RemoteName' URL..."
        git remote set-url $RemoteName $RepositoryUrl
    }
    else {
        Write-Host "Remote '$RemoteName' already points to that URL."
    }
}
else {
    Write-Host "Adding remote '$RemoteName' -> $RepositoryUrl"
    git remote add $RemoteName $RepositoryUrl
}

Write-Host "Pushing $Branch to $RemoteName..."
git push -u $RemoteName $Branch

Write-Host "Done." -ForegroundColor Green
