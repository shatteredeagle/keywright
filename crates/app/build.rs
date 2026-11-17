use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("Keywright").qml_files([
        "qml/Main.qml",
        "qml/KeyboardView.qml",
        "qml/KeyPicker.qml",
        "qml/ShortcutsPage.qml",
        "qml/LightingPage.qml",
    ]))
    .file("src/backend.rs")
    .build();
}
