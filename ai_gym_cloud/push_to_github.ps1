$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " AI Gym Cloud - Push Project to GitHub (fyptest.git)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$repoUrl = "https://github.com/aza610aza01-creator/fyptest.git"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root

try {
    if (-not (Test-Path (Join-Path $root ".git"))) {
        Write-Host "[1/5] Initializing local Git repository..." -ForegroundColor Yellow
        git init
    }

    Write-Host "[2/5] Setting branch to main..." -ForegroundColor Yellow
    git branch -M main

    $existingRemotes = git remote
    if ($existingRemotes -contains "origin") {
        Write-Host "[3/5] Updating remote origin to $repoUrl ..." -ForegroundColor Yellow
        git remote set-url origin $repoUrl
    } else {
        Write-Host "[3/5] Adding remote origin $repoUrl ..." -ForegroundColor Yellow
        git remote add origin $repoUrl
    }

    Write-Host "[4/5] Staging project files and creating commit..." -ForegroundColor Yellow
    git add .
    $status = git status --porcelain
    if ($status) {
        git commit -m "Initial commit: Complete AI Gym Cloud Flutter Android & Supabase project"
    } else {
        Write-Host "Working tree clean; commit already up to date." -ForegroundColor Green
    }

    Write-Host "[5/5] Pushing to $repoUrl (branch: main)..." -ForegroundColor Yellow
    git push -u origin main

    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " Successfully pushed AI Gym Cloud to $repoUrl !" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
finally {
    Pop-Location
}
