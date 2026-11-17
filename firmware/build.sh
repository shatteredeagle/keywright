#!/bin/sh
# Build the Q6 Max (ANSI knob) firmware with raw HID enabled over the 2.4G receiver.
# Needs arm-none-eabi-gcc, arm-none-eabi-newlib and python3.
# Output: out/keywright-q6max-wireless-<version>.bin (+ .sha256). Set VERSION to name it.
set -e
here=$(cd "$(dirname "$0")" && pwd)
version="${VERSION:-dev}"
# Keychron/qmk_firmware, branch 2025q3, pinned so the build is repeatable.
upstream=https://github.com/Keychron/qmk_firmware.git
commit=57e682caa0a821e6de1b589e6f983f266151ab02

if [ ! -d "$here/keychron-qmk" ]; then
  git init -q "$here/keychron-qmk"
  git -C "$here/keychron-qmk" remote add origin "$upstream"
  git -C "$here/keychron-qmk" fetch -q --depth 1 origin "$commit"
  git -C "$here/keychron-qmk" checkout -q FETCH_HEAD
  git -C "$here/keychron-qmk" submodule update -q --init --depth 1 --recursive
fi
cd "$here/keychron-qmk"
git apply --check "$here/q6max-wireless-raw-hid.patch" 2>/dev/null && git apply "$here/q6max-wireless-raw-hid.patch"
[ -d .venv ] || { python3 -m venv .venv && .venv/bin/pip install --quiet -r requirements.txt qmk; }
PATH="$PWD/.venv/bin:$PATH" QMK_HOME="$PWD" make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)" keychron/q6_max/ansi_encoder:kw
mkdir -p "$here/out"
out="$here/out/keywright-q6max-wireless-$version.bin"
cp keychron_q6_max_ansi_encoder_kw.bin "$out"
(cd "$here/out" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256")
echo "Built $out"
