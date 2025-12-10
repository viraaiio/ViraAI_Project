# Accounts & Services — ViraAI (Phase 0)

> این سند فهرست رسمی حساب‌ها و سرویس‌های مورد نیاز برای پروژه‌ی ViraAI (viraai.io) در فاز 0 را ثبت می‌کند.
> هر ورودی شامل: نام سرویس، نقش / کاربرد، اقدام مورد نیاز شما (Owner یا Admin)، سطح دسترسی پیشنهادی، و محل ذخیره‌سازی Credentials می‌باشد.
> **قانون امنیتی:** هیچ کلید یا رمز عبوری به‌صورت متن ساده در این فایل ذخیره نشود — تنها نام متغیرها و مکان ذخیره (Secrets) درج می‌شود.

---

## 1. Core developer / infra accounts (ضروری)
| سرویس | دامنه معمول | نقش / کاربرد | مالک پیشنهادی | Secret key name (در Replit / Server Vault) |
|---|---:|---|---|---|
| GitHub (Repo & Actions) | `github.com` | کد، PR، CI/CD، محافظت شاخه‌ها | Owner: `viraaiio` (تو) | `GITHUB_TOKEN` (Replit/GitHub Secrets) |
| Replit (Development + Copilot/Cursor) | `replit.com` | توسعه سریع، اجرای اولیه، environment | Admin: `viraaiio` | `REPLIT_TOKEN` |
| Backblaze B2 (Object Storage) | `backblaze.com` | بکاپ روزانه و آرشیو | Admin: `viraaiio` | `B2_KEY_ID` / `B2_APP_KEY` |
| Cloudflare (DNS, WAF, CDN) | `cloudflare.com` | DNS, WAF, TLS, Rate limiting | Admin: `viraaiio` | `CLOUDFLARE_API_TOKEN` |
| NOWPayments / Coinbase Commerce | `nowpayments.io` or `commerce.coinbase.com` | پرداخت با Tether (TRC20) | Finance / Owner | `NOWP_PAY_KEY` or `COINBASE_API_KEY` |
| Twilio (Phone / IVR) | `twilio.com` | شماره ثابت، IVR هوشمند، وبهوک‌ها | Support / Admin | `TWILIO_SID` / `TWILIO_AUTH_TOKEN` |
| Managed DB (e.g., Supabase/Postgres) | `supabase.com` | دیتابیس اولیه (auth) | Backend Lead | `DB_URL` / `DB_ADMIN_PASS` |
| Monitoring (UptimeRobot / Grafana) | `uptimerobot.com` / `grafana.com` | مانیتورینگ سرویس‌ها و alert | SRE | `MONITORING_API_KEY` |
| Mail (Brevo/Mailgun) | `brevo.com` / `mailgun.com` | ایمیل‌ ادمین / اعلان‌ها | Ops | `SMTP_USER` / `SMTP_PASS` |
| NOW (optional) / DockerHub | `hub.docker.com` | ذخیره تصاویر کانتینر | DevOps | `DOCKERHUB_TOKEN` |

---

## 2. Notes & actions (کارهای لازم، ترتیب اولویت)
1. **دو عاملی (2FA):** برای همه حساب‌های Owner/Admin (GitHub, Replit, Backblaze, Cloudflare, Twilio) فعال شود.  
2. **احراز مالکیت دامنه (viraai.io):** دامنه باید در Cloudflare وارد و برای TLS/Full و proxy فعال شود.  
3. **Create limited API keys:** برای CI/CD یک کلید با دسترسی محدود به Backblaze (فقط باکت `viraai-backups`) بساز. اسم پیشنهادی: `viraai-ci-key`.  
4. **Secrets storage:** همه کلیدها و توکن‌ها در:
   - **Replit Secrets** (برای اجرای در Replit)، و
   - **Server Vault** (برای سرور واقعی؛ مثلاً فایل `/etc/vault/viraai.env` با دسترسی 600 یا یک Vault مدیریت‌شده)
   ذخیره شوند — هرگز در کد یا repo ذخیره نشود.  
5. **تفکیک نقش‌ها:** تو (Owner) باید حداقل دو اکانت مجزا داشته باشی:  
   - `Owner` — حساب اصلی با دسترسی کامل  
   - `Admin/Dev` — حساب روزمره‌ی توسعه (کم‌تر با secrets کلی کار کند)  
6. **تگ‌گذاری و اسناد:** هر حساب داخل این فایل با تاریخ ایجاد و نام شخصی که ساخت را انجام داده ثبت شود (مثلاً: `Created: 2025-12-06 by viraaiio`).

---

## 3. Recommended setup checklist (چک‌لیست سریع)
- [ ] GitHub: repository ساخته شده (`ViraAI_Project`) و branch protection روی `main` فعال شده (no direct pushes).  
- [ ] Replit: Workspace `ViraAI-Phase0` ایجاد و `REPLIT_TOKEN` در Secrets ذخیره‌شده.  
- [ ] Backblaze: Bucket `viraai-backups` ساخته و Application Key با دسترسی محدود ایجاد‌شده.  
- [ ] Cloudflare: Zone `viraai.io` اضافه، TLS: Full و WAF فعال.  
- [ ] NOWPayments / Coinbase: حساب تست (sandbox) بساز و API key را در Secrets بگذار.  
- [ ] Twilio: شماره تست بگیر (trial) و SID/Auth token را در Secrets ذخیره کن.  
- [ ] Monitoring: UptimeRobot یک مانیتور برای `https://viraai.io/health` بساز.  
- [ ] Mail: یک SMTP account برای ارسال ایمیل‌های سیستم راه‌اندازی کن.  

---

## 4. Where to store secrets (محل ذخیره‌سازی پیشنهاد شده)
- **Replit Secrets** — برای متغیرهای مورد نیاز در Replit run.  
- **GitHub Secrets** — برای Actions (در صورتی که در آینده از GitHub Actions استفاده شود).  
- **Server Vault / OS-level secret manager** — برای متغیرهای سرور واقعی (`/etc/opt/viraai/secrets.env` یا HashiCorp Vault).  
- **Backblaze Application Keys** — فقط در Secrets CI نگهداری شود (نام پیشنهادی: `B2_CI_KEY_ID`, `B2_CI_APP_KEY`).

---

## 5. Commit & PR instructions (دقیقا چه‌کار باید بکنم)
**Branch:** `phase0-dev`  
**File path:** `/docs/accounts.md`  
**Commit message (copy/paste):**  
`phase/0-docs: add accounts & services list | ticket:PH0-001 | release:v0.0.1`  

پس از Commit، **یک Pull Request از `phase0-dev` به `main`** باز کن و برچسب `phase0` و `security-review` اضافه کن. من (Lead Architect) PR را بررسی می‌کنم و Merge را بعد از تایید انجام می‌دهم.

---

## 6. After merge — next immediate step
بعد از Merge این فایل:
1. به Cloudflare برو (اگر ندارید، بسازید) و مرحله DNS + TLS را انجام دهیم.  
2. سپس Replit Secrets و Backblaze limited key را اضافه کنیم.  
(من دستورالعمل‌های دقیق را مرحله‌به‌مرحله می‌نویسم — تو فقط بگو «برو مرحله بعد».)

---
