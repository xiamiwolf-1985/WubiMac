#!/bin/bash
set -e

echo "=== WubiMac 五笔输入法构建脚本 ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── 1. 检查 XcodeGen ──
XCODEGEN="$(which xcodegen 2>/dev/null || echo /opt/homebrew/bin/xcodegen)"
if [ ! -x "$XCODEGEN" ]; then
    echo "⚙️  安装 XcodeGen..."
    brew install xcodegen
    XCODEGEN="$(which xcodegen)"
fi

# ── 2. 清理 ──
echo "🧹 清理旧构建..."
if [ ! -w WubiMac.xcodeproj ] || [ ! -w .build ] 2>/dev/null; then
    echo "⚠️  检测到工程缓存目录权限异常，跳过清理。"
else
    rm -rf WubiMac.xcodeproj .build
fi
rm -rf ~/Library/Developer/Xcode/DerivedData/WubiMac-* 2>/dev/null || true

# ── 3. 生成并编译 ──
echo "⚙️  生成 Xcode 项目..."
"$XCODEGEN" generate

echo "🏗️  编译 (Release, arm64)..."
xcodebuild \
    -project WubiMac.xcodeproj \
    -scheme WubiMac \
    -configuration Release \
    -derivedDataPath .build/DerivedData \
    -destination "platform=macOS,arch=arm64" \
    MACOSX_DEPLOYMENT_TARGET=13.0 \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    ONLY_ACTIVE_ARCH=YES \
    2>&1 | tail -3

# ── 4. 验证 ──
APP=".build/DerivedData/Build/Products/Release/WubiMac.app"
if [ ! -f "$APP/Contents/MacOS/WubiMac" ]; then
    echo "❌ 构建失败"; exit 1
fi

echo "=== 签名 ==="
# 使用之前创建的本地证书签名
codesign --force --deep --sign "WubiMac Dev Certificate" "$APP" 2>/dev/null || codesign --force --deep --sign "-" "$APP"

# 验证 plist
CONN=$(/usr/libexec/PlistBuddy -c "Print :InputMethodConnectionName" "$APP/Contents/Info.plist" 2>/dev/null || echo "")
if [ -z "$CONN" ]; then
    echo "❌ Info.plist 缺少 InputMethodConnectionName！"; exit 1
fi
echo "✅ 编译成功 (ConnectionName: $CONN)"

# ── 5. 安装 ──
INSTALL_TARGET="/Library/Input Methods/WubiMac.app"
if [ -t 0 ] && [ -t 1 ]; then
    echo "📦 安装..."
    sudo rm -rf "$INSTALL_TARGET"
    sudo cp -R "$APP" "$INSTALL_TARGET"
    sudo xattr -rd com.apple.quarantine "$INSTALL_TARGET" 2>/dev/null || true

    # ── 6. 注册 ──
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_TARGET"
    killall WubiMac 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true

    echo ""
    echo "✅ 安装成功！请在 系统设置 → 键盘 → 输入法 → ＋ → 简体中文 中添加「五笔输入法」"
else
    echo ""
    echo "⚠️  当前不是交互式终端，已跳过安装。"
    echo "   如需安装，请在终端运行：sudo ./build.sh"
fi
