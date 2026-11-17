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
        fn set_encoder(self: Pin<&mut Backend>, layer: i32, clockwise: bool, code: i32) -> bool;

        #[qinvokable]
        fn set_key(self: Pin<&mut Backend>, layer: i32, row: i32, col: i32, code: i32) -> bool;

        #[qinvokable]
        fn env(self: &Backend, name: &QString) -> QString;

        #[qinvokable]
        fn rgb(self: &Backend) -> QString;

        #[qinvokable]
        fn set_rgb(self: &Backend, field: &QString, value: i32) -> bool;

        #[qinvokable]
        fn set_rgb_color(self: &Backend, hue: i32, saturation: i32) -> bool;

        #[qinvokable]
        fn save_rgb(self: &Backend) -> bool;

        #[qinvokable]
        fn kc_state(self: &Backend) -> QString;

        #[qinvokable]
        fn kc_apply(self: &Backend, op: &QString, args: &QString) -> bool;

        #[qinvokable]
        fn theme(self: &Backend) -> QString;

        #[qinvokable]
        fn set_theme(self: &Backend, mode: &QString);
    }
}

pub struct BackendRust {
    connected: bool,
    status: QString,
    keyboard: Option<Keyboard>,
    layout: Layout,
    layers: Vec<Vec<u16>>,
    /// LED index for each key of the layout, when the keyboard supports Keychron's extended RGB.
    /// `[layer][0 = counter-clockwise, 1 = clockwise]` bindings for the knob.
    encoders: Vec<[u16; 2]>,
    led_of: Vec<Option<u8>>,
    led_count: u8,
    extended_rgb: bool,
}

impl Default for BackendRust {
    fn default() -> Self {
        Self {
            connected: false,
            status: QString::from("Looking for a keyboard…"),
            keyboard: None,
            layout: Layout::q6_max_ansi(),
            layers: Vec::new(),
            encoders: Vec::new(),
            led_of: Vec::new(),
            led_count: 0,
            extended_rgb: false,
        }
    }
}

impl qobject::Backend {
    fn load(mut self: Pin<&mut Self>) {
        const Q6_MAX: u16 = 0x0860;
        const RECEIVER: u16 = 0xD030;
        let mut found = enumerate().unwrap_or_default();
        // Prefer the cable, then the 2.4G receiver.
        found.retain(|d| d.product_id == Q6_MAX || d.product_id == RECEIVER);
        found.sort_by_key(|d| d.product_id != Q6_MAX);
        if found.is_empty() {
            self.as_mut().set_connected(false);
            self.set_status(QString::from("Plug in the USB cable, or switch the keyboard to 2.4G with its receiver plugged in."));
            return;
        }
        let mut last_error = String::from("no reply from the keyboard");
        for info in found {
            let wireless = info.product_id == RECEIVER;
            let attempt = Keyboard::open(&info).and_then(|kb| {
                kb.protocol_version()?;
                if wireless {
                    // Make sure the keyboard behind the receiver is a Q6 Max.
                    match kb.identity()? {
                        Some((_, pid)) if pid == Q6_MAX => {}
                        _ => return Err(keywright_core::Error::Timeout),
                    }
                }
                let layers = kb.read_keymap(&self.rust().layout)?;
                Ok((kb, layers))
            });
            match attempt {
                Ok((kb, layers)) => {
                    let mut rust = self.as_mut().rust_mut();
                    rust.led_of = vec![None; rust.layout.keys.len()];
                    rust.led_count = 0;
                    rust.extended_rgb = false;
                    if let Ok(count) = kb.kc_rgb_led_count() {
                        if let Ok(map) = kb.kc_rgb_led_indices(rust.layout.rows, rust.layout.cols) {
                            rust.led_of = rust
                                .layout
                                .keys
                                .iter()
                                .map(|k| map[k.row as usize][k.col as usize])
                                .collect();
                            rust.led_count = count;
                            rust.extended_rgb = true;
                        }
                    }
                    rust.encoders = (0..layers.len() as u8)
                        .map(|l| Ok([kb.encoder(l, 0, false)?, kb.encoder(l, 0, true)?]))
                        .collect::<keywright_core::Result<Vec<_>>>()
                        .unwrap_or_default();
                    rust.keyboard = Some(kb);
                    rust.layers = layers;
                    self.as_mut().set_connected(true);
                    let how = if wireless { "2.4 GHz" } else { "USB cable" };
                    self.set_status(QString::from(format!("Keychron Q6 Max connected ({how})").as_str()));
                    return;
                }
                Err(e) => last_error = e.to_string(),
            }
        }
        self.as_mut().set_connected(false);
        self.set_status(QString::from(
            format!("Could not talk to the keyboard ({last_error}). Wake it by pressing a key and try Reconnect.").as_str(),
        ));
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
                    .enumerate()
                    .map(|(ki, k)| {
                        let code = codes[k.row as usize * cols + k.col as usize];
                        json!({
                            "x": k.x, "y": k.y, "w": k.w, "h": k.h,
                            "row": k.row, "col": k.col, "color": k.color,
                            "encoder": k.encoder, "code": code, "label": keycode::name(code), "led": r.led_of.get(ki).copied().flatten(),
                        })
                    })
                    .collect::<Vec<_>>()
            })
            .collect();
        let (w, h) = r.layout.size();
        let encoders: Vec<_> = r
            .encoders
            .iter()
            .map(|e| e.iter().map(|&c| json!({ "code": c, "label": keycode::name(c) })).collect::<Vec<_>>())
            .collect();
        QString::from(
            json!({ "width": w, "height": h, "layers": layers, "encoders": encoders })
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

fn theme_file() -> Option<std::path::PathBuf> {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(std::path::PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| std::path::PathBuf::from(h).join(".config")))?;
    Some(base.join("keywright").join("theme"))
}

