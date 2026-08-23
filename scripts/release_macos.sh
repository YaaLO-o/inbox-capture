#!/bin/sh
#
# 构建 INbox macOS Release 并打包成可拖入 /Applications 的 DMG。
#
# 用法：
#   sh scripts/release_macos.sh [version]
#
# 产物：
#   dist/INbox-<version>-macos-universal.dmg
#
# 说明：
# - flutter build macos --release 默认产出 universal binary（arm64 + x86_64）。
# - 当前未使用 Apple Developer ID，app 仅 ad-hoc 签名；首次打开会被 Gatekeeper
#   拦截，详见 .github/DOWNLOAD.md。

set -eu

VERSION=${1:-0.1.0}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")
APP_DIR="$REPO_DIR/app"
DIST_DIR="$REPO_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_NAME="INbox"
RELEASE_APP="$APP_DIR/build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-macos-universal.dmg"
VOL_NAME="${APP_NAME}"

if [ ! -d "$APP_DIR" ]; then
  echo "App directory not found: $APP_DIR" >&2
  exit 1
fi

echo "==> flutter pub get"
(cd "$APP_DIR" && flutter pub get >/dev/null)

echo "==> flutter build macos --release (universal)"
(cd "$APP_DIR" && flutter build macos --release)

if [ ! -d "$RELEASE_APP" ]; then
  echo "Release app not found after build: $RELEASE_APP" >&2
  exit 1
fi

echo "==> ad-hoc codesign (兜底，未使用 Developer ID)"
# --deep 已弃用但仍可用；Flutter 内嵌 framework 默认已签名，这里强制统一。
codesign --force --deep --sign - "$RELEASE_APP" >/dev/null 2>&1 || true
codesign --verify "$RELEASE_APP" >/dev/null 2>&1 || true

echo "==> preparing DMG staging"
/bin/rm -rf "$STAGING_DIR"
/bin/rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"
/bin/cp -R "$RELEASE_APP" "$STAGING_DIR/${APP_NAME}.app"
# /Applications 符号链接，让用户拖拽安装
ln -s /Applications "$STAGING_DIR/Applications"

# 给 DMG 卷宗设置 app 图标（.VolumeIcon.icns）。
ICON_SRC="$APP_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
ICONSET=$(mktemp -d)/AppIcon.iconset
if [ -f "$ICON_SRC" ]; then
  mkdir -p "$ICONSET"
  sips -z 16 16     "$ICON_SRC" --out "$ICONSET/icon_16x16.png"         >/dev/null 2>&1 || true
  sips -z 32 32     "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png"      >/dev/null 2>&1 || true
  sips -z 32 32     "$ICON_SRC" --out "$ICONSET/icon_32x32.png"         >/dev/null 2>&1 || true
  sips -z 64 64     "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png"      >/dev/null 2>&1 || true
  sips -z 128 128   "$ICON_SRC" --out "$ICONSET/icon_128x128.png"       >/dev/null 2>&1 || true
  sips -z 256 256   "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png"    >/dev/null 2>&1 || true
  sips -z 256 256   "$ICON_SRC" --out "$ICONSET/icon_256x256.png"       >/dev/null 2>&1 || true
  sips -z 512 512   "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png"    >/dev/null 2>&1 || true
  sips -z 512 512   "$ICON_SRC" --out "$ICONSET/icon_512x512.png"       >/dev/null 2>&1 || true
  sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png"    >/dev/null 2>&1 || true
  if iconutil -c icns "$ICONSET" -o "$STAGING_DIR/.VolumeIcon.icns" >/dev/null 2>&1; then
    # SetFile 已弃用；用隐藏属性让卷宗显示自定义图标。
    SetFile -a C "$STAGING_DIR" >/dev/null 2>&1 || true
  fi
fi

echo "==> creating DMG: $DMG_PATH"
mkdir -p "$DIST_DIR"
hdiutil create \
  -volname "$VOL_NAME" \
  -fs HFS+ \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH" >/dev/null

echo "==> cleaning staging"
/bin/rm -rf "$STAGING_DIR"

# 架构与校验信息
ARCHS=$(lipo -archs "$RELEASE_APP/Contents/MacOS/${APP_NAME}" 2>/dev/null || echo "unknown")
SIZE=$(du -h "$DMG_PATH" | cut -f1)
SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)

echo ""
echo "==> Done"
echo "    DMG : $DMG_PATH ($SIZE)"
echo "    Arch: $ARCHS"
echo "    SHA256: $SHA256"
