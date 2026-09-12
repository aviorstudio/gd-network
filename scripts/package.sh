#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$ROOT_DIR/addon/package-manifest.txt"
dist="$ROOT_DIR/dist"
stage="$(mktemp -d)"
declared="$(mktemp)"
actual="$(mktemp)"
trap 'rm -rf "$stage"; rm -f "$declared" "$actual"' EXIT

test -f "$manifest"
if find "$ROOT_DIR/addon" -type l -print -quit | grep -q .; then
    echo "Addon package rejects symlinks" >&2
    exit 1
fi
LC_ALL=C sort -u "$manifest" > "$declared"
find "$ROOT_DIR/addon" -type f -printf '%P\n' | grep -v '^package-manifest.txt$' | LC_ALL=C sort > "$actual"
if ! cmp -s "$declared" "$actual"; then
    echo "Addon tree does not match closed package manifest" >&2
    diff -u "$declared" "$actual" >&2 || true
    exit 1
fi

while IFS= read -r relative; do
    case "$relative" in
        ''|/*|*..*) echo "Unsafe package manifest path: $relative" >&2; exit 1 ;;
    esac
    install -D -m 0644 "$ROOT_DIR/addon/$relative" "$stage/$relative"
done < "$declared"

find "$stage" -type f -exec touch -t 198001010000 {} +
mkdir -p "$dist"
rm -f "$dist/@aviorstudio_gd-network.zip" "$dist/@aviorstudio_gd-network.zip.sha256"
(cd "$stage" && zip -X -q -r "$dist/@aviorstudio_gd-network.zip" .)
(cd "$dist" && sha256sum '@aviorstudio_gd-network.zip' > '@aviorstudio_gd-network.zip.sha256')
