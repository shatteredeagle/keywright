use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("Keywright")
            .qml_file(QmlFile::from("qml/Theme.qml").singleton(true))
            .qml_files([
                "qml/Main.qml",
                "qml/KeyboardView.qml",
                "qml/KeyPicker.qml",
                "qml/ShortcutsPage.qml",
                "qml/LightingPage.qml",
                "qml/HsvPicker.qml",
                "qml/PerKeyPage.qml",
                "qml/RegionsPage.qml",
                "qml/IndicatorsPage.qml",
                "qml/MacrosPage.qml",
                "qml/PageHeader.qml",
                "qml/Card.qml",
                "qml/KSwitch.qml",
                "qml/KField.qml",
                "qml/KSpin.qml",
                "qml/KCombo.qml",
                "qml/KTabs.qml",
                "qml/KSlider.qml",
                "qml/KButton.qml",
                "qml/Icon.qml",
                "qml/LightingPreview.qml",
            ]),
    )
    .file("src/backend.rs")
    .build();
}
