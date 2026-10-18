#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SDK=${ANDROID_HOME:-$HOME/android/sdk}
NDK=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-$SDK/ndk/29.0.14206865}}
if [ -z "${ANDROID_BUILD_TOOLS:-}" ]; then
    BUILD_TOOLS=$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)
else
    BUILD_TOOLS=$ANDROID_BUILD_TOOLS
fi
JAVA_HOME=${JAVA_HOME:-$HOME/android/jdk}
RAYLIB=${RAYLIB_ANDROID:-$HOME/android/raylib/src/libraylib.a}
OUT=$ROOT/build/android
APP=$OUT/apk
APK_NAME=${APK_NAME:-snake}
APP_VERSION_CODE=${APP_VERSION_CODE:-1}
APP_VERSION_NAME=${APP_VERSION_NAME:-0.1.0}
KEYSTORE=${ANDROID_KEYSTORE:-$ROOT/android/debug.keystore}
KEY_ALIAS=${ANDROID_KEY_ALIAS:-snake}
CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang

export PATH=$JAVA_HOME/bin:$PATH

ZAYLIB=${ZAYLIB_SRC:-$(cd "$ROOT" && zora --no-color deps-map | sed -n 's/^zaylib=//p')}
if [ -z "$ZAYLIB" ]; then
    echo "zaylib source path not found, run: zora --no-color deps-map" >&2
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
    --version-code "$APP_VERSION_CODE" --version-name "$APP_VERSION_NAME"

(cd "$APP" && zip -q -0 -r "$OUT/unsigned.apk" lib)

"$BUILD_TOOLS/zipalign" -f -P 16 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

if [ ! -f "$KEYSTORE" ]; then
    keytool -genkeypair -keystore "$KEYSTORE" -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass android -keypass android -dname "CN=ZeenSnake"
fi

"$BUILD_TOOLS/apksigner" sign --ks "$KEYSTORE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass pass:android --key-pass pass:android \
    --min-sdk-version 29 \
    --out "$ROOT/dist/$APK_NAME.apk" "$OUT/aligned.apk"

echo "APK: $ROOT/dist/$APK_NAME.apk"

if [ "${1:-}" = "install" ]; then
    "$SDK/platform-tools/adb" install -r "$ROOT/dist/$APK_NAME.apk"
fi
