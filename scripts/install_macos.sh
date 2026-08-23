#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")
APP_DIR="$REPO_DIR/app"
RELEASE_APP="$APP_DIR/build/macos/Build/Products/Release/INbox.app"
INSTALL_APP="/Applications/INbox.app"
STAGED_APP="/Applications/.INbox.app.installing.$$"
BACKUP_APP="/Applications/.INbox.app.backup.$$"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

installation_failed() {
  echo "Could not install INbox to $INSTALL_APP." >&2
  echo "Copy it manually from: $RELEASE_APP" >&2
}

archive_build_app() {
  build_app=$1
  archived_app="$build_app.noindex"

  if [ ! -d "$build_app" ]; then
    return
  fi

  "$LSREGISTER" -u "$build_app" >/dev/null 2>&1 || true
  /bin/rm -rf "$archived_app"
  /bin/mv "$build_app" "$archived_app"
}

stop_installed_app() {
  installed_executable='^/Applications/INbox[.]app/Contents/MacOS/INbox$'

  if ! /usr/bin/pgrep -f "$installed_executable" >/dev/null 2>&1; then
    return
  fi

  /usr/bin/pkill -TERM -f "$installed_executable"
  for attempt in 1 2 3 4 5; do
    if ! /usr/bin/pgrep -f "$installed_executable" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done

  echo "Could not stop the running INbox app. Quit it and run this script again." >&2
  exit 1
}

cleanup_installation() {
  exit_status=$?
  trap - EXIT HUP INT TERM

  if [ ! -e "$INSTALL_APP" ] && [ -e "$BACKUP_APP" ]; then
    if ! /bin/mv "$BACKUP_APP" "$INSTALL_APP"; then
      echo "The previous app remains at: $BACKUP_APP" >&2
    fi
  elif [ -e "$INSTALL_APP" ] && [ -e "$BACKUP_APP" ]; then
    /bin/rm -rf "$BACKUP_APP" || true
  fi

  /bin/rm -rf "$STAGED_APP" || true
  exit "$exit_status"
}

trap cleanup_installation EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cd "$APP_DIR"
flutter pub get
flutter build macos --release

if [ ! -d "$RELEASE_APP" ]; then
  echo "Release app not found: $RELEASE_APP" >&2
  exit 1
fi

if ! /usr/bin/ditto "$RELEASE_APP" "$STAGED_APP"; then
  installation_failed
  exit 1
fi

stop_installed_app

if [ -e "$INSTALL_APP" ]; then
  if ! /bin/mv "$INSTALL_APP" "$BACKUP_APP"; then
    installation_failed
    exit 1
  fi
fi

if ! /bin/mv "$STAGED_APP" "$INSTALL_APP"; then
  if [ -e "$BACKUP_APP" ] && ! /bin/mv "$BACKUP_APP" "$INSTALL_APP"; then
    echo "The previous app remains at: $BACKUP_APP" >&2
  fi
  installation_failed
  exit 1
fi

if [ -e "$BACKUP_APP" ]; then
  /bin/rm -rf "$BACKUP_APP"
fi

"$LSREGISTER" -f "$INSTALL_APP" >/dev/null 2>&1 || true
archive_build_app "$APP_DIR/build/macos/Build/Products/Debug/INbox.app"
archive_build_app "$APP_DIR/build/macos/Build/Products/Profile/INbox.app"
archive_build_app "$RELEASE_APP"

trap - EXIT HUP INT TERM
echo "INbox installed successfully: $INSTALL_APP"
