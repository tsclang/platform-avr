#!/bin/bash
# Builds an avr-gcc toolchain (binutils + gcc C-only + avr-libc) from
# sources into the TSClang bundle layout (bin/ at the archive root) and
# packs it as avr-gcc-<version>-darwin-arm64.tar.gz. macOS has no upstream
# binary distribution (Zak Kemble's builds cover Windows/Linux), hence
# this CI build. Runs natively on an arm64 macOS runner.
#
# C-only on purpose: TSClang emits C, so the C++ cross-compiler would only
# triple the build time.
set -euxo pipefail

GCC_VERSION=16.1.0
BINUTILS_VERSION=2.47
AVRLIBC_VERSION=2.2.1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build-avr-gcc"
OUT="$ROOT/bundles-out"
PREFIX="$WORK/stage"
JOBS="$(sysctl -n hw.ncpu)"

rm -rf "$WORK" && mkdir -p "$WORK/src" "$WORK" "$PREFIX" "$OUT"

fetch() { curl -fL --retry 3 -o "$2" "$1"; }

# --- binutils ---------------------------------------------------------------
fetch "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" "$WORK/binutils.tar.xz"
tar -C "$WORK/src" -xJf "$WORK/binutils.tar.xz"
mkdir -p "$WORK/build/binutils"
(cd "$WORK/build/binutils" \
  && "$WORK/src/binutils-${BINUTILS_VERSION}/configure" \
    --target=avr --prefix="$PREFIX" --disable-nls --disable-werror \
  && make -j"$JOBS" && make install)

export PATH="$PREFIX/bin:$PATH"
test -x "$PREFIX/bin/avr-ld"

# --- gcc (C only) ------------------------------------------------------------
fetch "https://ftp.gnu.org/g/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz" "$WORK/gcc.tar.xz"
tar -C "$WORK/src" -xJf "$WORK/gcc.tar.xz"
(cd "$WORK/src/gcc-${GCC_VERSION}" && ./contrib/download_prerequisites)
mkdir -p "$WORK/build/gcc"
(cd "$WORK/build/gcc" \
  && "$WORK/src/gcc-${GCC_VERSION}/configure" \
    --target=avr --prefix="$PREFIX" --enable-languages=c --disable-nls \
    --disable-libssp --disable-shared --with-dwarf2 --without-headers \
  && make -j"$JOBS" && make install)

"$PREFIX/bin/avr-gcc" --version | head -1

# --- avr-libc ----------------------------------------------------------------
fetch "https://github.com/avrdudes/avr-libc/releases/download/v${AVRLIBC_VERSION}/avr-libc-${AVRLIBC_VERSION}.tar.bz2" "$WORK/avr-libc.tar.bz2"
tar -C "$WORK/src" -xjf "$WORK/avr-libc.tar.bz2"
mkdir -p "$WORK/build/avr-libc"
(cd "$WORK/build/avr-libc" \
  && "$WORK/src/avr-libc-${AVRLIBC_VERSION}/configure" \
    --prefix="$PREFIX" --host=avr \
    --build="$("$WORK/src/avr-libc-${AVRLIBC_VERSION}/config.guess")" \
  && make -j"$JOBS" && make install)

# smoke: compile a trivial avr program against the freshly built libc
echo 'int main(void) { return 0; }' > "$WORK/smoke.c"
"$PREFIX/bin/avr-gcc" -mmcu=atmega328p -Os -o "$WORK/smoke.elf" "$WORK/smoke.c"
test -f "$PREFIX/avr/include/avr/io.h"

cat > "$PREFIX/TSC_BUNDLE_NOTICE.txt" <<EOF
TSClang toolchain bundle: avr-gcc ${GCC_VERSION} (darwin-arm64)
Sources: binutils ${BINUTILS_VERSION}, GCC ${GCC_VERSION} (C only), avr-libc ${AVRLIBC_VERSION}
License: GPL-3.0-or-later with GCC Runtime Library Exception (GCC, binutils); BSD-style (avr-libc)
Built: $(date -u +%Y-%m-%dT%H:%M:%SZ) by platform-avr CI (scripts/build-avr-gcc.sh)
Built from sources because no upstream publishes macOS avr-gcc binaries.
EOF

TARNAME="avr-gcc-${GCC_VERSION}-darwin-arm64.tar.gz"
tar -czf "$OUT/$TARNAME" -C "$PREFIX" .
shasum -a 256 "$OUT/$TARNAME"
