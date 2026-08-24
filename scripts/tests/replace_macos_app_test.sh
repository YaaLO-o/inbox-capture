#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
HELPER="$ROOT_DIR/app/macos/Runner/Resources/replace_macos_app.sh"
TEST_TMP_DIRS=""

cleanup_tests() {
  for dir in $TEST_TMP_DIRS; do
    rm -rf "$dir"
  done
}
trap cleanup_tests EXIT INT TERM

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

make_fake_open() {
  fake_open_bin_dir="$1"
  fake_open_log_path="$2"
  mkdir -p "$fake_open_bin_dir"
  fake_open="$fake_open_bin_dir/open"
  {
    printf '%s\n' '#!/bin/sh'
    printf '%s\n' 'set -eu'
    printf '%s\n' 'printf "%s\n" "$1" >> "$INBOX_FAKE_OPEN_LOG"'
  } > "$fake_open"
  chmod +x "$fake_open"
  export INBOX_OPEN_COMMAND="$fake_open"
  export INBOX_FAKE_OPEN_LOG="$fake_open_log_path"
}

write_marker() {
  app_dir="$1"
  marker="$2"
  mkdir -p "$app_dir/Contents"
  printf '%s\n' "$marker" > "$app_dir/Contents/marker.txt"
}

read_marker() {
  app_dir="$1"
  cat "$app_dir/Contents/marker.txt"
}

assert_marker() {
  app_dir="$1"
  expected="$2"
  actual="$(read_marker "$app_dir")"
  [ "$actual" = "$expected" ] || fail "expected marker $expected, got $actual"
}

test_success_installs_staged_app_and_opens_final_path() {
  tmp_dir="$(mktemp -d)"
  TEST_TMP_DIRS="$TEST_TMP_DIRS $tmp_dir"

  install_app="$tmp_dir/Apps/INbox.app"
  staged_app="$tmp_dir/Apps/.INbox.app.installing.123"
  backup_app="$tmp_dir/Apps/.INbox.app.backup.123"
  log_path="$tmp_dir/install.log"
  open_log="$tmp_dir/open.log"
  fake_bin="$tmp_dir/bin"

  mkdir -p "$tmp_dir/Apps"
  write_marker "$install_app" old
  write_marker "$staged_app" new
  make_fake_open "$fake_bin" "$open_log"

  sh "$HELPER" 0 "$staged_app" "$install_app" "$backup_app" "$log_path"

  assert_marker "$install_app" new
  [ ! -e "$backup_app" ] || fail "backup should be removed after successful install"
  [ "$(cat "$open_log")" = "$install_app" ] || fail "helper did not open exact final path"
}

test_failed_final_move_restores_backup() {
  tmp_dir="$(mktemp -d)"
  TEST_TMP_DIRS="$TEST_TMP_DIRS $tmp_dir"

  install_app="$tmp_dir/Apps/INbox.app"
  staged_app="$install_app/.INbox.app.installing.456"
  backup_app="$tmp_dir/Apps/.INbox.app.backup.456"
  log_path="$tmp_dir/install.log"
  open_log="$tmp_dir/open.log"
  fake_bin="$tmp_dir/bin"

  mkdir -p "$tmp_dir/Apps"
  write_marker "$install_app" old
  write_marker "$staged_app" new
  make_fake_open "$fake_bin" "$open_log"

  if sh "$HELPER" 0 "$staged_app" "$install_app" "$backup_app" "$log_path"; then
    fail "helper should fail when final move target is blocked"
  fi

  assert_marker "$install_app" old
  [ ! -s "$open_log" ] || fail "helper should not open app after failed install"
}

test_live_pid_timeout_leaves_installed_app_unchanged() {
  tmp_dir="$(mktemp -d)"
  TEST_TMP_DIRS="$TEST_TMP_DIRS $tmp_dir"

  install_app="$tmp_dir/Apps/INbox.app"
  staged_app="$tmp_dir/Apps/.INbox.app.installing.789"
  backup_app="$tmp_dir/Apps/.INbox.app.backup.789"
  log_path="$tmp_dir/install.log"
  open_log="$tmp_dir/open.log"
  fake_bin="$tmp_dir/bin"

  mkdir -p "$tmp_dir/Apps"
  write_marker "$install_app" old
  write_marker "$staged_app" new
  make_fake_open "$fake_bin" "$open_log"

  if sh "$HELPER" "$$" "$staged_app" "$install_app" "$backup_app" "$log_path"; then
    fail "helper should fail while old pid is still alive"
  fi

  assert_marker "$install_app" old
  [ ! -e "$backup_app" ] || fail "backup should not exist after pid timeout"
  [ ! -s "$open_log" ] || fail "helper should not open app after pid timeout"
}

test_success_installs_staged_app_and_opens_final_path
test_failed_final_move_restores_backup
test_live_pid_timeout_leaves_installed_app_unchanged

echo "replace_macos_app_test.sh: all tests passed"
