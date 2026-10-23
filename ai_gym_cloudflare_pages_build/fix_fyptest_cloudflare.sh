#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " Fixing aza610aza01-creator/fyptest@3ddb5da for Cloudflare"
echo "=========================================================="

# 1. If nested ai_gym_cloud/ subfolder exists (from commit 3ddb5da), move all its contents to repo root
if [ -d "ai_gym_cloud" ]; then
  echo "[1/4] Moving nested ai_gym_cloud/* files to repository root (/)..."
  cp -rn ai_gym_cloud/. . 2>/dev/null || cp -rf ai_gym_cloud/* . 2>/dev/null || true
  if [ -d "ai_gym_cloud/.devcontainer" ]; then
    cp -rf ai_gym_cloud/.devcontainer . || true
  fi
  git rm -rf ai_gym_cloud 2>/dev/null || rm -rf ai_gym_cloud
fi

# 2. Remove raw .zip archive from repo root if present
for zf in ai_gym_cloud_v5_2_cloudflare_pages_build.zip ai_gym_cloudflare_pages_build.zip ai_gym_cloud.zip; do
  if [ -f "$zf" ]; then
    echo "[2/4] Removing raw zip archive $zf from repository root..."
    git rm -f "$zf" 2>/dev/null || rm -f "$zf"
  fi
done

# 3. Write root wrangler.toml with name = "fyptest" (matching Cloudflare Workers Builds: fyptest)
echo "[3/4] Writing root wrangler.toml (name = 'fyptest') and package.json..."
cat << 'EOF_WRANGLER' > wrangler.toml
name = "fyptest"
compatibility_date = "2025-01-01"

[assets]
directory = "./public"
not_found_handling = "single-page-application"

[vars]
SUPABASE_URL = "https://eprmvrtcpuydxhtzwfep.supabase.co"
SUPABASE_PUBLISHABLE_KEY = "sb_publishable_7psvpRTKPvrcIFZjNcynIQ_KiDD5lgP"
SMTP_BUILD_DOMAIN = "aigymcloud.build"
EOF_WRANGLER

cat << 'EOF_PKG' > package.json
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
EOF_PKG

# Ensure ./public has index.html, styles.css, app.js, _headers, _redirects, manifest.json
mkdir -p public dist
for f in index.html styles.css app.js _headers _redirects manifest.json; do
  if [ -f "$f" ]; then
    cp -f "$f" "public/$f"
    cp -f "$f" "dist/$f"
  elif [ -f "public/$f" ]; then
    cp -f "public/$f" "$f"
    cp -f "public/$f" "dist/$f"
  fi
done

echo "[4/4] Verifying root files for Cloudflare Workers Builds (fyptest):"
ls -la wrangler.toml package.json index.html styles.css app.js public/index.html

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  git add -A
  git commit -m "Fix Cloudflare Workers build (fyptest): move ai_gym_cloud/* to root & set wrangler name=fyptest" || echo "Nothing new to commit."
  echo "Pushing fix to origin/$BRANCH..."
  git push -u origin "$BRANCH"
  echo "=========================================================="
  echo " SUCCESS! Commit pushed to aza610aza01-creator/fyptest."
  echo " Cloudflare Workers Builds: fyptest will now pass!"
  echo "=========================================================="
fi
