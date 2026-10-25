# ==============================================================================
# AI Gym Cloud v5.2 — Configure Supabase Custom Domain SMTP & 6-Digit Verify Code
# Project Ref: your-project-ref
# Usage (PowerShell):
#   $env:SUPABASE_ACCESS_TOKEN="sbp_..."          # Personal Access Token from https://supabase.com/dashboard/account/tokens
#   $env:SMTP_HOST="smtp.resend.com"              # Or smtp.sendgrid.net / email-smtp.ap-east-1.amazonaws.com / smtp.brevo.com
#   $env:SMTP_PORT="587"
#   $env:SMTP_USER="resend"
#   $env:SMTP_PASS="re_xxxxxxxxx"                 # Your SMTP password / API key
#   $env:SMTP_ADMIN_EMAIL="auth@yourdomain.com"   # Verified sender address on your build domain
#   .\supabase\configure_custom_smtp_and_otp.ps1
# ==============================================================================
$ErrorActionPreference = "Stop"

$ProjectRef = if ($env:SUPABASE_PROJECT_REF) { $env:SUPABASE_PROJECT_REF } else { "your-project-ref" }
$AccessToken = $env:SUPABASE_ACCESS_TOKEN
$SmtpHost = if ($env:SMTP_HOST) { $env:SMTP_HOST } else { "smtp.resend.com" }
$SmtpPort = if ($env:SMTP_PORT) { [int]$env:SMTP_PORT } else { 587 }
$SmtpUser = if ($env:SMTP_USER) { $env:SMTP_USER } else { "resend" }
$SmtpPass = $env:SMTP_PASS
$SmtpAdminEmail = if ($env:SMTP_ADMIN_EMAIL) { $env:SMTP_ADMIN_EMAIL } else { "auth@aigymcloud.build" }
$SmtpSenderName = if ($env:SMTP_SENDER_NAME) { $env:SMTP_SENDER_NAME } else { "AI Gym Cloud Security" }

$OtpTemplateHtml = @"
<div style="background:#070B10;color:#F5F7FA;padding:28px;border-radius:18px;font-family:sans-serif;max-width:480px;margin:0 auto;border:1px solid #283246;">
  <h2 style="color:#9ED756;margin-top:0;">AI Gym Cloud Verification Code</h2>
  <p style="color:#98A4B8;font-size:14px;">Enter this 6-digit verification code in the AI Gym Cloud app to verify <strong>{{ .Email }}</strong>:</p>
  <div style="background:#121721;border:2px solid #9ED756;border-radius:12px;padding:16px 24px;font-size:32px;font-weight:800;letter-spacing:8px;text-align:center;color:#9ED756;font-family:monospace;margin:20px 0;">
    {{ .Token }}
  </div>
  <p style="color:#8492A8;font-size:12px;">Code valid for 60 minutes. Or <a href="{{ .ConfirmationURL }}" style="color:#5CE1E6;">click here to verify via link</a>.</p>
</div>
"@

$PayloadObj = @{
  external_email_enabled = $true
  mailer_autoconfirm = $false
  mailer_otp_length = 6
  mailer_otp_exp = 3600
  mailer_subjects_confirmation = "Your AI Gym Cloud 6-Digit Verification Code: {{ .Token }}"
  mailer_templates_confirmation_content = $OtpTemplateHtml
  mailer_subjects_magic_link = "Your AI Gym Cloud 6-Digit Login Code: {{ .Token }}"
  mailer_templates_magic_link_content = $OtpTemplateHtml
  mailer_subjects_recovery = "Your AI Gym Cloud 6-Digit Recovery Code: {{ .Token }}"
  mailer_templates_recovery_content = $OtpTemplateHtml
}

if ($SmtpPass) {
  $PayloadObj["smtp_admin_email"] = $SmtpAdminEmail
  $PayloadObj["smtp_host"] = $SmtpHost
  $PayloadObj["smtp_port"] = $SmtpPort
  $PayloadObj["smtp_user"] = $SmtpUser
  $PayloadObj["smtp_pass"] = $SmtpPass
  $PayloadObj["smtp_sender_name"] = $SmtpSenderName
  $PayloadObj["smtp_max_frequency"] = 1
}

$JsonBody = $PayloadObj | ConvertTo-Json -Depth 5

if (-not $AccessToken) {
  Write-Host "==============================================================================" -ForegroundColor Yellow
  Write-Host " [INFO] SUPABASE_ACCESS_TOKEN (sbp_...) not set in environment." -ForegroundColor Yellow
  Write-Host " Note: Project keys (sb_publishable_... / sb_secret_...) authenticate against" -ForegroundColor Gray
  Write-Host "       your-project-ref.supabase.co, whereas Management API Auth/SMTP" -ForegroundColor Gray
  Write-Host "       updates require a Personal Access Token (sbp_...) from:" -ForegroundColor Gray
  Write-Host "       https://supabase.com/dashboard/account/tokens" -ForegroundColor Cyan
  Write-Host "==============================================================================" -ForegroundColor Yellow
  Write-Host "Generated JSON payload ready for PATCH https://api.supabase.com/v1/projects/$ProjectRef/config/auth :"
  Write-Host $JsonBody
  exit 0
}

$Uri = "https://api.supabase.com/v1/projects/$ProjectRef/config/auth"
$Headers = @{
  "Authorization" = "Bearer $AccessToken"
  "Content-Type"  = "application/json"
}

Write-Host "Applying Custom SMTP ($SmtpHost`:$SmtpPort, sender: $SmtpAdminEmail) + 6-Digit {{ .Token }} OTP templates to project $ProjectRef..." -ForegroundColor Cyan
$Response = Invoke-RestMethod -Method Patch -Uri $Uri -Headers $Headers -Body $JsonBody
Write-Host "[SUCCESS] Supabase Custom SMTP and 6-Digit OTP Verification Code templates are now active!" -ForegroundColor Green
