#!/bin/sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
INSTALLER="$ROOT_DIR/scripts/install.sh"
TEST_TMP_DIRS=""
FAILURES=0

cleanup_tests() {
  for dir in $TEST_TMP_DIRS; do
    case "$dir" in
      /tmp/*|/var/folders/*)
        [ -n "$dir" ] && rm -rf "$dir"
        ;;
      *)
        printf '%s\n' "refusing to remove unexpected test directory: $dir" >&2
        ;;
    esac
  done
}
trap cleanup_tests EXIT INT TERM

fail() {
  printf '%s\n' "FAIL: $1" >&2
  exit 1
}

record_failure() {
  FAILURES=$((FAILURES + 1))
  printf '%s\n' "not ok - $1" >&2
}

run_test() {
  name="$1"
  if "$name"; then
    printf '%s\n' "ok - $name"
  else
    record_failure "$name"
  fi
}

assert_eq() {
  actual="$1"
  expected="$2"
  message="$3"
  [ "$actual" = "$expected" ] || fail "$message: expected '$expected', got '$actual'"
}

assert_contains() {
  file="$1"
  needle="$2"
  message="$3"
  grep -F "$needle" "$file" >/dev/null 2>&1 || fail "$message"
}

assert_not_exists() {
  path="$1"
  message="$2"
  [ ! -e "$path" ] || fail "$message"
}

assert_no_generated_backups() {
  install_dir="$1"
  set -- "$install_dir"/.INbox.app.backup.*
  [ ! -e "$1" ] || fail "backup should not remain: $1"
}

make_app() {
  app_dir="$1"
  marker="$2"
  mkdir -p "$app_dir/Contents/MacOS"
  printf '%s\n' "$marker" > "$app_dir/Contents/marker.txt"
  printf '%s\n' '#!/bin/sh' > "$app_dir/Contents/MacOS/INbox"
  chmod +x "$app_dir/Contents/MacOS/INbox"
}

read_marker() {
  cat "$1/Contents/marker.txt"
}

make_fake_command_dir() {
  test_dir="$1"
  command_dir="$test_dir/bin"
  mkdir -p "$command_dir"

  cat > "$command_dir/uname" <<'EOF'
#!/bin/sh
printf '%s\n' Darwin
EOF

  cat > "$command_dir/curl" <<'EOF'
#!/bin/sh
set -eu
out=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      shift
      out="$1"
      ;;
    http*|fixture:*)
      url="$1"
      ;;
  esac
  shift || break
done
printf '%s\n' "curl:$url" >> "$INBOX_FAKE_EVENTS"
[ "$url" = "$INBOX_EXPECTED_DMG_URL" ] || exit 22
mkdir -p "$(dirname "$out")"
printf '%s\n' fake-dmg > "$out"
EOF

  cat > "$command_dir/hdiutil" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "hdiutil:$*" >> "$INBOX_FAKE_EVENTS"
case "$1" in
  attach)
    printf '%s\n' "/dev/disk9 Apple_HFS $INBOX_FAKE_MOUNT_DIR"
    ;;
  detach)
    ;;
  *)
    exit 64
    ;;
esac
EOF

  cat > "$command_dir/ditto" <<'EOF'
#!/bin/sh
set -eu
src="$1"
dst="$2"
if [ -n "${INBOX_FAKE_INSTALL_APP:-}" ] && [ -f "$INBOX_FAKE_INSTALL_APP/Contents/marker.txt" ]; then
  marker="$(cat "$INBOX_FAKE_INSTALL_APP/Contents/marker.txt")"
else
  marker="missing"
fi
printf '%s\n' "ditto:$src:$dst:saw-installed-$marker" >> "$INBOX_FAKE_EVENTS"
mkdir -p "$(dirname "$dst")"
cp -R "$src" "$dst"
EOF

  cat > "$command_dir/ps" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "ps:$*" >> "$INBOX_FAKE_EVENTS"
if [ "${INBOX_FAKE_PS_FAIL:-}" = "1" ]; then
  exit 71
fi
case " $* " in
  *ww*)
    cat "$INBOX_FAKE_PROCESS_FILE"
    ;;
  *)
    if [ "${INBOX_FAKE_TRUNCATE_PS:-}" = "1" ]; then
      awk '{ if (length($0) > 80) print substr($0, 1, 80); else print }' "$INBOX_FAKE_PROCESS_FILE"
    else
      cat "$INBOX_FAKE_PROCESS_FILE"
    fi
    ;;
esac
EOF

  cat > "$command_dir/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF

  cat > "$command_dir/kill" <<'EOF'
#!/bin/sh
set -eu
signal="$1"
pid="$2"
printf '%s\n' "kill:$signal:$pid" >> "$INBOX_FAKE_QUIT_LOG"
if [ "$signal" != "-TERM" ]; then
  exit 64
fi
if [ "${INBOX_FAKE_STUCK_PID:-}" = "$pid" ]; then
  exit 0
fi
awk -v dead_pid="$pid" '$1 != dead_pid { print }' "$INBOX_FAKE_PROCESS_FILE" > "$INBOX_FAKE_PROCESS_FILE.tmp"
mv "$INBOX_FAKE_PROCESS_FILE.tmp" "$INBOX_FAKE_PROCESS_FILE"
EOF

  cat > "$command_dir/sleep" <<'EOF'
#!/bin/sh
printf '%s\n' "sleep:$1" >> "$INBOX_FAKE_EVENTS"
EOF

  cat > "$command_dir/open" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$INBOX_FAKE_OPEN_LOG"
EOF

  cat > "$command_dir/osascript" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "osascript:$*" >> "$INBOX_FAKE_EVENTS"
EOF

  cat > "$command_dir/lsregister" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "lsregister:$*" >> "$INBOX_FAKE_EVENTS"
EOF

  cat > "$command_dir/rm" <<'EOF'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    /Applications/INbox.app|/Applications/.INbox.app.*)
      printf '%s\n' "blocked unsafe rm:$arg" >> "$INBOX_FAKE_EVENTS"
      exit 42
      ;;
  esac
done
exec /bin/rm "$@"
EOF

  cat > "$command_dir/mv" <<'EOF'
#!/bin/sh
set -eu
from="$1"
to="$2"
printf '%s\n' "mv:$from:$to" >> "$INBOX_FAKE_EVENTS"
case "${from##*/}:$to:${INBOX_FAKE_FAIL_STAGED_TO_FINAL:-}" in
  .INbox.app.installing.*:"$INBOX_FAKE_FAIL_MOVE_TO":1)
    exit 73
    ;;
