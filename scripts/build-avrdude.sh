#!/bin/bash
# Builds avrdude from the v8.3 source tarball into the TSClang bundle
# layout (bin/ + etc/ at the archive root) and packs it as
# avrdude-<version>-darwin-arm64.tar.gz. Upstream ships no arm64 macOS
# binary, hence this CI build. libusb/libftdi/hidapi are linked statically
# (Homebrew ships the .a files) so the bundle stays self-contained.
set -euxo pipefail

VERSION=8.3
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build-avrdude"
OUT="$ROOT/bundles-out"
PREFIX="$WORK/stage"

brew install libusb libftdi hidapi

rm -rf "$WORK" && mkdir -p "$WORK/src" "$WORK/build" "$PREFIX" "$OUT"
curl -fL --retry 3 -o "$WORK/avrdude.tar.gz" \
  "https://github.com/avrdudes/avrdude/releases/download/v${VERSION}/avrdude-${VERSION}.tar.gz"
tar -C "$WORK/src" -xzf "$WORK/avrdude.tar.gz" --strip-components=1

# Point avrdude's cmake at the static archives; explicit .a paths make the
# link static where a plain find_package would pick the .dylib.
cmake -S "$WORK/src" -B "$WORK/build" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_DOC=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_Libelf=ON \
  -DLIBUSB_LIBRARY="$(brew --prefix libusb)/lib/libusb-1.0.a" \
  -DLIBUSB_INCLUDE_DIR="$(brew --prefix libusb)/include" \
  -DLIBFTDI_LIBRARY="$(brew --prefix libftdi)/lib/libftdi1.a" \
  -DLIBFTDI_INCLUDE_DIR="$(brew --prefix libftdi)/include" \
  -DLIBHIDAPI_LIBRARY="$(brew --prefix hidapi)/lib/libhidapi.a" \
  -DLIBHIDAPI_INCLUDE_DIR="$(brew --prefix hidapi)/include"
cmake --build "$WORK/build" --parallel "$(sysctl -n hw.ncpu)"
cmake --install "$WORK/build"

test -x "$PREFIX/bin/avrdude"
test -f "$PREFIX/etc/avrdude.conf"
"$PREFIX/bin/avrdude" --version | head -1
otool -L "$PREFIX/bin/avrdude" | grep -v "System/Library\|/usr/lib" && { echo "unexpected dynamic deps"; exit 1; } || true

cat > "$PREFIX/TSC_BUNDLE_NOTICE.txt" <<EOF
TSClang toolchain bundle: avrdude ${VERSION} (darwin-arm64)
Source: https://github.com/avrdudes/avrdude (v${VERSION} source tarball)
License: GPL-2.0-or-later (avrdude); LGPL-2.1 (libusb), LGPL-2.1 with exception (libftdi), BSD/ISC (hidapi) — linked statically
Built: $(date -u +%Y-%m-%dT%H:%M:%SZ) by platform-avr CI (scripts/build-avrdude.sh)
Built from sources because upstream publishes no arm64 macOS binary.
EOF

TARNAME="avrdude-${VERSION}-darwin-arm64.tar.gz"
tar -czf "$OUT/$TARNAME" -C "$PREFIX" .
shasum -a 256 "$OUT/$TARNAME"
