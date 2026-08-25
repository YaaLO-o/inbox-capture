#!/bin/sh
#
# INbox 一键安装脚本（macOS）
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/YaaLO-o/inbox-capture/main/scripts/install.sh | sh
#
# 为什么用脚本而不是浏览器下载 DMG：
#   curl 下载的文件不会被浏览器附加 com.apple.quarantine 隔离标记，
#   配合 ditto 安装，App 首次打开不会被 Gatekeeper 拦截
#   （当前版本为 ad-hoc 签名，未做 Apple Developer ID 公证）。
#
# 这与 Homebrew 的 `brew install --no-quarantine` 是同样的原理。

set -eu

APP_NAME="INbox"
REPO="YaaLO-o/inbox-capture"
INSTALL_DIR="${INBOX_INSTALL_DIR:-/Applications}"
case "$INSTALL_DIR" in
  */) INSTALL_DIR="${INSTALL_DIR%/}" ;;
esac

if [ -z "$INSTALL_DIR" ] || [ "$INSTALL_DIR" = "/" ]; then
  echo "❌ 安装目录不安全：$INSTALL_DIR" >&2
  exit 64
fi

APP_PATH="$INSTALL_DIR/${APP_NAME}.app"
STAGED_APP="$INSTALL_DIR/.${APP_NAME}.app.installing.$$"
BACKUP_APP="$INSTALL_DIR/.${APP_NAME}.app.backup.$$"
# 固定文件名资产，始终指向最新 Release
DMG_URL="${INBOX_DMG_URL:-https://github.com/${REPO}/releases/latest/download/${APP_NAME}-macos-universal.dmg}"
COMMAND_DIR="${INBOX_COMMAND_DIR:-}"

command_path() {
  name="$1"
  default_path="$2"
  if [ -n "$COMMAND_DIR" ]; then
    printf '%s/%s\n' "$COMMAND_DIR" "$name"
  else
    printf '%s\n' "$default_path"
  fi
}

UNAME=$(command_path uname /usr/bin/uname)
CURL=$(command_path curl /usr/bin/curl)
HDIUTIL=$(command_path hdiutil /usr/bin/hdiutil)
DITTO=$(command_path ditto /usr/bin/ditto)
PS=$(command_path ps /bin/ps)
KILL=$(command_path kill /bin/kill)
SLEEP=$(command_path sleep /bin/sleep)
MV=$(command_path mv /bin/mv)
RM=$(command_path rm /bin/rm)
OPEN=$(command_path open /usr/bin/open)
LSREGISTER=$(command_path lsregister /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister)

INSTALL_TMP_DIR=$(mktemp -d)
DMG_PATH="$INSTALL_TMP_DIR/${APP_NAME}.dmg"
INSTALL_LOG="$INSTALL_TMP_DIR/install.log"
MOUNT_DIR=""
INSTALL_COMPLETE=0

warn() {
  echo "⚠️  $*" >&2
}

safe_remove_generated() {
  path="$1"
  [ -e "$path" ] || return 0

  parent="${path%/*}"
  base="${path##*/}"
  if [ "$parent" != "$INSTALL_DIR" ]; then
    warn "拒绝清理非安装目录中的路径：$path"
    return 1
  fi

  case "$base" in
    .INbox.app.installing.[0-9]*|.INbox.app.backup.[0-9]*)
      "$RM" -rf -- "$path"
      ;;
    *)
      warn "拒绝清理非脚本生成的路径：$path"
      return 1
      ;;
  esac
}

