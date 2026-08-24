#!/bin/sh
set -eu

if [ "$#" -ne 5 ]; then
  echo "usage: replace_macos_app.sh OLD_PID STAGED_APP INSTALL_APP BACKUP_APP LOG_PATH" >&2
  exit 64
fi

OLD_PID="$1"
STAGED_APP="$2"
INSTALL_APP="$3"
BACKUP_APP="$4"
LOG_PATH="$5"
OPEN_COMMAND="${INBOX_OPEN_COMMAND:-/usr/bin/open}"

log() {
  printf '%s %s\n' "$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG_PATH"
}

safe_remove_generated() {
  path="$1"
  base="${path##*/}"
  case "$base" in
    .INbox.app.*)
      /bin/rm -rf -- "$path"
      ;;
    *)
      log "refusing recursive cleanup for unexpected path: $path"
      return 1
      ;;
  esac
}

cleanup() {
  exit_status=$?
  trap - EXIT HUP INT TERM

  if [ ! -e "$INSTALL_APP" ] && [ -e "$BACKUP_APP" ]; then
    if /bin/mv "$BACKUP_APP" "$INSTALL_APP"; then
      log "restored backup to $INSTALL_APP"
    else
      log "failed to restore backup from $BACKUP_APP"
    fi
  fi

  if [ "$exit_status" -eq 0 ] && [ -e "$BACKUP_APP" ]; then
    safe_remove_generated "$BACKUP_APP" || true
  fi

  if [ -e "$STAGED_APP" ]; then
    safe_remove_generated "$STAGED_APP" || true
  fi

  exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

case "$OLD_PID" in
  ''|*[!0-9]*)
    log "old pid is not numeric: $OLD_PID"
    exit 64
    ;;
esac

case "${STAGED_APP##*/}" in
  .INbox.app.installing.*) ;;
  *)
    log "staged app path is not generated: $STAGED_APP"
    exit 65
    ;;
esac

case "${BACKUP_APP##*/}" in
  .INbox.app.backup.*) ;;
  *)
    log "backup app path is not generated: $BACKUP_APP"
    exit 65
    ;;
esac

if [ ! -d "$STAGED_APP" ]; then
  log "staged app is missing: $STAGED_APP"
  exit 66
fi

if [ "$OLD_PID" -gt 0 ]; then
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if ! /bin/kill -0 "$OLD_PID" >/dev/null 2>&1; then
      break
    fi
    log "waiting for old INbox pid $OLD_PID ($attempt/10)"
    /bin/sleep 1
  done

  if /bin/kill -0 "$OLD_PID" >/dev/null 2>&1; then
    log "old INbox pid $OLD_PID did not exit within 10 seconds"
    exit 70
  fi
fi

if [ -e "$BACKUP_APP" ]; then
  safe_remove_generated "$BACKUP_APP"
fi

if [ -e "$INSTALL_APP" ]; then
  if ! /bin/mv "$INSTALL_APP" "$BACKUP_APP" 2>> "$LOG_PATH"; then
    log "failed to move installed app to backup"
    exit 67
  fi
fi

if ! /bin/mv "$STAGED_APP" "$INSTALL_APP" 2>> "$LOG_PATH"; then
  log "failed to move staged app into place"
  exit 68
fi
"$OPEN_COMMAND" "$INSTALL_APP"
log "installed update and opened $INSTALL_APP"
