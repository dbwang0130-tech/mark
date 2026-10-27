#!/bin/bash
# 构建并安装 Mark（Markdown 阅读器 + Quick Look 扩展）到 /Applications
set -euo pipefail
cd "$(dirname "$0")"

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT=build/DerivedData/Build/Products/Release/Mark.app
DEST=/Applications/Mark.app
EXT_ID=com.markdownext.Mark.QuickLook

xcodegen generate --quiet
# xcodegen 不认识 Icon Composer 的 .icon 格式，改成 Xcode 使用的文件类型
sed -i '' 's/lastKnownFileType = wrapper.icon;/lastKnownFileType = folder.iconcomposer.icon;/' Mark.xcodeproj/project.pbxproj
LOG=build/xcodebuild.log
mkdir -p build
if ! env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy -u ALL_PROXY -u all_proxy \
  xcodebuild -project Mark.xcodeproj -scheme Mark -configuration Release \
  -derivedDataPath build/DerivedData build > "$LOG" 2>&1; then
  grep -E "error:" "$LOG" | sort -u
  echo "构建失败，未安装（完整日志：$LOG）"
  exit 1
fi

# 只让 /Applications 里的副本生效，避免系统选中构建目录中的拷贝
"$LSREGISTER" -u "$BUILT" 2>/dev/null || true
pluginkit -r "$BUILT/Contents/PlugIns/MarkQuickLook.appex" 2>/dev/null || true

# 正在运行的旧版本不会自动更新，安装前先正常退出
osascript -e 'tell application id "com.markdownext.Mark" to quit' 2>/dev/null || true
for _ in 1 2 3 4 5; do pgrep -f "$DEST/Contents/MacOS/" >/dev/null || break; sleep 1; done

rm -rf "$DEST"
ditto "$BUILT" "$DEST"
"$LSREGISTER" -f -R "$DEST"
pluginkit -a "$DEST/Contents/PlugIns/MarkQuickLook.appex"
pluginkit -e use -i "$EXT_ID"
pkill -f MarkQuickLook 2>/dev/null || true
qlmanage -r >/dev/null 2>&1
echo "已安装：$DEST"
pluginkit -m -v -i "$EXT_ID"
