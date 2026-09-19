#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "未找到 Swift 编译器。"
  echo "将打开 Apple Command Line Tools 安装程序；安装完成后重新运行本脚本。"
  /usr/bin/xcode-select --install >/dev/null 2>&1 || true
  read -k 1 "?按任意键关闭…"
  echo
  exit 1
fi

echo "正在编译 What File Is This…"
/usr/bin/env swift build -c release
BIN_DIR="$(/usr/bin/env swift build -c release --show-bin-path)"
BIN="$BIN_DIR/WhatFileIsThis"

if [[ ! -x "$BIN" ]]; then
  echo "编译完成，但未找到可执行文件：$BIN"
  exit 1
fi

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/What File Is This.app"
DEST="$HOME/Applications/What File Is This.app"

/bin/rm -rf "$APP"
/bin/mkdir -p "$APP/Contents/MacOS"
/bin/cp "$BIN" "$APP/Contents/MacOS/WhatFileIsThis"
/bin/chmod 755 "$APP/Contents/MacOS/WhatFileIsThis"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>What File Is This</string>
  <key>CFBundleExecutable</key>
  <string>WhatFileIsThis</string>
  <key>CFBundleIdentifier</key>
  <string>dev.is-a.zjy.whatfileisthis</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>What File Is This</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.1</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>What File Is This Result</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>dev.is-a.zjy.wfitresult</string>
      </array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>dev.is-a.zjy.wfitresult</string>
      <key>UTTypeDescription</key>
      <string>What File Is This Result</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.data</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>wfitresult</string>
        </array>
        <key>public.mime-type</key>
        <string>application/x-what-file-is-this-result</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP"
/bin/mkdir -p "$HOME/Applications"
/bin/rm -rf "$DEST"
/usr/bin/ditto "$APP" "$DEST"
/usr/bin/codesign --verify --deep --strict "$DEST"

# Register the application with Launch Services. Do not launch an empty window here;
# the Shortcut will start a fresh instance and pass the result file explicitly.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" >/dev/null 2>&1 || true

echo
echo "安装完成："
echo "$DEST"
echo
echo "安装完成。App 不会自动打开空窗口；运行 Finder 快捷指令时才会启动。"
echo "每次分析会启动一个独立结果窗口，关闭窗口后对应 App 实例自动退出。"
read -k 1 "?按任意键关闭…"
echo
