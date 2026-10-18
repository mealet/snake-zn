#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SDK=${ANDROID_HOME:-$HOME/android/sdk}
NDK=${ANDROID_NDK_HOME:-$SDK/ndk/29.0.14206865}
BUILD_TOOLS=${ANDROID_BUILD_TOOLS:-$SDK/build-tools/36.1.0}
JAVA_HOME=${JAVA_HOME:-$HOME/android/jdk}
RAYLIB=${RAYLIB_ANDROID:-$HOME/android/raylib/src/libraylib.a}
OUT=$ROOT/build/android
APP=$OUT/apk
CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang

export PATH=$JAVA_HOME/bin:$PATH

ZAYLIB=$(cd "$ROOT" && zora deps-map | sed -n 's/^zaylib=//p')
if [ -z "$ZAYLIB" ]; then
    echo "zaylib source path not found, run: zora deps-map" >&2
    exit 1
fi

if [ ! -f "$RAYLIB" ]; then
    echo "raylib for android not found at $RAYLIB" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/assets/assets" "$APP/lib/arm64-v8a" "$APP/res/mipmap-xxxhdpi" "$ROOT/dist"
cp -r "$ROOT/assets/." "$APP/assets/assets/"
cp "$ROOT/android/icon.png" "$APP/res/mipmap-xxxhdpi/ic_launcher.png"

(cd "$ROOT/src" && zeen main.zn "$OUT/snake" \
    --target aarch64-linux-android --mode Release --emit OBJ \
    --pkg "snake=$ROOT/src" --pkg "zaylib=$ZAYLIB")

"$CC" -shared -o "$APP/lib/arm64-v8a/libsnake.so" "$OUT/snake.o" "$RAYLIB" \
    -Wl,-soname,libsnake.so \
    -u ANativeActivity_onCreate \
    -Wl,--wrap=fopen \
    -Wl,-z,max-page-size=16384 \
    -Wl,--no-undefined \
    -llog -landroid -lEGL -lGLESv2 -lOpenSLES -ldl -lm

"$BUILD_TOOLS/aapt2" compile --dir "$APP/res" -o "$OUT/res.zip"

"$BUILD_TOOLS/aapt2" link -o "$OUT/unsigned.apk" \
    -I "$SDK/platforms/android-36/android.jar" \
    --manifest "$ROOT/android/AndroidManifest.xml" \
    -A "$APP/assets" \
    --no-compress-fonts \
    "$OUT/res.zip" \
    --min-sdk-version 29 --target-sdk-version 36 \
    --version-code 1 --version-name 0.1.0

(cd "$APP" && zip -q -0 -r "$OUT/unsigned.apk" lib)

"$BUILD_TOOLS/zipalign" -f -P 16 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

if [ ! -f "$ROOT/android/debug.keystore" ]; then
    keytool -genkeypair -keystore "$ROOT/android/debug.keystore" -alias snake \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass android -keypass android -dname "CN=Zeen Snake"
fi

"$BUILD_TOOLS/apksigner" sign --ks "$ROOT/android/debug.keystore" \
    --ks-pass pass:android --key-pass pass:android \
    --min-sdk-version 29 \
    --out "$ROOT/dist/snake.apk" "$OUT/aligned.apk"

echo "APK: $ROOT/dist/snake.apk"

if [ "${1:-}" = "install" ]; then
    "$SDK/platform-tools/adb" install -r "$ROOT/dist/snake.apk"
fi
