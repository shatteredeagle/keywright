use core::pin::Pin;
use cxx_qt::CxxQtType;
use cxx_qt_lib::QString;
use keywright_core::{Keyboard, enumerate, keycode, layout::Layout};
use serde_json::json;

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(bool, connected)]
        #[qproperty(QString, status)]
        type Backend = super::BackendRust;

        #[qinvokable]
        fn load(self: Pin<&mut Backend>);

        #[qinvokable]
        fn keymap(self: &Backend) -> QString;

        #[qinvokable]
        fn catalog(self: &Backend) -> QString;

        #[qinvokable]
        fn set_key(self: Pin<&mut Backend>, layer: i32, row: i32, col: i32, code: i32) -> bool;

        #[qinvokable]
        fn env(self: &Backend, name: &QString) -> QString;
    }
}

pub struct BackendRust {
    connected: bool,
    status: QString,
    keyboard: Option<Keyboard>,
    layout: Layout,
    layers: Vec<Vec<u16>>,
}

impl Default for BackendRust {
    fn default() -> Self {
        Self {
            connected: false,
            status: QString::from("Looking for a keyboard…"),
            keyboard: None,
            layout: Layout::q6_max_ansi(),
            layers: Vec::new(),
        }
    }
}

impl qobject::Backend {
    fn load(mut self: Pin<&mut Self>) {
        let found = enumerate()
            .ok()
            .and_then(|d| d.into_iter().find(|d| d.product_id == 0x0860));
        let Some(info) = found else {
            self.as_mut().set_connected(false);
            self.set_status(QString::from(
                "Plug the keyboard in with its USB cable to configure it.",
            ));
            return;
        };
        let result = Keyboard::open(&info).and_then(|kb| {
            let layers = kb.read_keymap(&self.rust().layout)?;
            Ok((kb, layers))
        });
        match result {
            Ok((kb, layers)) => {
                let mut rust = self.as_mut().rust_mut();
                rust.keyboard = Some(kb);
                rust.layers = layers;
                self.as_mut().set_connected(true);
                self.set_status(QString::from("Keychron Q6 Max connected"));
            }
            Err(e) => {
                self.as_mut().set_connected(false);
                self.set_status(QString::from(
                    format!("Could not talk to the keyboard: {e}").as_str(),
                ));
            }
        }
    }

    fn keymap(&self) -> QString {
        let r = self.rust();
        let cols = r.layout.cols as usize;
        let layers: Vec<_> = r
            .layers
            .iter()
            .map(|codes| {
                r.layout
                    .keys
                    .iter()
                    .map(|k| {
                        let code = codes[k.row as usize * cols + k.col as usize];
                        json!({
                            "x": k.x, "y": k.y, "w": k.w, "h": k.h,
                            "row": k.row, "col": k.col, "color": k.color,
                            "encoder": k.encoder, "code": code, "label": keycode::name(code),
                        })
                    })
                    .collect::<Vec<_>>()
            })
            .collect();
        let (w, h) = r.layout.size();
        QString::from(
            json!({ "width": w, "height": h, "layers": layers })
                .to_string()
                .as_str(),
        )
    }
}

impl qobject::Backend {
    fn catalog(&self) -> QString {
        let items: Vec<_> = keycode::catalog()
            .into_iter()
            .map(|(g, c, n)| json!({ "group": g, "code": c, "label": n }))
            .collect();
        QString::from(json!(items).to_string().as_str())
    }

    fn set_key(mut self: Pin<&mut Self>, layer: i32, row: i32, col: i32, code: i32) -> bool {
        let cols = self.rust().layout.cols as usize;
        let written = match &self.rust().keyboard {
            Some(kb) => kb
                .set_keycode(layer as u8, row as u8, col as u8, code as u16)
                .is_ok(),
            None => false,
        };
        if written {
            self.as_mut().rust_mut().layers[layer as usize][row as usize * cols + col as usize] =
                code as u16;
        } else {
            self.set_status(QString::from("Could not write to the keyboard."));
        }
        written
    }

    fn env(&self, name: &QString) -> QString {
        QString::from(std::env::var(name.to_string()).unwrap_or_default().as_str())
    }
}
