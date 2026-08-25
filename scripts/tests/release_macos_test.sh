#!/bin/sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TEST_TMP_ROOT=$(mktemp -d)
FAILURES=0

cleanup_tests() {
  case "$TEST_TMP_ROOT" in
    /tmp/*|/var/folders/*)
      /bin/rm -rf "$TEST_TMP_ROOT"
      ;;
    *)
      printf '%s\n' "refusing to remove unexpected test directory: $TEST_TMP_ROOT" >&2
      ;;
  esac
}
trap cleanup_tests EXIT INT TERM

fail() {
  printf '%s\n' "FAIL: $1" >&2
  return 1
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

make_fake_command_dir() {
  test_dir="$1"
  command_dir="$test_dir/bin"
  mkdir -p "$command_dir"

  cat > "$command_dir/flutter" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "flutter:$*" >> "$INBOX_RELEASE_FAKE_EVENTS"
case "$1 $2" in
  "pub get")
    ;;
  "build macos")
    app_dir="$PWD/build/macos/Build/Products/Release/INbox.app"
    mkdir -p "$app_dir/Contents/MacOS"
    printf '%s\n' '#!/bin/sh' > "$app_dir/Contents/MacOS/INbox"
    chmod +x "$app_dir/Contents/MacOS/INbox"
    cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>${INBOX_FAKE_BUNDLE_VERSION:-1.1.1}</string>
  <key>CFBundleVersion</key>
  <string>${INBOX_FAKE_BUILD_NUMBER:-2}</string>
</dict>
</plist>
PLIST
    ;;
  *)
    exit 64
    ;;
esac
EOF

  cat > "$command_dir/codesign" <<'EOF'
#!/bin/sh
exit 0
EOF

  cat > "$command_dir/lipo" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "${INBOX_FAKE_ARCHS:-arm64 x86_64}"
EOF

  cat > "$command_dir/hdiutil" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "hdiutil:$*" >> "$INBOX_RELEASE_FAKE_EVENTS"
if [ "$1" = "create" ]; then
  out=""
  for arg in "$@"; do
    out="$arg"
  done
  mkdir -p "$(dirname "$out")"
  printf '%s\n' fake-dmg > "$out"
fi
EOF

  cat > "$command_dir/sips" <<'EOF'
#!/bin/sh
exit 0
EOF

  cat > "$command_dir/iconutil" <<'EOF'
#!/bin/sh
set -eu
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    out="$1"
  fi
  shift || break
done
[ -n "$out" ] && printf '%s\n' fake-icon > "$out"
EOF

  cat > "$command_dir/SetFile" <<'EOF'
#!/bin/sh
exit 0
EOF

  chmod +x "$command_dir"/*
  printf '%s\n' "$command_dir"
}

make_fixture() {
  tmp_dir="$(mktemp -d "$TEST_TMP_ROOT/fixture.XXXXXX")"
  mkdir -p "$tmp_dir/repo/scripts" "$tmp_dir/repo/app"
  /bin/cp "$ROOT_DIR/scripts/release_macos.sh" "$tmp_dir/repo/scripts/release_macos.sh"
  : > "$tmp_dir/events.log"
  make_fake_command_dir "$tmp_dir" > "$tmp_dir/command_dir.txt"
  printf '%s\n' "$tmp_dir"
}

run_release() {
  tmp_dir="$1"
  shift
  stdout="$tmp_dir/stdout.log"
  stderr="$tmp_dir/stderr.log"
  command_dir="$(cat "$tmp_dir/command_dir.txt")"
  INBOX_RELEASE_FAKE_EVENTS="$tmp_dir/events.log" \
  INBOX_FAKE_BUNDLE_VERSION="${INBOX_FAKE_BUNDLE_VERSION:-1.1.1}" \
  INBOX_FAKE_BUILD_NUMBER="${INBOX_FAKE_BUILD_NUMBER:-2}" \
  INBOX_FAKE_ARCHS="${INBOX_FAKE_ARCHS:-arm64 x86_64}" \
  PATH="$command_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
  sh "$tmp_dir/repo/scripts/release_macos.sh" "$@" > "$stdout" 2> "$stderr"
}

test_requires_explicit_version_argument() {
  tmp_dir="$(make_fixture)"
  if run_release "$tmp_dir"; then
    fail "release script should fail without an explicit version"
  fi

  assert_contains "$tmp_dir/stderr.log" "Usage: sh scripts/release_macos.sh <version>" "usage should explain the required version argument"
}

test_passes_release_metadata_to_flutter_build() {
  tmp_dir="$(make_fixture)"
  run_release "$tmp_dir" 1.1.1

  assert_contains "$tmp_dir/events.log" "flutter:build macos --release --build-name 1.1.1 --build-number 2" "flutter build should receive release metadata"
}

test_rejects_bundle_version_mismatch() {
  tmp_dir="$(make_fixture)"
  INBOX_FAKE_BUNDLE_VERSION=1.1.0 run_release "$tmp_dir" 1.1.1 && fail "release script should reject a mismatched bundle version"

  assert_not_exists "$tmp_dir/repo/dist/INbox-1.1.1-macos-universal.dmg" "release script should stop before creating the versioned DMG"
}

test_rejects_missing_intel_architecture() {
  tmp_dir="$(make_fixture)"
  INBOX_FAKE_ARCHS=arm64 run_release "$tmp_dir" 1.1.1 && fail "release script should reject a non-universal binary"

  assert_not_exists "$tmp_dir/repo/dist/INbox-1.1.1-macos-universal.dmg" "release script should stop before creating the versioned DMG"
}

run_test test_requires_explicit_version_argument
run_test test_passes_release_metadata_to_flutter_build
run_test test_rejects_bundle_version_mismatch
run_test test_rejects_missing_intel_architecture

if [ "$FAILURES" -ne 0 ]; then
  printf '%s\n' "release_macos_test.sh: $FAILURES failure(s)" >&2
  exit 1
fi

printf '%s\n' "release_macos_test.sh: all tests passed"
