# @tsclang/avr — official toolchain bundles

This repository hosts the downloadable toolchain bundles consumed by the
[`@tsclang/avr`](https://github.com/tsclang/tsclang/tree/develop/packages/platforms/avr)
platform package of the [TSClang](https://github.com/tsclang/tsclang) compiler.

The packages' `platform.toolchains.<name>.downloads["<os>-arch>"]` entries point
at [Releases](../../releases) of this repository — never at raw upstream
downloads. This is the **sha256 contract**: a pinned hash ships with the
package manifest, so upstream re-uploads cannot silently change what users
execute, and availability is under our control.

## Bundles

| Tag | Toolchain | OS-arch | Origin | License |
|-----|-----------|---------|--------|---------|
| `toolchains-v1` | avr-gcc 16.1.0 | win32-x64, linux-x64 | [Zak Kemble's avr-gcc build](https://github.com/ZakKemble/avr-gcc-build) | GPL-3.0 + GCC Runtime Library Exception |
| `toolchains-v1` | avr-gcc 16.1.0 | darwin-arm64 | built from sources by this repo's CI (binutils 2.47 + GCC 16.1.0 C-only + avr-libc 2.2.1) | GPL-3.0 + GCC Runtime Library Exception; BSD-style (avr-libc) |
| `toolchains-v1` | avrdude 8.3 | win32-x64, linux-x64, darwin-x64 | [avrdude](https://github.com/avrdudes/avrdude) release binaries | GPL-2.0+ |
| `toolchains-v1` | avrdude 8.3 | darwin-arm64 | built from sources by this repo's CI (statically linked libusb/libftdi/hidapi) | GPL-2.0+ |

**darwin-x64 avr-gcc** (Intel Macs): no upstream publishes macOS avr-gcc
binaries and CI has no free x64 macOS runner, so no bundle is released for it.
The documented fallback is Homebrew:
```sh
brew install osx-cross/avr/avr-gcc
```

Bundles are assembled by this repository's CI
([`.github/workflows/bundles.yml`](.github/workflows/bundles.yml)); posix
bundles are packed/built on posix runners so executable bits survive.

Every archive carries a `TSC_BUNDLE_NOTICE.txt` stating the upstream source
and license. Layout contract: a `bin/` directory on top.

Note: the avr-gcc bundle also carries `avr-objcopy`/`avr-as` in its `bin/` —
TSClang resolves tools shipped inside another toolchain's bundle
(`avr-objcopy` → `avr-gcc@<v>/bin/avr-objcopy`).

Release assets are immutable. A new toolchain version ships as a **new tag**
(`toolchains-v2`, …) plus a package manifest bump.
