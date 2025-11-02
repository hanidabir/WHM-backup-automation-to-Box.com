# WHM Backup to Box  
*(Automate cPanel account backups and upload to Box with optional Telegram notifications)*

This guide explains how to automatically back up all WHM (cPanel) accounts, compress their files, dump their databases, upload the backups to **Box** using `rclone`, and optionally send **Telegram notifications** per user. It also generates a JSON summary of the process for easy monitoring.

The workflow is **ready-to-use and fully customizable** — it can be triggered monthly/weekly via **cron** or integrated into **n8n** for more advanced automation.

---

## Use Cases

* Automating backups of all cPanel accounts
* Compressing and splitting large account files
* Dumping MySQL databases securely
* Uploading backups to Box cloud storage
* Sending per-user backup notifications to Telegram
* Generating JSON summaries for monitoring or dashboards

---

[English Version](https://github.com/hanidabir/WHM-backup-automation-to-Box.com/blob/main/docs/en.md) | [نسخه فارسی](https://github.com/hanidabir/WHM-backup-automation-to-Box.com/blob/main/docs/fa.md)

---

## Workflow Summary

| Component                  | Description                                           |
| -------------------------- | ----------------------------------------------------- |
| `whm_backup_to_box.sh` | The main Bash backup script                      |
| `rclone`                   | Handles secure upload to Box                           |
| `/root/.my.cnf`            | Stores MySQL credentials securely                      |
| Telegram Bot               | Sends notifications per user (optional)               |
| Cron / Scheduler           | Triggers backup automatically                          |
| JSON Summary Output        | Provides structured report for monitoring or logging  |
