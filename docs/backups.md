# Backups — ViraAI Infrastructure & Codebase  
این سند ساختار، سیاست‌ها و فرآیندهای بکاپ‌گیری پروژه ViraAI را مشخص می‌کند و برای ممیزی امنیتی، Disaster Recovery و CI/CD مورد استفاده قرار می‌گیرد.

---

## 1. Bucket Configuration  
**Bucket Name:** viraai-backups  
**Provider:** Backblaze B2  
**Access:** allPrivate (فقط از طریق کلیدهای اختصاصی)  
**Region:** auto (بهترین عملکرد)  
**Encryption:** سرور-ساید فعال  

---

## 2. Retention & Lifecycle  
- نگه‌داری نسخه‌ها: 30 روز  
- حذف نسخه‌های قدیمی‌تر از 30 روز  
- نگه‌داری Always Keep برای فایل‌های زیر:
  - `package.json`
  - `package-lock.json`
  - `README.md`
  - `deployment/*`
  - `configs/*`

---

## 3. Backup Sources  
### 3.1. Codebase  
مسیر اصلی پروژه که Sync می‌شود:

