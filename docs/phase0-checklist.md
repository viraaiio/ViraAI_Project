# Phase 0 — Pre-Build Security & Infrastructure Checklist  
هدف: اطمینان از اینکه همه حساب‌ها، DNS، WAF، Secrets و Backup قبل از شروع ساخت اصلی آماده و ایمن هستند.

---

## 1. حساب‌ها و سرویس‌ها  
- [ ] GitHub Repository آماده  
- [ ] Replit Workspace ایجاد شده  
- [ ] Cloudflare Zone فعال  
- [ ] Backblaze B2 ایجاد و تست شده  
- [ ] NOWPayments حساب ایجاد  
- [ ] Twilio حساب ایجاد  
- [ ] Coinbase Commerce (اختیاری)

---

## 2. DNS & Cloudflare  
- [ ] Domain متصل به Cloudflare  
- [ ] SSL/TLS روی Full (strict اگر ممکن)  
- [ ] فعال‌سازی WAF Baseline Rule Set  
- [ ] فعال‌سازی Bot Fight Mode  
- [ ] Rate Limit برای مسیرهای /api/*  
- [ ] DNS A/AAAA/CNAME آماده

---

## 3. Secrets & Access Control  
- [ ] ساخت Secret Vault  
- [ ] ثبت همه Placeholder Secrets  
- [ ] تنظیم RBAC (Least Privilege)  
- [ ] غیرفعال‌سازی Keyهای قدیمی  
- [ ] عدم وجود Secrets در Repo تأیید شد  
- [ ] Security Policy نوشته شد

---

## 4. Backups & Storage  
- [ ] ایجاد Bucket خصوصی  
- [ ] فعال‌سازی 30-Day Retention  
- [ ] فعال‌سازی Lifecycle Rule  
- [ ] تست دستور `b2 ls`  
- [ ] تست موفق `b2 sync`  
- [ ] ساخت کلید محدود برای CI/CD  
- [ ] ثبت گزارش بکاپ در docs/backups.md

---

## 5. Server Prep (اختیاری — اگر اکنون استفاده شود)  
- [ ] ساخت مسیرهای /opt/viraai/{apps,logs,backups,deploy}  
- [ ] تنظیم Owner و Permissionها  
- [ ] تست SSH با کلید جدید  
- [ ] پورت پیش‌فرض SSH تغییر داده شد  
- [ ] Fail2Ban فعال شد (در فاز 1)

---

## 6. خروجی نهایی فاز 0  
- [ ] فایل accounts.md تکمیل  
- [ ] فایل backups.md تکمیل  
- [ ] این چک‌لیست کامل و Merge شد  
- [ ] PR فاز 0 بسته و شاخه dev حذف شد