impl qobject::Backend {
    /// Saved appearance: "system", "light" or "dark".
    fn theme(&self) -> QString {
        let saved = theme_file().and_then(|p| std::fs::read_to_string(p).ok()).unwrap_or_default();
        let mode = match saved.trim() {
            m @ ("light" | "dark") => m,
            _ => "system",
        };
        QString::from(mode)
    }

    fn set_theme(&self, mode: &QString) {
        let Some(path) = theme_file() else { return };
        if let Some(dir) = path.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let _ = std::fs::write(path, mode.to_string());
    }
}

impl qobject::Backend {
    fn rgb(&self) -> QString {
        let r = self.rust();
        let state = r.keyboard.as_ref().and_then(|kb| kb.rgb_basic().ok());
        let Some(v) = state else { return QString::from("null") };
        let effects: Vec<_> = r.layout.rgb_effects.iter().map(|(n, id)| json!({ "name": n, "id": id })).collect();
        QString::from(
            json!({
                "brightness": v.brightness, "effect": v.effect, "speed": v.speed,
                "hue": v.hue, "saturation": v.saturation, "effects": effects,
            })
            .to_string()
            .as_str(),
        )
    }

    fn set_rgb(&self, field: &QString, value: i32) -> bool {
        let id = match field.to_string().as_str() {
            "brightness" => 1,
            "effect" => 2,
            "speed" => 3,
            _ => return false,
        };
        let byte = value.clamp(0, 255) as u8;
        self.rust().keyboard.as_ref().is_some_and(|kb| kb.custom_set(keywright_core::RGB_CHANNEL, id, &[byte]).is_ok())
    }

    fn set_rgb_color(&self, hue: i32, saturation: i32) -> bool {
        let data = [hue.clamp(0, 255) as u8, saturation.clamp(0, 255) as u8];
        self.rust().keyboard.as_ref().is_some_and(|kb| kb.custom_set(keywright_core::RGB_CHANNEL, 4, &data).is_ok())
    }

    fn save_rgb(&self) -> bool {
        // Keychron firmware persists one changed value per save, so rewrite and save each value.
        self.rust()
            .keyboard
            .as_ref()
            .is_some_and(|kb| kb.rgb_basic().and_then(|v| kb.set_rgb_basic(&v, true)).is_ok())
    }
}

