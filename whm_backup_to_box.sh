#!/bin/bash
# =========================================================
# WHM Backup to Box.com
# =========================================================

set -euo pipefail
IFS=$'\n\t'

# ---------- SETTINGS ----------
BACKUP_DIR="/home/Site Backup"
BOX_DIR_NAME="$(date +'%Y-%m-%d')"
LOG_FILE="/root/whm_backup.log"
HOSTNAME="$(hostname)"
TEST_USER=""
MAX_SIZE_MB=1900

# Telegram
TELEGRAM_BOT_TOKEN="TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="TELEGRAM_CHAT_ID"

# ---------- CLEAN LOG ----------
rm -f "$LOG_FILE"
touch "$LOG_FILE"
log() { echo "$@" | tee -a "$LOG_FILE"; }

SUMMARY_FILE="$BACKUP_DIR/summary_$(date +%F_%H-%M-%S).txt"
> "$SUMMARY_FILE"

send_telegram_file() {
  curl -s -F chat_id="$TELEGRAM_CHAT_ID" \
       -F document=@"$LOG_FILE" \
       "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" >/dev/null 2>&1 || true
}

send_telegram_msg() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
       -d chat_id="${TELEGRAM_CHAT_ID}" \
       -d parse_mode="Markdown" \
       -d text="$1" >/dev/null 2>&1 || true
}

log "=== WHM Backup started at $(date) ==="
log "-----------------------------------------"
log "📦 Host: $HOSTNAME | Date: $BOX_DIR_NAME"

if [[ -n "$TEST_USER" ]]; then
  USERS=("$TEST_USER")
else
  USERS=($(ls -1 /var/cpanel/users 2>/dev/null))
fi

[[ ${#USERS[@]} -eq 0 ]] && exit 1

declare -A RESULT
declare -A REASON

for user in "${USERS[@]}"; do
  log "-----------------------------------------"
  log "🔹 Backup for account: $user"

  RESULT["$user"]="✅"
  REASON["$user"]=""

  USER_BACKUP_DIR="$BACKUP_DIR/$user"
  mkdir -p "$USER_BACKUP_DIR"

  TAR_FILE="$USER_BACKUP_DIR/${user}_files.tar.gz"
  log "📦 Compressing files..."
  if ! tar -czf "$TAR_FILE" "/home/$user" >>"$LOG_FILE" 2>&1; then
    REASON["$user"]="File compression failed"
  fi

  FILE_SIZE_MB=$(du -m "$TAR_FILE" | cut -f1 || echo 0)
  if (( FILE_SIZE_MB > MAX_SIZE_MB )); then
    log "⚠️ Splitting file..."
    split -b "${MAX_SIZE_MB}M" "$TAR_FILE" "${TAR_FILE}.part-"
    rm -f "$TAR_FILE"
  fi

  log "💾 Checking DBs..."
  DBS=$(mysql --defaults-file=/root/.my.cnf -Nse "SHOW DATABASES LIKE '${user}_%';" || true)
  if [[ -n "$DBS" ]]; then
    for db in $DBS; do
      log "🗄️ Dumping $db ..."
      mysqldump --defaults-file=/root/.my.cnf "$db" | gzip > "$USER_BACKUP_DIR/${db}.sql.gz" 2>>"$LOG_FILE" \
      || REASON["$user"]="DB dump failed"
    done
  fi

  log "☁️ Uploading to Box..."
  if rclone copy "$USER_BACKUP_DIR" "box:Site Backup/$BOX_DIR_NAME/$user" >>"$LOG_FILE" 2>&1; then
    log "✅ Upload done"
    rm -rf "$USER_BACKUP_DIR"
  else
    RESULT["$user"]="❌"
    REASON["$user"]="Upload failed"
    log "⚠️ Upload failed — local copy kept"
  fi

  log "✅ Finished $user"
done

# ---------- SUMMARY MESSAGE ----------
SUMMARY="✅ *Backup Completed*
🌐 Host: *$HOSTNAME* | 📦 Folder: *$BOX_DIR_NAME*

👤 *Users:*"

for user in "${USERS[@]}"; do
  if [[ -n "${REASON[$user]}" ]]; then
    SUMMARY+="
• ${user} ${RESULT[$user]}
  ${REASON[$user]}"
  else
    SUMMARY+="
• ${user} ${RESULT[$user]}"
  fi
done

send_telegram_msg "$SUMMARY"
send_telegram_file

log "✅ Backup finished at $(date)"
exit 0
