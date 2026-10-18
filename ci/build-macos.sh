#!/usr/bin/env sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=${OUT_DIR:-$ROOT/dist/release}
RAYLIB_DIR=${RAYLIB_DIR:?RAYLIB_DIR is required}
APP_VERSION=${APP_VERSION:-0.1.0}
ARCH=${ARCH:-$(uname -m)}
ZEEN=${ZEEN:-zeen}

if [ -z "${ZAYLIB_SRC:-}" ]; then
    ZAYLIB_SRC=$(cd "$ROOT" && zora --no-color deps-map | sed -n 's/^zaylib=//p')
fi

if [ -z "$ZAYLIB_SRC" ]; then
    echo "zaylib source path not found, run: zora --no-color deps-map" >&2
    exit 1
fi

BIN="$OUT_DIR/ZeenSnake"
APP="$OUT_DIR/ZeenSnake.app"
FRAMEWORK="$APP/Contents/Frameworks/libraylib.600.dylib"
BUNDLE_VERSION=$(printf '%s' "$APP_VERSION" | tr -cd '0-9.')
if [ -z "$BUNDLE_VERSION" ]; then
    BUNDLE_VERSION=0.1.0
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

(
    cd "$ROOT/src"
    "$ZEEN" main.zn "$BIN" \
        --mode Release \
        --pkg "snake=$ROOT/src" \
        --pkg "zaylib=$ZAYLIB_SRC" \
        --link raylib \
        --link-dir "$RAYLIB_DIR/lib"
)

if [ ! -x "$BIN" ]; then
    echo "macos binary was not created" >&2
    exit 1
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ZeenSnake"
cp -R "$ROOT/assets" "$APP/Contents/Resources/assets"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
cp -L "$RAYLIB_DIR/lib/libraylib.600.dylib" "$FRAMEWORK"

OLD=$(otool -L "$APP/Contents/MacOS/ZeenSnake" | awk '/libraylib/ { print $1; exit }')
if [ -z "$OLD" ]; then
    echo "raylib dylib was not linked" >&2
    exit 1
fi

install_name_tool -change "$OLD" "@executable_path/../Frameworks/libraylib.600.dylib" \
    "$APP/Contents/MacOS/ZeenSnake"
install_name_tool -id "@rpath/libraylib.600.dylib" "$FRAMEWORK"

ICONSET="$OUT_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" "$ROOT/android/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$double" "$double" "$ROOT/android/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ZeenSnake</string>
    <key>CFBundleDisplayName</key>
    <string>ZeenSnake</string>
    <key>CFBundleExecutable</key>
    <string>ZeenSnake</string>
    <key>CFBundleIdentifier</key>
    <string>com.mealet.zeensnake</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$BUNDLE_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --sign - "$FRAMEWORK"
codesign --force --deep --sign - "$APP"

if command -v lipo >/dev/null 2>&1; then
    if ! lipo -archs "$APP/Contents/MacOS/ZeenSnake" | grep -q "$ARCH"; then
        echo "macos binary does not contain $ARCH" >&2
        exit 1
    fi
fi

STAGE="$OUT_DIR/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname ZeenSnake -srcfolder "$STAGE" -ov -format UDZO \
    "$OUT_DIR/ZeenSnake-macos-$ARCH.dmg"

rm -rf "$STAGE" "$ICONSET"

echo "ZeenSnake-macos-$ARCH.dmg"
