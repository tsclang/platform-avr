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
# The v8.3 GitHub release ships only signature files for the source
# archives, so use the tag's auto-generated source archive instead.
curl -fL --retry 3 -o "$WORK/avrdude.tar.gz" \
  "https://github.com/avrdudes/avrdude/archive/refs/tags/v${VERSION}.tar.gz"
tar -C "$WORK/src" -xzf "$WORK/avrdude.tar.gz" --strip-components=1

# avrdude's CMake does not use find_package for these — it runs bare
# find_library() and check_include_file() over default paths and never adds
# the external include dirs to its targets, expecting them to live in the
# compiler's default search path. Homebrew's /opt/homebrew is not there, so
# feed the brew prefixes through CMAKE_PREFIX_PATH (find_library picks the
# .a archives, with USE_STATIC_LIBS preferring them) and export the headers
# via CMAKE_C_FLAGS — that covers both the configure checks and the build.
cmake -S "$WORK/src" -B "$WORK/build" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_DOC=OFF \
  -DUSE_STATIC_LIBS=ON \
  -DCMAKE_PREFIX_PATH="$(brew --prefix libusb);$(brew --prefix libftdi);$(brew --prefix hidapi)" \
  -DCMAKE_C_FLAGS="-I$(brew --prefix libusb)/include -I$(brew --prefix libftdi)/include -I$(brew --prefix hidapi)/include" \
  -DCMAKE_EXE_LINKER_FLAGS="-framework CoreFoundation -framework IOKit -lobjc"
cmake --build "$WORK/build" --parallel "$(sysctl -n hw.ncpu)"
cmake --install "$WORK/build"

test -x "$PREFIX/bin/avrdude"
test -f "$PREFIX/etc/avrdude.conf"
"$PREFIX/bin/avrdude" --version | head -1
otool -L "$PREFIX/bin/avrdude" | grep -v "System/Library\|/usr/lib" && { echo "unexpected dynamic deps"; exit 1; } || true

cat > "$PREFIX/TSC_BUNDLE_NOTICE.txt" <<EOF
TSClang toolchain bundle: avrdude ${VERSION} (darwin-arm64)
Source: https://github.com/avrdudes/avrdude (tag v${VERSION} source archive)
License: GPL-2.0-or-later (avrdude); LGPL-2.1 (libusb), LGPL-2.1 with exception (libftdi), BSD/ISC (hidapi) — linked statically
Built: $(date -u +%Y-%m-%dT%H:%M:%SZ) by platform-avr CI (scripts/build-avrdude.sh)
Built from sources because upstream publishes no arm64 macOS binary.
EOF

TARNAME="avrdude-${VERSION}-darwin-arm64.tar.gz"
tar -czf "$OUT/$TARNAME" -C "$PREFIX" .
shasum -a 256 "$OUT/$TARNAME"
