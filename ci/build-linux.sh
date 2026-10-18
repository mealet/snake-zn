#!/usr/bin/env sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=${OUT_DIR:-$ROOT/dist/release}
RAYLIB_DIR=${RAYLIB_DIR:?RAYLIB_DIR is required}
APP_VERSION=${APP_VERSION:-0.1.0}
ZEEN=${ZEEN:-zeen}

if [ -z "${ZAYLIB_SRC:-}" ]; then
    ZAYLIB_SRC=$(cd "$ROOT" && zora --no-color deps-map | sed -n 's/^zaylib=//p')
fi

if [ -z "$ZAYLIB_SRC" ]; then
    echo "zaylib source path not found, run: zora --no-color deps-map" >&2
    exit 1
fi

BIN="$OUT_DIR/ZeenSnake"
STATIC_LIB_DIR="$OUT_DIR/lib-static"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$STATIC_LIB_DIR"

cp "$RAYLIB_DIR/lib/libraylib.a" "$STATIC_LIB_DIR/libraylib.a"

(
    cd "$ROOT/src"
    "$ZEEN" main.zn "$BIN" \
        --mode Release \
        --pkg "snake=$ROOT/src" \
        --pkg "zaylib=$ZAYLIB_SRC" \
        --link raylib \
        --link m \
        --link pthread \
        --link dl \
        --link rt \
        --link GL \
        --link X11 \
        --link-dir "$STATIC_LIB_DIR"
)

if [ ! -x "$BIN" ]; then
    echo "linux binary was not created" >&2
    exit 1
fi

if ldd "$BIN" | grep -q "not found"; then
    ldd "$BIN" | grep "not found" >&2
    exit 1
fi

if command -v strip >/dev/null 2>&1; then
    strip "$BIN"
fi

cp "$BIN" "$OUT_DIR/ZeenSnake-linux-x86_64"

PKG="$OUT_DIR/pkg/ZeenSnake"
mkdir -p "$PKG"
cp "$BIN" "$PKG/ZeenSnake"
cp -R "$ROOT/assets" "$PKG/assets"
cp "$ROOT/LICENSE" "$ROOT/README.md" "$PKG/"
tar -czf "$OUT_DIR/ZeenSnake-linux-x86_64.tar.gz" -C "$OUT_DIR/pkg" ZeenSnake

APPDIR="$OUT_DIR/AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/512x512/apps"
cp "$BIN" "$APPDIR/usr/bin/ZeenSnake"
cp -R "$ROOT/assets" "$APPDIR/usr/bin/assets"
cp "$ROOT/android/icon.png" "$APPDIR/zeensnake.png"
cp "$ROOT/android/icon.png" "$APPDIR/.DirIcon"
cp "$ROOT/android/icon.png" "$APPDIR/usr/share/icons/hicolor/512x512/apps/zeensnake.png"

cat > "$APPDIR/zeensnake.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=ZeenSnake
Comment=Snake game made with Zeen
Exec=ZeenSnake
Icon=zeensnake
Categories=Game;
Terminal=false
EOF

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/ZeenSnake" "$@"
EOF

chmod +x "$APPDIR/AppRun"
cp "$APPDIR/zeensnake.desktop" "$APPDIR/usr/share/applications/zeensnake.desktop"

TOOL=${APPIMAGETOOL:-${RUNNER_TEMP:-/tmp}/appimagetool-x86_64.AppImage}
if [ ! -x "$TOOL" ]; then
    curl -fsSL --retry 3 -o "$TOOL" \
        https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x "$TOOL"
fi

ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 VERSION="$APP_VERSION" \
    "$TOOL" "$APPDIR" "$OUT_DIR/ZeenSnake-linux-x86_64.AppImage"

rm -rf "$STATIC_LIB_DIR" "$OUT_DIR/AppDir"

echo "ZeenSnake-linux-x86_64"
echo "ZeenSnake-linux-x86_64.tar.gz"
echo "ZeenSnake-linux-x86_64.AppImage"
