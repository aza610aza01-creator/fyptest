#!/usr/bin/env bash
set -euo pipefail

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
echo "Staging AI Gym Cloud v5.2 (Codespaces + Cloudflare Pages + Supabase OTP)..."
git add -A
git commit -m "Deploy AI Gym Cloud v5.2 (Codespaces + Cloudflare Pages + Pure SVG + 6-Digit OTP)" || echo "No new changes to commit."
git push -u origin "$BRANCH"
echo "Pushed to origin/$BRANCH!"
