#!/bin/sh
# Build Keywright and install it for the current user (no root needed).
# Prints one extra line for the udev rule, which does need root.
set -e
here=$(cd "$(dirname "$0")" && pwd)
prefix="${PREFIX:-$HOME/.local}"
cd "$here"
cargo build --release -p keywright
install -Dm755 target/release/keywright "$prefix/bin/keywright"
install -Dm644 packaging/keywright.desktop "$prefix/share/applications/keywright.desktop"
for px in 32 64 128 256; do
  install -Dm644 "packaging/icons/keywright-$px.png" "$prefix/share/icons/hicolor/${px}x${px}/apps/keywright.png"
done
command -v update-desktop-database >/dev/null && update-desktop-database "$prefix/share/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$prefix/share/icons/hicolor" || true
echo "Installed to $prefix. Launch Keywright from your application menu."
if [ ! -e /etc/udev/rules.d/70-keywright.rules ] && [ ! -e /etc/udev/rules.d/70-keychron.rules ]; then
  echo "One-time step so the app can open the keyboard (needs root):"
  echo "  sudo install -Dm644 $here/packaging/70-keywright.rules /etc/udev/rules.d/70-keywright.rules && sudo udevadm control --reload-rules"
  echo "Then unplug and replug the keyboard."
fi
