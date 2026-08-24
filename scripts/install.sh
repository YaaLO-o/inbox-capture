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
INSTALL_DIR="/Applications"
APP_PATH="$INSTALL_DIR/${APP_NAME}.app"
# 固定文件名资产，始终指向最新 Release
DMG_URL="https://github.com/${REPO}/releases/latest/download/${APP_NAME}-macos-universal.dmg"

TMPDIR=$(mktemp -d)
DMG_PATH="$TMPDIR/${APP_NAME}.dmg"
MOUNT_DIR=""

cleanup() {
  if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMPDIR"
}
trap cleanup EXIT INT TERM

# 仅支持 macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "❌ INbox 目前仅支持 macOS。" >&2
  exit 1
fi

echo "🦊 正在下载 INbox…"
# -f 失败返回错误码，-L 跟随重定向
# 不加 -s：让 curl 显示实时进度条（速度、百分比、剩余时间）
if ! curl -fL --progress-bar -o "$DMG_PATH" "$DMG_URL"; then
  echo "❌ 下载失败：$DMG_URL" >&2
  exit 1
fi

echo "📦 下载完成，正在挂载磁盘映像…"
# -nobrowse 不在 Finder 显示，-readonly 只读挂载
MOUNT_OUT=$(hdiutil attach -nobrowse -readonly "$DMG_PATH" 2>&1)
MOUNT_DIR=$(echo "$MOUNT_OUT" | grep "Apple_HFS" | sed -E 's/.*Apple_HFS[[:space:]]+//' | tail -1)
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

# 如果旧版正在运行，尝试正常退出
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "⏸  正在退出运行中的 INbox…"
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
fi

echo "📂 正在安装到 $APP_PATH …"
# 如果已有旧版，先删除
if [ -d "$APP_PATH" ]; then
  rm -rf "$APP_PATH"
fi

# 用 ditto 而不是 cp -R：ditto 保留 bundle 结构，且不会在复制时附加 quarantine
if ! ditto "$SRC_APP" "$APP_PATH" 2>/tmp/inbox-install-err; then
  # /Applications 无写权限时（其他用户账号管理的 Mac），提示用户
  if ! [ -w "$INSTALL_DIR" ]; then
    echo ""
    echo "⚠️  没有 $INSTALL_DIR 的写入权限。" >&2
    echo "   请运行：sudo cp -R \"$SRC_APP\" \"$APP_PATH\"" >&2
  else
    cat /tmp/inbox-install-err >&2
  fi
  exit 1
fi

hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
MOUNT_DIR=""

echo ""
echo "✅ INbox 已安装到 $APP_PATH"
echo ""
echo "   首次启动：在「应用程序」里双击 INbox，或运行：open -a $APP_NAME"
echo "   （若仍被 Gatekeeper 提示，右键 → 打开；正常情况下用本脚本安装不会有该提示）"
echo ""

# 询问是否立即启动（从 /dev/tty 读取，兼容 curl | sh 管道模式）
if [ -e /dev/tty ]; then
  printf "🚀 现在启动 INbox？[Y/n] "
  read -r answer < /dev/tty
  case "$answer" in
    [nN]*) echo "好的，你可以稍后在 Applications 里打开。" ;;
    *) open -a "$APP_NAME" && echo "已启动！" ;;
  esac
else
  open -a "$APP_NAME" && echo "已启动 INbox！"
fi
