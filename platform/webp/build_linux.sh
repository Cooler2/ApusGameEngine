#!/usr/bin/env bash
# Build one decode-only Linux x64 library from the pinned upstream source.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd -P)"
work="$root/Work/webp-build"
archive="${1:-$work/libwebp-1.6.0.tar.gz}"
url="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz"
expected="e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564"
output="$root/redist/linux/libapuswebpdecoder.so"

[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || {
  echo "build_linux.sh requires Linux x86_64" >&2
  exit 2
}
for tool in gcc make tar readelf sha256sum; do
  command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 2; }
done
mkdir -p "$work" "$(dirname "$output")"
if [ ! -f "$archive" ]; then
  command -v curl >/dev/null || { echo "Missing curl to download source" >&2; exit 2; }
  curl -fLsS --retry 3 "$url" -o "$archive"
fi
echo "$expected  $archive" | sha256sum -c - >/dev/null

tmp="$(mktemp -d "$work/linux-x64.XXXXXX")"
case "$tmp" in "$work"/linux-x64.*) ;; *) echo "Unsafe build path: $tmp" >&2; exit 2;; esac
trap 'rm -rf -- "$tmp"' EXIT
tar -xzf "$archive" -C "$tmp"
(
  cd "$tmp/libwebp-1.6.0"
  make -s -f makefile.unix 'EXTRA_FLAGS=-fPIC' src/libwebpdecoder.a -j "${JOBS:-4}"
  gcc -shared -Wl,-soname,libapuswebpdecoder.so     -Wl,--whole-archive src/libwebpdecoder.a -Wl,--no-whole-archive     -o "$tmp/libapuswebpdecoder.so"
)

mapfile -t needed < <(readelf -d "$tmp/libapuswebpdecoder.so" | sed -n 's/.*(NEEDED).*\[\([^]]*\)\].*/\1/p')
if [ "${needed[*]}" != "libc.so.6" ]; then
  echo "Unexpected runtime dependencies: ${needed[*]}" >&2
  exit 1
fi
for symbol in WebPGetInfo WebPDecodeRGBAInto; do
  readelf -Ws "$tmp/libapuswebpdecoder.so" | grep -E "GLOBAL DEFAULT.* $symbol$" >/dev/null || {
    echo "Missing export: $symbol" >&2
    exit 1
  }
done
cp "$tmp/libapuswebpdecoder.so" "$output"
printf 'Wrote %s\nSHA-256: %s\nDependencies: %s\n'   "$output" "$(sha256sum "$output" | cut -d ' ' -f1)" "${needed[*]}"
