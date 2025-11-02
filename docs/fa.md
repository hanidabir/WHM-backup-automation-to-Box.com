# پشتیبان‌گیری WHM به Box (راهنمای کامل راه‌اندازی)

> این راهنما همه مراحل لازم برای خودکارسازی پشتیبان‌گیری از حساب‌های WHM (cPanel)، آپلود آنها به Box با استفاده از `rclone`، پاک‌سازی لاگ‌های قدیمی و ارسال اطلاعیه‌های تلگرام (اختیاری) را توضیح می‌دهد — همه آماده اجرا به صورت ماهانه/هفتگی (با cron یا n8n).

---

## فهرست مطالب

۱. ایجاد ربات تلگرام و دریافت chat ID
۲. نصب و پیکربندی rclone (وصل کردن سرور WHM به Box)
۳. آماده‌سازی اعتبارنامه امن MySQL (`/root/.my.cnf`)
۴. افزودن اسکریپت پشتیبان‌گیری (کد کامل)
۵. تست پشتیبان‌گیری و بررسی آپلود در Box
۶. زمان‌بندی: cron یا n8n (cron در اینجا توضیح داده شده، n8n در سند بعدی)

---

## ۱ — ایجاد ربات تلگرام و دریافت chat ID

### ۱.۱ ساخت ربات و دریافت توکن

۱. تلگرام را باز کنید و وارد صفحه‌ی `@BotFather` شوید.

۲. دستور `/newbot` را اجرا کنید و یک نام و نام کاربری انتخاب کنید (مثلاً `NotificationsBot`).

۳. یک **توکن API** دریافت می‌کنید، چیزی شبیه:
```
1234567890:AAHk...rest_of_token
````

این توکن را امن نگه دارید — این توکن ربات شماست.

### ۱.۲ دریافت chat ID عددی

از حساب تلگرامی که می‌خواهید پیام‌ها را دریافت کند:

۱. یک پیام به ربات خود ارسال کنید (مثلاً `/start`).

۲. در ترمینال اجرا کنید:

```bash
TOKEN="YOUR_BOT_TOKEN"
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | jq .
````

۳. در خروجی JSON به دنبال `chat.id` بگردید — این همان **chat ID** شماست.
   اگر `jq` ندارید، خروجی خام را بررسی کنید:

```
"chat":{"id":123456789,"first_name":"..."}
```

- عدد `123456789` همان chat ID است.

---

## ۲ — نصب و پیکربندی `rclone` برای Box

### ۲.۱ نصب rclone (مثال Debian/Ubuntu)

```bash
curl https://rclone.org/install.sh | sudo bash
```

یا از طریق APT:

```bash
apt update
apt install rclone -y
```

### ۲.۲ ایجاد یک remote جدید به نام `box`

#### گزینه الف — سرور WHM با دسترسی مرورگر

```bash
rclone config
# انتخاب "n" برای Remote جدید
# name: box
# Storage: box
# client_id: (وارد کنید)
# client_secret: (وارد کنید)
# Edit advanced config? n
# Use auto config? y
```

مرورگر باز می‌شود — تأیید کنید و تمام شد.

#### گزینه ب — سرور WHM بدون مرورگر (توصیه شده)

۱. روی سرور WHM اجرا کنید:

```bash
rclone config
```

هنگامی که `Use auto config?` پرسیده شد، پاسخ **n** دهید.
rclone چیزی شبیه این نمایش می‌دهد:

```
Execute the following on a machine with a web browser:
rclone authorize "box"
```

۲. روی کامپیوتر محلی خود (با مرورگر) اجرا کنید:

```bash
rclone authorize "box"
```

بعد از ورود به Box و اجازه دسترسی، یک JSON دریافت خواهید کرد:

```json
{"access_token":"...","refresh_token":"...","expiry":"..."}
```

۳. آن JSON را کپی کنید، به سرور WHM بازگردید و در پرامپت `config_token>` قرار دهید.

۴. تمام — اتصال را تست کنید:

```bash
rclone lsd box:
rclone ls box:
```

> فایل پیکربندی rclone در مسیر `/root/.config/rclone/rclone.conf` ذخیره می‌شود — آن را امن نگه دارید.

---

## ۳ — آماده‌سازی اعتبارنامه امن MySQL

ایجاد `/root/.my.cnf`:

```ini
[client]
user=root
password=YOUR_MYSQL_ROOT_PASSWORD
```

مجوزهای مناسب را تنظیم کنید:

```bash
chmod 600 /root/.my.cnf
```

تست کنید:

```bash
mysql --defaults-file=/root/.my.cnf -e "SHOW DATABASES;"
```

---

## ۴ — اسکریپت پشتیبان‌گیری (کد کامل)

فایل موجود در این ریپازیتوری را روی سرور خود در مسیر `/root/whm_backup_to_box.sh` ذخیره کنید.
جایگزین‌های زیر را تغییر دهید:

* `TELEGRAM_BOT_TOKEN` → توکن ربات شما
* `TELEGRAM_CHAT_ID` → chat ID عددی شما

اجرای فایل را فعال کنید:

```bash
chmod 700 /root/whm_backup_to_box.sh
```

---

## ۵ — تست دستی

### تست برای یک کاربر

1. ربات تلگرام خود را با `/start` فعال کنید.
2. اجرا کنید:

```bash
TEST_USER=username bash /root/whm_backup_to_box.sh
```

خروجی نهایی مورد انتظار:

```json
{"status":"ok","message":"Backup finished for 1 of 1 accounts.","host":"yourhostname.example"}
```

بررسی لاگ‌ها:

```bash
cat /root/whm_backup.log
```

بررسی پوشه Box:

```bash
rclone lsd box:
```

پیام‌های تلگرام را بررسی کنید.

---

## ۶ — زمان‌بندی

### گزینه الف — اجرا از طریق cron

برای اجرا به صورت خودکار در **ساعت ۳:۰۰ بامداد روز اول هر ماه**:

```bash
crontab -e
```

اضافه کنید:

```
0 3 1 * * TEST_USER="" bash /root/whm_backup_to_box.sh >> /root/whm_cron.log 2>&1
```

همچنین می‌توانید فایل `/root/run_whm_backup.sh` بسازید:

```bash
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin"
bash /root/whm_backup_to_box.sh
```

سپس:

```bash
chmod +x /root/run_whm_backup.sh
```

و در crontab:

```
0 3 1 * * /root/run_whm_backup.sh >> /root/whm_cron.log 2>&1
```

### گزینه ب — اجرا از طریق n8n

ریپازیتوری بعدی را ببینید: [`Automate Remote Script Execution with n8n`](https://github.com/hanidabir/automate-remote-script-execution-with-n8n)

---

## نکات امنیتی

* فایل‌های حساس را امن کنید:

```bash
chmod 600 /root/.my.cnf
chmod 600 /root/.config/rclone/rclone.conf
```

* هرگز توکن‌های تلگرام یا rclone را در ریپازیتوری عمومی قرار ندهید.
* برای محیط تولید، استفاده از متغیرهای محیطی یا Vault توصیه می‌شود.

---

**اکنون سیستم شما کاملاً خودکار است**:

* پشتیبان‌ها تولید و به Box آپلود می‌شوند.
* لاگ‌ها پاکسازی می‌شوند.
* پیام‌های تلگرام دریافت می‌شوند.
* هر ماه به صورت خودکار اجرا می‌شود.

```
```
