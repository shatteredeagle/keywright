#!/bin/sh
# Build the Q6 Max (ANSI knob) firmware with raw HID enabled over the 2.4G receiver.
# Needs arm-none-eabi-gcc/newlib and python3. Output: out/keychron_q6_max_ansi_encoder_kw.bin
set -e
here=$(cd "$(dirname "$0")" && pwd)
[ -d "$here/keychron-qmk" ] || git clone --depth 1 --branch 2025q3 --recurse-submodules --shallow-submodules \
  https://github.com/Keychron/qmk_firmware.git "$here/keychron-qmk"
cd "$here/keychron-qmk"
git apply --check "$here/q6max-wireless-raw-hid.patch" 2>/dev/null && git apply "$here/q6max-wireless-raw-hid.patch"
[ -d .venv ] || { python3 -m venv .venv && .venv/bin/pip install --quiet -r requirements.txt qmk; }
PATH="$PWD/.venv/bin:$PATH" QMK_HOME="$PWD" make -j"$(nproc)" keychron/q6_max/ansi_encoder:kw
mkdir -p "$here/out" && cp keychron_q6_max_ansi_encoder_kw.bin "$here/out/"
