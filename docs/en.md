# WHM Backup to Box (Full Setup Guide)

> This guide walks through every step required to automate WHM (cPanel) account backups, upload them to Box using `rclone`, clean up old logs, and optionally send Telegram notifications — all ready to be triggered monthly/weekly (via cron or n8n).

---

## Table of Contents

1. Create Telegram bot and get chat ID
2. Install and configure rclone (link WHM server → Box)
3. Set up secure MySQL credentials (`/root/.my.cnf`)
4. Add the backup script (full code included)
5. Test backup and verify Box upload
6. Scheduling options: cron or n8n (cron described here, n8n in next doc)

---

## 1 — Create Telegram Bot and Get Chat ID

### 1.1 Create bot and get Bot Token

1. Open Telegram and chat with `@BotFather`.
2. Run `/newbot`, choose a name and a username (e.g., `NotificationsBot`).
3. You’ll receive an **HTTP API token**, something like:

```

1234567890:AAHk...rest_of_token

````

Keep this safe — it’s your bot token.

### 1.2 Get numeric chat ID

From the Telegram account where you want to receive messages:

1. Send a message to your bot (e.g., `/start`).
2. In a terminal, run:

```bash
TOKEN="YOUR_BOT_TOKEN"
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | jq .
````

3. Look for `chat.id` in the JSON result — that’s your **chat ID**.
   If you don’t have `jq`, inspect the raw output:

```
"chat":{"id":123456789,"first_name":"..."}
```

  → Here `123456789` is the chat ID.

---

## 2 — Install and Configure `rclone` for Box

### 2.1 Install rclone (Debian/Ubuntu example)

```bash
curl https://rclone.org/install.sh | sudo bash
```

or via APT:

```bash
apt update
apt install rclone -y
```

### 2.2 Create a new remote called `box`

#### Option A — WHM server with browser access

```bash
rclone config
# Choose "n" for New remote
# name: box
# Storage: box
# client_id: (Enter)
# client_secret: (Enter)
# Edit advanced config? n
# Use auto config? y
```

This opens a browser — approve and done.

#### Option B — WHM server without browser (recommended)

1. On WHM server:

   ```bash
   rclone config
   ```

   When prompted `Use auto config?`, answer **n**.
   rclone will show something like:

   ```
   Execute the following on a machine with a web browser:
   rclone authorize "box"
   ```
2. On your local computer (with browser), run:

   ```bash
   rclone authorize "box"
   ```

   After logging into Box and allowing access, you’ll get a JSON like:

   ```json
   {"access_token":"...","refresh_token":"...","expiry":"..."}
   ```
3. Copy that JSON, go back to the WHM server, and paste it at the `config_token>` prompt.
4. Done — test the connection:

   ```bash
   rclone lsd box:
   rclone ls box:
   ```

> rclone config file is stored at `/root/.config/rclone/rclone.conf` — keep it secure.

---

## 3 — Prepare Secure MySQL Credentials

Create `/root/.my.cnf`:

```ini
[client]
user=root
password=YOUR_MYSQL_ROOT_PASSWORD
```

Set proper permissions:

```bash
chmod 600 /root/.my.cnf
```

Test:

```bash
mysql --defaults-file=/root/.my.cnf -e "SHOW DATABASES;"
```

---

## 4 — Backup Script (Full Code)

Save the file from this repository as `/root/whm_backup_to_box.sh` on your server.
Replace placeholders:

* `TELEGRAM_BOT_TOKEN` → your bot token
* `TELEGRAM_CHAT_ID` → numeric chat ID

Make it executable:

```bash
chmod 700 /root/whm_backup_to_box.sh
```

---

## 5 — Manual Testing

### Single user test

1. Start your Telegram bot with `/start`.
2. Run:
  ```bash
  TEST_USER=username bash /root/whm_backup_to_box.sh
  ```

Expected final output:

```json
{"status":"ok","message":"Backup finished for 1 of 1 accounts.","host":"yourhostname.example"}
```

Check logs:

```bash
cat /root/whm_backup.log
```

Check Box folder:

```bash
rclone lsd box:
```

Check Telegram messages.

---

## 6 — Scheduling

### Option A — Run via cron

To run automatically at **3:00 AM on the 1st of each month**:

```bash
crontab -e
```

Add:

```
0 3 1 * * TEST_USER="" bash /root/whm_backup_to_box.sh >> /root/whm_cron.log 2>&1
```

Alternatively, create `/root/run_whm_backup.sh`:

```bash
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin"
bash /root/whm_backup_to_box.sh
```

Then:

```bash
chmod +x /root/run_whm_backup.sh
```

and in crontab:

```
0 3 1 * * /root/run_whm_backup.sh >> /root/whm_cron.log 2>&1
```

### Option B — Run via n8n

See next document: [`Automate Remote Script Execution with n8n`](https://github.com/hanidabir/automate-remote-script-execution-with-n8n)

---

## Security Notes

* Secure sensitive files:

  ```bash
  chmod 600 /root/.my.cnf
  chmod 600 /root/.config/rclone/rclone.conf
  ```
* Never expose Telegram tokens or rclone tokens in public repos.
* Consider storing them as environment variables or in Vault for production.

---

**Now your system is fully automated**:

* Backups are generated and uploaded to Box.
* Logs are cleaned.
* Telegram receives reports.
* It runs automatically every month.