safe_remove_tmp_dir() {
  case "$INSTALL_TMP_DIR" in
    /tmp/*|/var/folders/*)
      /bin/rm -rf "$INSTALL_TMP_DIR"
      ;;
    *)
      warn "拒绝清理异常临时目录：$INSTALL_TMP_DIR"
      ;;
  esac
}

cleanup() {
  exit_status=$?
  trap - EXIT INT TERM

  if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
    "$HDIUTIL" detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi

  if [ "$INSTALL_COMPLETE" -ne 1 ] && [ ! -e "$APP_PATH" ] && [ -e "$BACKUP_APP" ]; then
    if "$MV" "$BACKUP_APP" "$APP_PATH" >/dev/null 2>&1; then
      warn "已恢复旧版 INbox。"
    else
      warn "恢复旧版失败，请检查：$BACKUP_APP"
    fi
  fi

  if [ -e "$STAGED_APP" ]; then
    safe_remove_generated "$STAGED_APP" || true
  fi

  if [ "$INSTALL_COMPLETE" -eq 1 ] && [ -e "$BACKUP_APP" ]; then
    safe_remove_generated "$BACKUP_APP" || true
  fi

  safe_remove_tmp_dir
  exit "$exit_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

find_running_inbox_pids() {
  process_list="$INSTALL_TMP_DIR/processes.$$"
  if ! "$PS" -axww -o pid=,command= > "$process_list"; then
    return 1
  fi

  while IFS= read -r line; do
    trimmed_line=$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]+//')
    pid="${trimmed_line%%[!0-9]*}"

    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac

    command_text="${trimmed_line#"$pid"}"
    command_text=$(printf '%s\n' "$command_text" | sed -E 's/^[[:space:]]+//')

    case "$command_text" in
      *"/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"|*"/${APP_NAME}.app/Contents/MacOS/${APP_NAME} "*)
        printf '%s\n' "$pid"
        ;;
    esac
  done < "$process_list"
}

request_running_inbox_to_quit() {
  if ! pids="$(find_running_inbox_pids)"; then
    echo "❌ 无法枚举运行中的 INbox 进程，已停止安装以保护现有 App。" >&2
    return 1
  fi
  [ -n "$pids" ] || return 0

  echo "⏸  正在请求运行中的 INbox 退出…"
  for pid in $pids; do
    "$KILL" -TERM "$pid" >/dev/null 2>&1 || true
  done

  attempt=1
  while [ "$attempt" -le 10 ]; do
    if ! remaining="$(find_running_inbox_pids)"; then
      echo "❌ 无法确认 INbox 进程是否已退出，已停止安装以保护现有 App。" >&2
      return 1
    fi
    [ -z "$remaining" ] && return 0
    "$SLEEP" 1
    attempt=$((attempt + 1))
  done

  if ! remaining="$(find_running_inbox_pids)"; then
    echo "❌ 无法确认 INbox 进程是否已退出，已停止安装以保护现有 App。" >&2
    return 1
  fi
  if [ -n "$remaining" ]; then
    echo "❌ INbox 仍在运行，已停止安装以保护现有 App。" >&2
    echo "$remaining" | while IFS= read -r pid; do
      [ -n "$pid" ] && echo "   未退出的进程 PID：$pid" >&2
    done
    return 1
  fi

  return 0
}

# 仅支持 macOS
if [ "$("$UNAME" -s)" != "Darwin" ]; then
  echo "❌ INbox 目前仅支持 macOS。" >&2
  exit 1
fi

if [ ! -d "$INSTALL_DIR" ]; then
  echo "❌ 安装目录不存在：$INSTALL_DIR" >&2
  exit 1
fi

if ! [ -w "$INSTALL_DIR" ]; then
  echo "" >&2
  echo "⚠️  没有 $INSTALL_DIR 的写入权限。" >&2
  echo "   请在有权限的账户中运行安装脚本。" >&2
  exit 1
fi

safe_remove_generated "$STAGED_APP"
safe_remove_generated "$BACKUP_APP"

echo "🦊 正在下载 INbox…"
# -f 失败返回错误码，-L 跟随重定向
# 不加 -s：让 curl 显示实时进度条（速度、百分比、剩余时间）
if ! "$CURL" -fL --progress-bar -o "$DMG_PATH" "$DMG_URL"; then
  echo "❌ 下载失败：$DMG_URL" >&2
  exit 1
fi

echo "📦 下载完成，正在挂载磁盘映像…"
# -nobrowse 不在 Finder 显示，-readonly 只读挂载
MOUNT_OUT=$("$HDIUTIL" attach -nobrowse -readonly "$DMG_PATH" 2>&1) || {
  echo "❌ 无法挂载 DMG" >&2
  echo "$MOUNT_OUT" >&2
  exit 1
}
MOUNT_DIR=$(printf '%s\n' "$MOUNT_OUT" | sed -nE 's/.*Apple_[^[:space:]]+[[:space:]]+(.+)$/\1/p' | tail -1)
if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
  echo "❌ 无法挂载 DMG" >&2
  echo "$MOUNT_OUT" >&2
  exit 1
fi

SRC_APP="$MOUNT_DIR/${APP_NAME}.app"
if [ ! -d "$SRC_APP" ]; then
  echo "❌ DMG 中未找到 ${APP_NAME}.app" >&2
  exit 1
fi

echo "📦 正在暂存 INbox 到 $STAGED_APP …"
# 用 ditto 而不是 cp -R：ditto 保留 bundle 结构，且不会在复制时附加 quarantine
if ! "$DITTO" "$SRC_APP" "$STAGED_APP" 2>"$INSTALL_LOG"; then
  echo "❌ 暂存 INbox 失败。" >&2
  cat "$INSTALL_LOG" >&2
  exit 1
fi

"$HDIUTIL" detach "$MOUNT_DIR" >/dev/null 2>&1 || true
MOUNT_DIR=""

request_running_inbox_to_quit || exit 1

echo "📂 正在安装到 $APP_PATH …"
if [ -e "$APP_PATH" ]; then
  if ! "$MV" "$APP_PATH" "$BACKUP_APP" 2>>"$INSTALL_LOG"; then
    echo "❌ 无法备份旧版 INbox。" >&2
    cat "$INSTALL_LOG" >&2
    exit 1
  fi
fi

if ! "$MV" "$STAGED_APP" "$APP_PATH" 2>>"$INSTALL_LOG"; then
  echo "❌ 无法把新版 INbox 移动到正式位置，正在回滚。" >&2
  cat "$INSTALL_LOG" >&2
  exit 1
fi

INSTALL_COMPLETE=1

if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$APP_PATH" >/dev/null 2>&1 || true
fi

if [ -e "$BACKUP_APP" ]; then
  safe_remove_generated "$BACKUP_APP"
fi

echo ""
echo "✅ INbox 已安装到 $APP_PATH"
echo ""
echo "   首次启动：在「应用程序」里双击 INbox，或运行：open \"$APP_PATH\""
echo "   （若仍被 Gatekeeper 提示，右键 → 打开；正常情况下用本脚本安装不会有该提示）"
echo ""

if [ "${INBOX_SKIP_OPEN:-0}" = "1" ]; then
  echo "已跳过自动启动。"
else
  "$OPEN" "$APP_PATH"
  echo "已启动 INbox！"
fi
