## Installing

- **Linux**: make the AppImage executable and run it. For the keyboard to be usable without root, install `70-keywright.rules` into `/etc/udev/rules.d/`, run `sudo udevadm control --reload-rules`, then replug the keyboard.
- **macOS** (Apple silicon): open the dmg and drag Keywright to Applications. The app is not signed, so the first time use right-click, Open. macOS asks for Input Monitoring permission so the app can reach the keyboard.
- **Windows**: unzip and run `keywright.exe`. Flashing firmware additionally needs the WinUSB driver for the STM32 bootloader (Zadig).

## Firmware

Every release bundles `keywright-q6max-wireless-*.bin`, Keychron's open QMK firmware with a small patch that lets Keywright configure the Q6 Max over the 2.4 GHz receiver. It is flashed from the app's Firmware page, behind warnings. The firmware is GPL-2.0-or-later; its source is Keychron's `qmk_firmware` at the commit pinned in `firmware/build.sh`, plus `firmware/q6max-wireless-raw-hid.patch`.

Keywright is unofficial and is not made or supported by Keychron.
