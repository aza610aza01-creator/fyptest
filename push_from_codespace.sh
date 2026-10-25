#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo " AI Gym Cloud v5.2 — Codespace Git Commit & Cloudflare Sync"
echo "=================================================================="

git add -A
git status -s
git commit -m "AI Gym Cloud v5.2: Add Codespace devcontainer + Cloudflare ./public static assets + 6-digit OTP" || echo "No new changes to commit."
git push origin HEAD
echo "Pushed to GitHub! Cloudflare Workers/Pages (/opt/buildhome) will now detect ./public and wrangler.toml."
