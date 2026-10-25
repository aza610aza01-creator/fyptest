#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-your-project-ref}"
SMTP_HOST="${SMTP_HOST:-smtp.resend.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-resend}"
SMTP_ADMIN_EMAIL="${SMTP_ADMIN_EMAIL:-auth@aigymcloud.build}"
SMTP_SENDER_NAME="${SMTP_SENDER_NAME:-AI Gym Cloud Security}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "[INFO] Export SUPABASE_ACCESS_TOKEN='sbp_...' from https://supabase.com/dashboard/account/tokens and SMTP_PASS='...' then re-run this script to PATCH https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth"
  exit 0
fi

curl -sS -X PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"external_email_enabled\": true,
    \"mailer_autoconfirm\": false,
    \"mailer_otp_length\": 6,
    \"mailer_otp_exp\": 3600,
    \"smtp_admin_email\": \"${SMTP_ADMIN_EMAIL}\",
    \"smtp_host\": \"${SMTP_HOST}\",
    \"smtp_port\": ${SMTP_PORT},
    \"smtp_user\": \"${SMTP_USER}\",
    \"smtp_pass\": \"${SMTP_PASS:-}\",
    \"smtp_sender_name\": \"${SMTP_SENDER_NAME}\",
    \"mailer_subjects_confirmation\": \"Your AI Gym Cloud 6-Digit Verification Code: {{ .Token }}\",
    \"mailer_subjects_magic_link\": \"Your AI Gym Cloud 6-Digit Login Code: {{ .Token }}\",
    \"mailer_templates_confirmation_content\": \"<h2>AI Gym Cloud Verification Code</h2><p>Your 6-digit code is: <strong style='font-size:28px;letter-spacing:6px;'>{{ .Token }}</strong></p>\",
    \"mailer_templates_magic_link_content\": \"<h2>AI Gym Cloud Login Code</h2><p>Your 6-digit login code is: <strong style='font-size:28px;letter-spacing:6px;'>{{ .Token }}</strong></p>\"
  }"
echo "Updated Supabase Auth Custom SMTP and 6-Digit OTP templates for ${PROJECT_REF}."
