import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Flash firmware to the keyboard, behind warnings, a backup, and a typed confirmation.
Item {
    id: root
    property var backend
    signal reconnectRequested()

    property var status: ({ version: null, bootloaders: [], bundled: null, os: "", running: false })
    property var progress: ({ running: false, finished: false, phase: null, done: 0, total: 0, error: null })
    property string source: "bundled"        // "bundled" or "file"
    property var fileInfo: null
    property string backupPath: ""
    property string backupError: ""
    property bool skipBackup: false
    property var acks: [false, false, false, false, false]
    property string confirmText: ""
    property string restoreMessage: ""
    property bool userChose: false

    readonly property var bundled: status.bundled
    readonly property bool hasBundled: bundled !== null && bundled !== undefined
    readonly property var image: source === "bundled" ? bundled : fileInfo
    readonly property bool imageOk: image !== null && image !== undefined && image.ok === true
    readonly property bool bootOk: status.bootloaders.length === 1
    readonly property bool acksOk: acks.every(a => a)
    readonly property bool backupOk: backupPath !== "" || skipBackup
    readonly property bool running: progress.running
    readonly property bool canFlash: imageOk && bootOk && acksOk && backupOk && confirmText === "FLASH" && !running && !progress.finished
    readonly property bool done: progress.finished && progress.error === null
    readonly property bool failed: progress.finished && progress.error !== null

    function poll() {
        status = JSON.parse(backend.fw_status());
        progress = JSON.parse(backend.fw_progress());
        if (!userChose) source = status.bundled ? "bundled" : "file";
    }
    Timer { interval: 800; repeat: true; running: root.visible; triggeredOnStart: true; onTriggered: root.poll() }

    function setAck(i, v) { const a = acks.slice(); a[i] = v; acks = a; }
    function phaseText() {
        const p = progress.phase;
        const label = p === "erase" ? "Erasing" : p === "write" ? "Writing" : p === "verify" ? "Verifying" : p === "restart" ? "Restarting" : "Starting";
        return label + (progress.total > 1 ? " " + progress.done + " / " + progress.total : "…");
    }
    function overall() {
        // Erase 10%, write 50%, verify 35%, restart 5%.
        const f = progress.total > 0 ? progress.done / progress.total : 0;
        switch (progress.phase) {
        case "erase": return 0.10 * f;
        case "write": return 0.10 + 0.50 * f;
        case "verify": return 0.60 + 0.35 * f;
        case "restart": return 0.95 + 0.05 * f;
        default: return 0;
        }
    }
    function makeBackup() {
        const r = JSON.parse(backend.fw_backup());
        if (r.ok) { backupPath = r.path; backupError = ""; } else { backupError = r.error; }
    }
    function flash() {
        const path = source === "bundled" ? bundled.path : fileInfo.path;
        backend.fw_flash(path);
        poll();
    }
    function restore() { restoreMessage = backend.fw_restore(backupPath) || "Your settings are back on the keyboard."; }

    FileDialog {
        id: picker
        title: "Choose a firmware file"
        nameFilters: ["Firmware (*.bin)", "All files (*)"]
        onAccepted: {
            let p = selectedFile.toString();
            p = p.replace(/^file:\/\/\/(?=[A-Za-z]:)/, "").replace(/^file:\/\//, "");
            root.fileInfo = JSON.parse(root.backend.fw_check(decodeURIComponent(p)));
            root.userChose = true;
            root.source = "file";
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            x: 28
            width: parent.width - 56
            spacing: 16

            PageHeader {
                Layout.topMargin: 28
                Layout.fillWidth: true
                title: "Firmware"
                subtitle: "Replace the keyboard's firmware. Most people never need this page."
            }

            // Current state ---------------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                RowLayout {
                    anchors.fill: parent
                    spacing: 16
                    Rectangle { Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 12; color: Theme.panelHi; Icon { anchors.centerIn: parent; name: "chip"; size: 22; color: Theme.dim } }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { Layout.fillWidth: true; text: "Installed firmware"; color: Theme.dim; font.pixelSize: 12 }
                        Text { Layout.fillWidth: true; text: root.status.version || (root.status.bootloaders.length ? "Keyboard is in bootloader mode" : "Keyboard not connected"); color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    }
                    Rectangle {
                        radius: 14; height: 28; width: bl.implicitWidth + 28
                        color: root.bootOk ? Qt.rgba(Theme.ok.r, Theme.ok.g, Theme.ok.b, 0.16) : Theme.panelHi
                        Text { id: bl; anchors.centerIn: parent; font.pixelSize: 12; font.weight: Font.Medium
                            color: root.bootOk ? Theme.ok : Theme.faint
                            text: root.bootOk ? "Bootloader found" : root.status.bootloaders.length > 1 ? "More than one bootloader" : "No bootloader" }
                    }
                }
            }

            // Warnings --------------------------------------------------------------------------
            Card {
                id: warnCard
                Layout.fillWidth: true
                border.color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.55)
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    RowLayout {
                        spacing: 10
                        Icon { name: "alert"; size: 22; color: Theme.danger }
                        Text { text: "Read this before you flash"; color: Theme.text; font.pixelSize: 17; font.weight: Font.Bold }
                    }
                    Repeater {
                        model: [
                            "Flashing replaces the keyboard's firmware. If it goes wrong, the keyboard can stop working until it is flashed again. The recovery bootloader lives in the chip's read-only memory and cannot be erased, so recovery is normally possible, but that is not guaranteed.",
                            "This is only for the Keychron Q6 Max ANSI with knob. Other models and layouts (ISO, JIS, no knob) need different firmware, and the wrong one may not start.",
                            "Keep the USB cable plugged in and leave the keyboard alone until this page says Done. It takes about ten seconds.",
                            "Your keymap, lighting and macros may be reset. Keywright saves a backup first and can restore it afterwards.",
                            "This is unofficial. It is not made or supported by Keychron, it may affect your warranty, and updating through Keychron Launcher later will replace it."
                        ]
                        delegate: RowLayout {
                            id: ackRow
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 12
                            KSwitch { checked: root.acks[ackRow.index]; onToggled: root.setAck(ackRow.index, checked); enabled: !root.running }
                            Text { text: ackRow.modelData; color: Theme.text; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true; lineHeight: 1.15 }
                        }
                    }
                }
            }

            // Windows driver note ----------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                visible: root.status.os === "windows"
                ColumnLayout {
                    anchors.fill: parent
                    Text { text: "Windows needs a driver for the bootloader"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "Install the WinUSB driver for “STM32 BOOTLOADER” with Zadig (zadig.akeo.ie) before flashing. You only need to do this once."; color: Theme.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }

            // Which firmware ---------------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    Text { text: "1  Choose the firmware"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.hasBundled
                        implicitHeight: bundledCol.implicitHeight + 28
                        radius: 10
                        color: root.source === "bundled" ? Theme.accentSoft : Theme.panelHi
                        border.color: root.source === "bundled" ? Theme.accent : Theme.line
                        ColumnLayout {
                            id: bundledCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 4
                            RowLayout {
                                Text { text: "Keywright wireless-config firmware"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
                                Text { visible: root.hasBundled && root.bundled.ok; text: "Checked"; color: Theme.ok; font.pixelSize: 12; font.weight: Font.Medium }
                            }
                            Text { text: "Lets Keywright configure the keyboard over the 2.4 GHz receiver, and unlocks Keychron's extra RGB features (per-key colours and regions). Built from Keychron's open QMK source with a small patch."; color: Theme.dim; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Text { visible: root.hasBundled && root.bundled.ok; text: root.hasBundled && root.bundled.ok ? Math.round(root.bundled.size / 1024) + " KB · sha256 " + root.bundled.sha256.slice(0, 16) + "…" : ""; color: Theme.faint; font.pixelSize: 11 }
                            Text { visible: root.hasBundled && !root.bundled.ok; text: root.hasBundled && !root.bundled.ok ? root.bundled.problems.join(" ") : ""; color: Theme.danger; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        TapHandler { onTapped: { root.userChose = true; root.source = "bundled"; } }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: fileCol.implicitHeight + 28
                        radius: 10
                        color: root.source === "file" ? Theme.accentSoft : Theme.panelHi
                        border.color: root.source === "file" ? Theme.accent : Theme.line
                        ColumnLayout {
                            id: fileCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 6
                            Text { text: "A firmware file from your computer"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { text: "For example Keychron's official firmware, to go back to stock. Only use a .bin made for the Q6 Max ANSI with knob."; color: Theme.dim; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            RowLayout {
                                spacing: 10
                                KButton { text: "Choose file…"; iconName: "plus"; onClicked: picker.open() }
                                Text { visible: root.fileInfo !== null; text: root.fileInfo ? (root.fileInfo.name || "") : ""; color: Theme.text; font.pixelSize: 12; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            }
                            Text { visible: root.fileInfo !== null && root.fileInfo.ok === true; text: root.fileInfo && root.fileInfo.ok ? "Looks like valid firmware · " + Math.round(root.fileInfo.size / 1024) + " KB · sha256 " + root.fileInfo.sha256.slice(0, 16) + "…" : ""; color: Theme.ok; font.pixelSize: 12 }
                            Text { visible: root.fileInfo !== null && root.fileInfo.ok === true; text: "Keywright can check that the file is a firmware image for this chip, but not that it is the right firmware for your keyboard."; color: Theme.warn; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Text { visible: root.fileInfo !== null && root.fileInfo.ok === false; text: root.fileInfo && !root.fileInfo.ok ? root.fileInfo.problems.join(" ") : ""; color: Theme.danger; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        TapHandler { onTapped: { root.userChose = true; root.source = "file"; } }
                    }
                }
            }

            // Backup -----------------------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Text { text: "2  Back up your settings"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { text: "Saves your keymap, knob, macros and lighting to a file so they can be put back after flashing. The keyboard has to be connected normally for this."; color: Theme.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    RowLayout {
                        spacing: 12
                        KButton { text: root.backupPath ? "Back up again" : "Save a backup"; iconName: "save"; enabled: backend.connected && !root.running; onClicked: root.makeBackup() }
                        Text { visible: root.backupPath !== ""; text: "Saved to " + root.backupPath; color: Theme.ok; font.pixelSize: 12; elide: Text.ElideMiddle; Layout.fillWidth: true }
                        Text { visible: root.backupError !== ""; text: root.backupError; color: Theme.danger; font.pixelSize: 12 }
                    }
                    KSwitch { visible: root.backupPath === ""; text: "Continue without a backup"; checked: root.skipBackup; onToggled: root.skipBackup = checked; enabled: !root.running }
                }
            }

            // Bootloader -------------------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Text { text: "3  Put the keyboard in bootloader mode"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text {
                        text: "Slide the mode switch to the middle position (Off). Unplug the USB cable, hold down the Esc key, plug the cable back in while holding it, and keep holding for two seconds. The keyboard stays dark. That is normal."
                        color: Theme.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true; lineHeight: 1.15
                    }
                    Text {
                        text: root.bootOk ? "The bootloader is connected and ready." : root.status.bootloaders.length > 1 ? "More than one STM32 bootloader is attached. Unplug the others so only the keyboard remains." : "Waiting for the keyboard in bootloader mode…"
                        color: root.bootOk ? Theme.ok : Theme.dim; font.pixelSize: 13; font.weight: Font.Medium
                    }
                }
            }

            // Flash ------------------------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    Text { text: "4  Flash"; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }

                    ColumnLayout {
                        visible: !root.running && !root.progress.finished
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "Type FLASH to confirm"; color: Theme.dim; font.pixelSize: 13 }
                        RowLayout {
                            spacing: 12
                            KField { Layout.preferredWidth: 220; placeholderText: "FLASH"; text: root.confirmText; onTextEdited: root.confirmText = text }
                            KButton { text: "Flash firmware"; iconName: "bolt"; variant: "danger"; enabled: root.canFlash; onClicked: root.flash() }
                        }
                        Text {
                            visible: !root.canFlash
                            color: Theme.faint; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
                            text: "Still needed: " + [
                                !root.imageOk ? "a valid firmware" : "",
                                !root.acksOk ? "all five warnings switched on" : "",
                                !root.backupOk ? "a backup (or continue without one)" : "",
                                !root.bootOk ? "the keyboard in bootloader mode" : "",
                                root.confirmText !== "FLASH" ? "FLASH typed above" : ""
                            ].filter(x => x !== "").join(", ") + "."
                        }
                    }

                    ColumnLayout {
                        visible: root.running
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: root.phaseText(); color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Rectangle {
                            Layout.fillWidth: true; height: 10; radius: 5; color: Theme.field; border.color: Theme.line
                            Rectangle { width: Math.max(10, parent.width * root.overall()); height: parent.height; radius: 5; color: Theme.accent; Behavior on width { NumberAnimation { duration: 150 } } }
                        }
                        Text { text: "Do not unplug the keyboard."; color: Theme.warn; font.pixelSize: 13; font.weight: Font.Medium }
                    }

                    ColumnLayout {
                        visible: root.done
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "Done. The firmware was written and checked, and the keyboard is restarting."; color: Theme.ok; font.pixelSize: 14; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        Text { text: "Wait a few seconds for it to reappear, then reconnect. Flashing can reset your settings, so restore the backup if they are gone."; color: Theme.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        RowLayout {
                            spacing: 10
                            KButton { text: "Reconnect"; iconName: "refresh"; variant: "primary"; onClicked: root.reconnectRequested() }
                            KButton { text: "Restore my settings"; iconName: "undo"; visible: root.backupPath !== ""; enabled: backend.connected; onClicked: root.restore() }
                        }
                        Text { visible: root.restoreMessage !== ""; text: root.restoreMessage; color: Theme.dim; font.pixelSize: 13 }
                    }

                    ColumnLayout {
                        visible: root.failed
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Flashing did not finish."; color: Theme.danger; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: root.progress.error || ""; color: Theme.text; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        Text {
                            color: Theme.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true; lineHeight: 1.15
                            text: "Do not panic and do not unplug it yet. If the keyboard is still in bootloader mode, flash again. If it no longer responds, put it in bootloader mode again (hold Esc while plugging in the cable) and flash the firmware again, or Keychron's official firmware."
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: 24 }
        }
    }
}
