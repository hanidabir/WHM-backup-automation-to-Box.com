#!/bin/bash
# =========================================================
#  WHM Monthly Backup to Box.com (JSON + Telegram per-user)
# =========================================================


set -euo pipefail
IFS=$'\n\t'

# ---------- SETTINGS ----------
BACKUP_DIR="/home/Site Backup"
BOX_DIR_NAME="$(date +'%Y-%m')"
LOG_FILE="/root/whm_monthly_backup.log"
HOSTNAME="$(hostname)"
TEST_USER=""
MAX_SIZE_MB=1900   # ✅ Split threshold (in MB)

# 🟢 Telegram
TELEGRAM_BOT_TOKEN="TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="TELEGRAM_CHAT_ID"

# ---------- FUNCTIONS ----------
log() { echo "$@" | tee -a "$LOG_FILE"; }

send_telegram() {
  local msg="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="$msg" > /dev/null 2>&1 || true
  fi
}

finish() {
  local status="$1"
  local msg="$2"
  echo "{\"status\":\"$status\",\"message\":\"$msg\",\"host\":\"$HOSTNAME\"}"
  exit 0
}

# ---------- MAIN ----------
mkdir -p "$BACKUP_DIR"
log "=== WHM Monthly Backup started at $(date) ==="
log "-----------------------------------------"
log "📦 Starting WHM Monthly Backup on $HOSTNAME"

# Check MySQL root access
if ! mysql --defaults-file=/root/.my.cnf -e "SHOW DATABASES;" >/dev/null 2>&1; then
  log "⚠️ MySQL root access failed!"
  finish "error" "MySQL root access denied on $HOSTNAME"
fi

# Select users
if [[ -n "$TEST_USER" ]]; then
  USERS=("$TEST_USER")
else
  USERS=($(ls -1 /var/cpanel/users 2>/dev/null))
fi

[[ ${#USERS[@]} -eq 0 ]] && finish "error" "No cPanel accounts found on $HOSTNAME"

SUMMARY_FILE="$BACKUP_DIR/summary_$(date +%F_%H-%M-%S).txt"
> "$SUMMARY_FILE"

for user in "${USERS[@]}"; do
  if [[ ! -d "/home/$user" ]]; then
    log "⚠️  Skipping $user — home directory not found."
    continue
  fi

  log "-----------------------------------------"
  log "🔹 Starting backup for account: $user"

  USER_BACKUP_DIR="$BACKUP_DIR/$user"
  mkdir -p "$USER_BACKUP_DIR"

  # 1️⃣ Compress files
  log "📦 Compressing files for $user ..."
  TAR_FILE="$USER_BACKUP_DIR/${user}_files.tar.gz"
  if tar -czf "$TAR_FILE" "/home/$user" >/dev/null 2>&1; then
    log "✅ Files compressed for $user"
  else
    log "⚠️ Failed to compress files for $user"
  fi

  # 2️⃣ Split if file exceeds 1.9 GB
  FILE_SIZE_MB=$(du -m "$TAR_FILE" | cut -f1)
  if (( FILE_SIZE_MB > MAX_SIZE_MB )); then
    log "⚠️ File size ${FILE_SIZE_MB}MB > ${MAX_SIZE_MB}MB. Splitting..."
    split -b "${MAX_SIZE_MB}M" "$TAR_FILE" "${TAR_FILE}.part-"
    rm -f "$TAR_FILE"
    log "✅ Split complete into parts:"
    ls -lh "${TAR_FILE}.part-"* | tee -a "$LOG_FILE"
  else
    log "📏 File size OK (${FILE_SIZE_MB}MB)"
  fi

  # 3️⃣ Dump databases
  log "💾 Detecting databases for $user ..."
  DBS=$(mysql --defaults-file=/root/.my.cnf -Nse "SHOW DATABASES LIKE '${user}_%';" 2>/dev/null || true)
  if [[ -z "$DBS" ]]; then
    log "⚠️  No databases found for $user."
  else
    for db in $DBS; do
      log "🗄️  Dumping $db ..."
      mysqldump --defaults-file=/root/.my.cnf "$db" | gzip > "$USER_BACKUP_DIR/${db}.sql.gz" 2>>"$LOG_FILE" || \
        log "⚠️ Dump failed for $db"
    done
  fi

  # 4️⃣ Upload to Box
  log "☁️ Uploading $user backup to Box under $BOX_DIR_NAME ..."
  if rclone copy "$USER_BACKUP_DIR" "box:Site Backup/$BOX_DIR_NAME/$user" >>"$LOG_FILE" 2>&1; then
    log "✅ Upload successful for $user"
    rm -rf "$USER_BACKUP_DIR"
    send_telegram "✅ Backup completed | 👤 User: ${user} | 🌐 Host: ${HOSTNAME} | 📦 Folder: ${BOX_DIR_NAME} | Status: ✅ Success"
  else
    log "⚠️ Upload failed for $user (keeping local copy)"
    send_telegram "⚠️ Backup failed | 👤 User: ${user} | 🌐 Host: ${HOSTNAME} | Status: ❌ Upload failed"
  fi

  echo "$user - OK" >> "$SUMMARY_FILE"
  log "✅ Finished backup for $user"
done

# ---------- FINAL JSON ----------
TOTAL_USERS=${#USERS[@]}
SUCCESS_COUNT=$(grep -c "OK" "$SUMMARY_FILE" || true)
MSG="Backup finished for $SUCCESS_COUNT of $TOTAL_USERS accounts."

finish "ok" "$MSG"