esac
exec /bin/mv "$from" "$to"
EOF

  chmod +x "$command_dir"/*
  printf '%s\n' "$command_dir"
}

make_fixture() {
  tmp_dir="$(mktemp -d)"
  TEST_TMP_DIRS="$TEST_TMP_DIRS $tmp_dir"
  mkdir -p "$tmp_dir/Apps" "$tmp_dir/mount"
  make_app "$tmp_dir/mount/INbox.app" new
  make_app "$tmp_dir/Apps/INbox.app" old
  : > "$tmp_dir/events.log"
  : > "$tmp_dir/processes.txt"
  : > "$tmp_dir/quit.log"
  : > "$tmp_dir/open.log"
  make_fake_command_dir "$tmp_dir" > "$tmp_dir/command_dir.txt"
  printf '%s\n' "$tmp_dir"
}

run_installer() {
  tmp_dir="$1"
  stdout="$tmp_dir/stdout.log"
  stderr="$tmp_dir/stderr.log"
  command_dir="$(cat "$tmp_dir/command_dir.txt")"
  INBOX_INSTALL_DIR="$tmp_dir/Apps" \
  INBOX_DMG_URL="fixture://INbox.dmg" \
  INBOX_COMMAND_DIR="$command_dir" \
  INBOX_FAKE_EVENTS="$tmp_dir/events.log" \
  INBOX_FAKE_PROCESS_FILE="$tmp_dir/processes.txt" \
  INBOX_FAKE_QUIT_LOG="$tmp_dir/quit.log" \
  INBOX_FAKE_OPEN_LOG="$tmp_dir/open.log" \
  INBOX_FAKE_MOUNT_DIR="$tmp_dir/mount" \
  INBOX_FAKE_INSTALL_APP="$tmp_dir/Apps/INbox.app" \
  INBOX_EXPECTED_DMG_URL="fixture://INbox.dmg" \
  INBOX_FAKE_STUCK_PID="${INBOX_FAKE_STUCK_PID:-}" \
  INBOX_FAKE_PS_FAIL="${INBOX_FAKE_PS_FAIL:-}" \
  INBOX_FAKE_TRUNCATE_PS="${INBOX_FAKE_TRUNCATE_PS:-}" \
  INBOX_FAKE_FAIL_MOVE_TO="${INBOX_FAKE_FAIL_MOVE_TO:-}" \
  INBOX_FAKE_FAIL_STAGED_TO_FINAL="${INBOX_FAKE_FAIL_STAGED_TO_FINAL:-}" \
  PATH="$command_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
  sh "$INSTALLER" > "$stdout" 2> "$stderr"
}

test_success_replaces_marker_and_opens_exact_final_path() {
  tmp_dir="$(make_fixture)"
  run_installer "$tmp_dir"

  assert_eq "$(read_marker "$tmp_dir/Apps/INbox.app")" new "installed app marker"
  assert_eq "$(cat "$tmp_dir/open.log")" "$tmp_dir/Apps/INbox.app" "installer opened exact final path"
  assert_no_generated_backups "$tmp_dir/Apps"
}

test_staging_completes_before_old_app_is_moved() {
  tmp_dir="$(make_fixture)"
  run_installer "$tmp_dir"

  assert_contains "$tmp_dir/events.log" "saw-installed-old" "staging should see old app still in place"
}

test_still_running_pid_aborts_without_touching_old_app() {
  tmp_dir="$(make_fixture)"
  printf '%s\n' "1234 /Applications/INbox.app/Contents/MacOS/INbox" > "$tmp_dir/processes.txt"
  INBOX_FAKE_STUCK_PID=1234 run_installer "$tmp_dir" && fail "installer should fail while INbox is still running"

  assert_eq "$(read_marker "$tmp_dir/Apps/INbox.app")" old "old app should remain after timeout"
  assert_no_generated_backups "$tmp_dir/Apps"
  [ ! -s "$tmp_dir/open.log" ] || fail "installer should not open after process timeout"
}

test_failed_staged_to_final_move_restores_old_app() {
  tmp_dir="$(make_fixture)"
  INBOX_FAKE_FAIL_STAGED_TO_FINAL=1 INBOX_FAKE_FAIL_MOVE_TO="$tmp_dir/Apps/INbox.app" run_installer "$tmp_dir" && fail "installer should fail when final move fails"

  assert_eq "$(read_marker "$tmp_dir/Apps/INbox.app")" old "old app should be restored after final move failure"
  [ ! -s "$tmp_dir/open.log" ] || fail "installer should not open after failed final move"
}

test_all_matching_executable_paths_receive_quit_request() {
  tmp_dir="$(make_fixture)"
  debug_executable="$tmp_dir/build/macos/Build/Products/Debug/INbox.app/Contents/MacOS/INbox"
  printf '%s\n' "111 /Applications/INbox.app/Contents/MacOS/INbox" > "$tmp_dir/processes.txt"
  printf '%s\n' "222 $debug_executable" >> "$tmp_dir/processes.txt"
  printf '%s\n' "333 /Applications/INbox.app/Contents/MacOS/INboxHelper" >> "$tmp_dir/processes.txt"

  run_installer "$tmp_dir"

  assert_contains "$tmp_dir/quit.log" "kill:-TERM:111" "installed app process should receive TERM"
  assert_contains "$tmp_dir/quit.log" "kill:-TERM:222" "debug app process should receive TERM"
  if grep -F "kill:-TERM:333" "$tmp_dir/quit.log" >/dev/null 2>&1; then
    fail "non-matching executable should not receive TERM"
  fi
}

test_spaced_long_debug_executable_aborts_before_replacement() {
  tmp_dir="$(make_fixture)"
  debug_executable="$tmp_dir/build output/with a very long folder name that requires wide ps output/Debug Builds/INbox.app/Contents/MacOS/INbox"
  printf '%s\n' "444 $debug_executable" > "$tmp_dir/processes.txt"

  INBOX_FAKE_TRUNCATE_PS=1 INBOX_FAKE_STUCK_PID=444 run_installer "$tmp_dir" && fail "installer should fail while spaced Debug INbox is still running"

  assert_contains "$tmp_dir/quit.log" "kill:-TERM:444" "spaced Debug app process should receive TERM"
  assert_eq "$(read_marker "$tmp_dir/Apps/INbox.app")" old "old app should remain when spaced Debug app is still running"
  [ ! -s "$tmp_dir/open.log" ] || fail "installer should not open after spaced Debug process timeout"
}

test_ps_failure_aborts_without_touching_old_app() {
  tmp_dir="$(make_fixture)"

  INBOX_FAKE_PS_FAIL=1 run_installer "$tmp_dir" && fail "installer should fail when process enumeration fails"

  assert_eq "$(read_marker "$tmp_dir/Apps/INbox.app")" old "old app should remain after ps failure"
  assert_no_generated_backups "$tmp_dir/Apps"
  [ ! -s "$tmp_dir/open.log" ] || fail "installer should not open after ps failure"
}

run_all_tests() {
  run_test test_success_replaces_marker_and_opens_exact_final_path
  run_test test_staging_completes_before_old_app_is_moved
  run_test test_still_running_pid_aborts_without_touching_old_app
  run_test test_failed_staged_to_final_move_restores_old_app
  run_test test_all_matching_executable_paths_receive_quit_request
  run_test test_spaced_long_debug_executable_aborts_before_replacement
  run_test test_ps_failure_aborts_without_touching_old_app
}

if [ "$#" -gt 0 ]; then
  for test_name in "$@"; do
    run_test "$test_name"
  done
else
  run_all_tests
fi

if [ "$FAILURES" -ne 0 ]; then
  printf '%s\n' "install_sh_test.sh: $FAILURES test(s) failed" >&2
  exit 1
fi

printf '%s\n' "install_sh_test.sh: all tests passed"
