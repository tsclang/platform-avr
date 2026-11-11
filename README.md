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
| `toolchains-v1` | avr-gcc 16.1.0 | win32-x64 | [Zak Kemble's avr-gcc build](https://github.com/ZakKemble/avr-gcc-build) | GPL-3.0 + GCC Runtime Library Exception |
| `toolchains-v1` | avrdude 8.3 | win32-x64 | [avrdude](https://github.com/avrdudes/avrdude) | GPL-2.0+ |

Linux/macOS bundles are built from source by this repository's CI
(binutils + gcc targeted at avr, avr-libc, avrdude) — see
`.github/workflows/`.

Every archive carries a `TSC_BUNDLE_NOTICE.txt` stating the upstream source
and license. Layout contract: a `bin/` directory on top.

Note: the avr-gcc bundle also carries `avr-objcopy`/`avr-as` in its `bin/` —
TSClang resolves tools shipped inside another toolchain's bundle
(`avr-objcopy` → `avr-gcc@<v>/bin/avr-objcopy`).

Release assets are immutable. A new toolchain version ships as a **new tag**
(`toolchains-v2`, …) plus a package manifest bump.
