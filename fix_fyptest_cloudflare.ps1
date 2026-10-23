$ErrorActionPreference = "Stop"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Fixing aza610aza01-creator/fyptest@3ddb5da for Cloudflare" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (Test-Path ".\ai_gym_cloud") {
    Write-Host "[1/4] Moving nested ai_gym_cloud/* files to repository root..." -ForegroundColor Yellow
    Copy-Item -Path ".\ai_gym_cloud\*" -Destination "." -Recurse -Force
    git rm -rf ai_gym_cloud 2>$null
    if (Test-Path ".\ai_gym_cloud") { Remove-Item -Path ".\ai_gym_cloud" -Recurse -Force }
}

foreach ($zf in @("ai_gym_cloud_v5_2_cloudflare_pages_build.zip", "ai_gym_cloudflare_pages_build.zip", "ai_gym_cloud.zip")) {
    if (Test-Path $zf) {
        Write-Host "[2/4] Removing raw zip archive $zf from repository root..." -ForegroundColor Yellow
        git rm -f $zf 2>$null
        if (Test-Path $zf) { Remove-Item -Path $zf -Force }
    }
}

Write-Host "[3/4] Writing root wrangler.toml (name = 'fyptest') and package.json..." -ForegroundColor Yellow
$wrangler = @"
name = "fyptest"
compatibility_date = "2025-01-01"

[assets]
directory = "./public"
not_found_handling = "single-page-application"

[vars]
SUPABASE_URL = "https://eprmvrtcpuydxhtzwfep.supabase.co"
SUPABASE_PUBLISHABLE_KEY = "sb_publishable_7psvpRTKPvrcIFZjNcynIQ_KiDD5lgP"
SMTP_BUILD_DOMAIN = "aigymcloud.build"
"@
[System.IO.File]::WriteAllText((Join-Path $PWD "wrangler.toml"), $wrangler, (New-Object System.Text.UTF8Encoding($false)))

$pkg = @"
{
  "name": "fyptest",
  "version": "5.2.0",
  "private": true,
  "description": "AI Gym Cloud v5.2 — Pure SVG Web App & Supabase 6-Digit OTP Build for Cloudflare Workers & Pages (fyptest)",
  "scripts": {
    "build": "echo \"Static HTML/CSS/JS assets ready in ./public and ./\"",
    "dev": "npx wrangler dev --assets=./public",
    "deploy": "npx wrangler deploy",
    "pages:deploy": "npx wrangler pages deploy ./public --project-name=fyptest"
  }
}
"@
[System.IO.File]::WriteAllText((Join-Path $PWD "package.json"), $pkg, (New-Object System.Text.UTF8Encoding($false)))

New-Item -ItemType Directory -Force -Path ".\public", ".\dist" | Out-Null
foreach ($f in @("index.html", "styles.css", "app.js", "_headers", "_redirects", "manifest.json")) {
    if (Test-Path ".\$f") {
        Copy-Item ".\$f" ".\public\$f" -Force
        Copy-Item ".\$f" ".\dist\$f" -Force
    } elseif (Test-Path ".\public\$f") {
        Copy-Item ".\public\$f" ".\$f" -Force
        Copy-Item ".\public\$f" ".\dist\$f" -Force
    }
}

Write-Host "[4/4] Staging, committing, and pushing to GitHub..." -ForegroundColor Green
git add -A
git commit -m "Fix Cloudflare Workers build (fyptest): move ai_gym_cloud/* to root & set wrangler name=fyptest"
git push -u origin main
Write-Host "Done! Cloudflare Workers Builds: fyptest will now succeed." -ForegroundColor Green
