# AI Gym Cloud v5.2 — Cloudflare Pages Build (`HTML / CSS / JS`)

This bundle is pre-configured for **Cloudflare Pages** (Direct Upload, Wrangler CLI, or Git CI/CD).

## Included Files
- `index.html`: Main responsive web app shell with inline SVG iconography and WebRTC camera viewport.
- `styles.css`: Complete Dark/Light glassmorphic design token stylesheet (WCAG 2.2 AA/AAA).
- `app.js`: Supabase JS v2 client (`https://eprmvrtcpuydxhtzwfep.supabase.co`), 2-Step 6-Digit Email Verify Code (`{{ .Token }}`) authentication, real-time 17-keypoint SVG pose coach, workout set logger, and CSV exporter.
- `_headers`: Enables camera access (`Permissions-Policy: camera=(self)`) and security headers on Cloudflare Pages.
- `_redirects`: SPA routing rule (`/* /index.html 200`).
- `wrangler.toml` & `package.json`: Ready for `npx wrangler pages deploy . --project-name ai-gym-cloud`.
- `functions/api/config.js`: Cloudflare Pages Function returning runtime Supabase & Custom SMTP domain metadata at `/api/config`.

## 3 Ways to Deploy to Cloudflare Pages

### Option 1: Drag-and-Drop ZIP Upload (Fastest — Zero CLI needed)
1. Open the **Cloudflare Dashboard** → **Workers & Pages** → **Create** → **Pages** → **Upload assets**.
2. Name your project `ai-gym-cloud` and upload `ai_gym_cloudflare_pages_build.zip` (or the extracted folder).
3. Under **Custom Domains**, bind your build domain (e.g., `app.aigymcloud.build`) and add that URL to Supabase **Authentication → URL Configuration → Redirect URLs**.

### Option 2: Deploy via Wrangler CLI (PowerShell / Terminal)
```powershell
npx wrangler pages deploy . --project-name ai-gym-cloud
```

### Option 3: Cloudflare Pages Git Integration
- **Framework preset**: `None` (Static HTML/CSS/JS)
- **Build command**: *(leave empty)*
- **Build output directory**: `/` (or `.`)
