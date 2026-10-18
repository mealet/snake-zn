#!/usr/bin/env sh
set -eu

VERSION="${1:?usage: install-zeen.sh <version> [prefix]}"
PREFIX="${2:-$HOME/zeen}"
TAG="v${VERSION#v}"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

curl -fsSL "https://raw.githubusercontent.com/mealet/zeen/$TAG/install.sh" -o "$TMP"
sh "$TMP" --version "$TAG" --prefix "$PREFIX"
rm -f "$TMP"

if [ -n "${GITHUB_PATH:-}" ]; then
    printf '%s\n' "$PREFIX/bin" >> "$GITHUB_PATH"
fi

if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'ZEEN_STD=%s\n' "$PREFIX/share/zeen/std" >> "$GITHUB_ENV"
fi

"$PREFIX/bin/zeen" --version