#[derive(serde::Deserialize, Default)]
#[serde(default)]
struct KcArgs {
    led: u8,
    leds: Vec<u8>,
    region: u8,
    index: u8,
    kind: u8,
    h: u8,
    s: u8,
    v: u8,
    effect: u8,
    hue: u8,
    sat: u8,
    speed: u8,
    time: u32,
    disabled: u8,
}

impl qobject::Backend {
    /// Everything the extended lighting pages need, as JSON; "null" when the keyboard lacks it.
    fn kc_state(&self) -> QString {
        let r = self.rust();
        let Some(kb) = r.keyboard.as_ref().filter(|_| r.extended_rgb) else { return QString::from("null") };
        let read = || -> keywright_core::Result<serde_json::Value> {
            let info = kb.kc_rgb_mixed_info()?;
            let effects: Vec<_> = (0..info.regions)
                .map(|reg| kb.kc_rgb_region_effects(reg, info.effects_per_region))
                .collect::<keywright_core::Result<_>>()?;
            Ok(json!({
                "ledCount": r.led_count,
                "perKeyType": kb.kc_rgb_per_key_type()?,
                "colors": kb.kc_rgb_per_key_colors(r.led_count)?,
                "regions": kb.kc_rgb_regions(r.led_count)?,
                "regionCount": info.regions,
                "stepsPerRegion": info.effects_per_region,
                "regionEffects": effects,
                "indicators": kb.kc_rgb_indicators()?,
            }))
        };
        match read() {
            Ok(v) => QString::from(v.to_string().as_str()),
            Err(_) => QString::from("null"),
        }
    }

    /// Apply one extended-lighting change. `args` is a JSON object; see `KcArgs` for its fields.
    fn kc_apply(&self, op: &QString, args: &QString) -> bool {
        use keywright_core::kcrgb::{Hsv, RegionEffect};
        let r = self.rust();
        let Some(kb) = r.keyboard.as_ref().filter(|_| r.extended_rgb) else { return false };
        let a: KcArgs = serde_json::from_str(&args.to_string()).unwrap_or_default();
        let hsv = Hsv { h: a.h, s: a.s, v: a.v };
        let result = match op.to_string().as_str() {
            "color" => kb.kc_rgb_set_per_key_colors(a.led, &[hsv]),
            "fill" => kb.kc_rgb_set_per_key_colors(0, &vec![hsv; r.led_count as usize]),
            "perKeyType" => kb.kc_rgb_set_per_key_type(a.kind),
            "region" => (|| {
                let mut regions = kb.kc_rgb_regions(r.led_count)?;
                for &led in &a.leds {
                    if let Some(slot) = regions.get_mut(led as usize) {
                        *slot = a.region;
                    }
                }
                kb.kc_rgb_set_regions(&regions)
            })(),
            "regionEffect" => (|| {
                let info = kb.kc_rgb_mixed_info()?;
                let mut list = kb.kc_rgb_region_effects(a.region, info.effects_per_region)?;
                let step = RegionEffect { effect: a.effect, hue: a.hue, sat: a.sat, speed: a.speed, time: a.time };
                match list.get_mut(a.index as usize) {
                    Some(slot) => *slot = step,
                    None => return Ok(()),
                }
                kb.kc_rgb_set_region_effects(a.region, &list)
            })(),
            "indicators" => kb.kc_rgb_set_indicators(&keywright_core::kcrgb::Indicators {
                available: 0,
                disabled: a.disabled,
                color: hsv,
            }),
            "save" => kb.kc_rgb_save(),
            _ => return false,
        };
        result.is_ok()
    }
}

impl qobject::Backend {
    fn set_encoder(mut self: Pin<&mut Self>, layer: i32, clockwise: bool, code: i32) -> bool {
        let written = match &self.rust().keyboard {
            Some(kb) => kb.set_encoder(layer as u8, 0, clockwise, code as u16).is_ok(),
            None => false,
        };
        if written {
            if let Some(slot) = self.as_mut().rust_mut().encoders.get_mut(layer as usize) {
                slot[clockwise as usize] = code as u16;
            }
        } else {
            self.set_status(QString::from("Could not write to the keyboard."));
        }
        written
    }
}
