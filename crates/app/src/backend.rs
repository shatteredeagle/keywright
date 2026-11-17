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
        fn macros(self: &Backend) -> QString;

        #[qinvokable]
        fn set_macros(self: &Backend, json: &QString) -> QString;

        #[qinvokable]
        fn fw_status(self: &Backend) -> QString;

        #[qinvokable]
        fn fw_check(self: &Backend, path: &QString) -> QString;

        #[qinvokable]
        fn fw_backup(self: &Backend) -> QString;

        #[qinvokable]
        fn fw_flash(self: Pin<&mut Backend>, path: &QString) -> bool;

        #[qinvokable]
        fn fw_progress(self: &Backend) -> QString;

        #[qinvokable]
        fn fw_restore(self: &Backend, path: &QString) -> QString;

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
                    if let (Ok(count), Ok(map)) = (
                        kb.kc_rgb_led_count(),
                        kb.kc_rgb_led_indices(rust.layout.rows, rust.layout.cols),
                    ) {
                        rust.led_of = rust
                            .layout
                            .keys
                            .iter()
                            .map(|k| map[k.row as usize][k.col as usize])
                            .collect();
                        rust.led_count = count;
                        rust.extended_rgb = true;
                    }
                    rust.encoders = (0..layers.len() as u8)
                        .map(|l| Ok([kb.encoder(l, 0, false)?, kb.encoder(l, 0, true)?]))
                        .collect::<keywright_core::Result<Vec<_>>>()
                        .unwrap_or_default();
                    rust.keyboard = Some(kb);
                    rust.layers = layers;
                    self.as_mut().set_connected(true);
                    let how = if wireless { "2.4 GHz" } else { "USB cable" };
                    self.set_status(QString::from(
                        format!("Keychron Q6 Max connected ({how})").as_str(),
                    ));
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
            .map(|e| {
                e.iter()
                    .map(|&c| json!({ "code": c, "label": keycode::name(c) }))
                    .collect::<Vec<_>>()
            })
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

/// The platform's per-user settings folder for Keywright.
fn app_dir() -> Option<std::path::PathBuf> {
    use std::path::PathBuf;
    let base = if cfg!(target_os = "windows") {
        std::env::var_os("APPDATA").map(PathBuf::from)
    } else if cfg!(target_os = "macos") {
        std::env::var_os("HOME").map(|h| PathBuf::from(h).join("Library/Application Support"))
    } else {
        std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
    }?;
    Some(base.join("keywright"))
}

fn theme_file() -> Option<std::path::PathBuf> {
    app_dir().map(|d| d.join("theme"))
}

impl qobject::Backend {
    /// Saved appearance: "system", "light" or "dark".
    fn theme(&self) -> QString {
        let saved = theme_file()
            .and_then(|p| std::fs::read_to_string(p).ok())
            .unwrap_or_default();
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
        let Some(v) = state else {
            return QString::from("null");
        };
        let effects: Vec<_> = r
            .layout
            .rgb_effects
            .iter()
            .map(|(n, id)| json!({ "name": n, "id": id }))
            .collect();
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
        self.rust().keyboard.as_ref().is_some_and(|kb| {
            kb.custom_set(keywright_core::RGB_CHANNEL, id, &[byte])
                .is_ok()
        })
    }

    fn set_rgb_color(&self, hue: i32, saturation: i32) -> bool {
        let data = [hue.clamp(0, 255) as u8, saturation.clamp(0, 255) as u8];
        self.rust()
            .keyboard
            .as_ref()
            .is_some_and(|kb| kb.custom_set(keywright_core::RGB_CHANNEL, 4, &data).is_ok())
    }

    fn save_rgb(&self) -> bool {
        // Keychron firmware persists one changed value per save, so rewrite and save each value.
        self.rust().keyboard.as_ref().is_some_and(|kb| {
            kb.rgb_basic()
                .and_then(|v| kb.set_rgb_basic(&v, true))
                .is_ok()
        })
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
        let Some(kb) = r.keyboard.as_ref().filter(|_| r.extended_rgb) else {
            return QString::from("null");
        };
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
        let Some(kb) = r.keyboard.as_ref().filter(|_| r.extended_rgb) else {
            return false;
        };
        let a: KcArgs = serde_json::from_str(&args.to_string()).unwrap_or_default();
        let hsv = Hsv {
            h: a.h,
            s: a.s,
            v: a.v,
        };
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
                let step = RegionEffect {
                    effect: a.effect,
                    hue: a.hue,
                    sat: a.sat,
                    speed: a.speed,
                    time: a.time,
                };
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
            Some(kb) => kb
                .set_encoder(layer as u8, 0, clockwise, code as u16)
                .is_ok(),
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

impl qobject::Backend {
    /// All macro slots plus buffer usage, as JSON; "null" when the keyboard can't be read.
    fn macros(&self) -> QString {
        use keywright_core::macros;
        let Some(kb) = self.rust().keyboard.as_ref() else {
            return QString::from("null");
        };
        let read = || -> keywright_core::Result<serde_json::Value> {
            let count = kb.macro_count()? as usize;
            let buffer = kb.read_macro_buffer()?;
            let list = macros::decode(&buffer, count);
            let used = macros::encode(&list, buffer.len())
                .map(|b| b.iter().rposition(|&x| x != 0).map_or(0, |i| i + 1))
                .unwrap_or(0);
            Ok(json!({ "macros": list, "size": buffer.len(), "used": used }))
        };
        match read() {
            Ok(v) => QString::from(v.to_string().as_str()),
            Err(_) => QString::from("null"),
        }
    }

    /// Write all macros. Returns an empty string on success, otherwise a message to show.
    fn set_macros(&self, json: &QString) -> QString {
        use keywright_core::macros::{self, Macro};
        let Some(kb) = self.rust().keyboard.as_ref() else {
            return QString::from("No keyboard connected.");
        };
        let list: Vec<Macro> = match serde_json::from_str(&json.to_string()) {
            Ok(l) => l,
            Err(e) => return QString::from(format!("Could not read the macros: {e}").as_str()),
        };
        let result = kb
            .macro_buffer_size()
            .map_err(|e| e.to_string())
            .and_then(|size| macros::encode(&list, size as usize).map_err(|e| e.to_string()))
            .and_then(|buf| kb.write_macro_buffer(&buf).map_err(|e| e.to_string()));
        QString::from(result.err().unwrap_or_default().as_str())
    }
}

// ---- Firmware flashing ------------------------------------------------------------------------

/// Progress of the background flash, polled by the UI.
#[derive(Default, Clone, serde::Serialize)]
struct FlashState {
    running: bool,
    finished: bool,
    phase: Option<keywright_core::dfu::Phase>,
    done: usize,
    total: usize,
    error: Option<String>,
}

fn flash_state() -> &'static std::sync::Mutex<FlashState> {
    static STATE: std::sync::OnceLock<std::sync::Mutex<FlashState>> = std::sync::OnceLock::new();
    STATE.get_or_init(Default::default)
}

/// Firmware shipped with the app: `firmware/*.bin` beside the program or in `share/keywright/firmware`.
fn bundled_firmware() -> Option<std::path::PathBuf> {
    let exe = std::env::current_exe().ok()?;
    let dir = exe.parent()?;
    let mut candidates = vec![
        dir.join("firmware"),
        dir.join("../share/keywright/firmware"),
        dir.join("../Resources/firmware"),
    ];
    if let Some(custom) = std::env::var_os("KEYWRIGHT_FIRMWARE_DIR") {
        candidates.insert(0, std::path::PathBuf::from(custom));
    }
    candidates.into_iter().find_map(|d| {
        std::fs::read_dir(d)
            .ok()?
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .find(|p| {
                p.extension().is_some_and(|x| x == "bin")
                    && p.file_name()
                        .is_some_and(|n| n.to_string_lossy().starts_with("keywright"))
            })
    })
}

fn describe_image(path: &std::path::Path) -> serde_json::Value {
    match std::fs::read(path) {
        Err(e) => json!({ "ok": false, "problems": [format!("Could not read the file: {e}")] }),
        Ok(data) => match keywright_core::dfu::check_image(&data) {
            Ok(info) => {
                json!({ "ok": true, "path": path.to_string_lossy(), "name": path.file_name().map(|n| n.to_string_lossy().into_owned()), "size": info.size, "sha256": info.sha256 })
            }
            Err(problems) => {
                json!({ "ok": false, "path": path.to_string_lossy(), "problems": problems })
            }
        },
    }
}

impl qobject::Backend {
    /// Everything the Firmware page shows: the installed version, any bootloader attached, the bundled image.
    fn fw_status(&self) -> QString {
        let version = self
            .rust()
            .keyboard
            .as_ref()
            .and_then(|kb| kb.firmware_version().ok());
        let bootloaders = keywright_core::dfu::find_bootloaders().unwrap_or_default();
        let bundled = bundled_firmware().map(|p| {
            let mut v = describe_image(&p);
            let expected = std::fs::read_to_string(p.with_extension("bin.sha256")).ok().and_then(|t| t.split_whitespace().next().map(str::to_owned));
            if let (Some(e), Some(a)) = (&expected, v.get("sha256").and_then(|s| s.as_str())) {
                if e != a {
                    v = json!({ "ok": false, "path": p.to_string_lossy(), "problems": ["The bundled firmware does not match its checksum. Reinstall Keywright."] });
                }
            }
            v
        });
        QString::from(
            json!({
                "version": version,
                "bootloaders": bootloaders,
                "bundled": bundled,
                "os": std::env::consts::OS,
                "running": flash_state().lock().map(|s| s.running).unwrap_or(false),
            })
            .to_string()
            .as_str(),
        )
    }

    /// Validate a firmware file the user picked.
    fn fw_check(&self, path: &QString) -> QString {
        QString::from(
            describe_image(std::path::Path::new(&path.to_string()))
                .to_string()
                .as_str(),
        )
    }

    /// Save the keyboard's configuration to the app's backup folder before flashing.
    fn fw_backup(&self) -> QString {
        let result = (|| -> Result<std::path::PathBuf, String> {
            let kb = self
                .rust()
                .keyboard
                .as_ref()
                .ok_or("The keyboard is not connected.")?;
            let backup = keywright_core::backup::Backup::read(kb, &self.rust().layout)
                .map_err(|e| e.to_string())?;
            let dir = app_dir()
                .ok_or("No settings folder available.")?
                .join("backups");
            std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
            let stamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0);
            let path = dir.join(format!("q6-max-{stamp}.json"));
            let text = serde_json::to_string_pretty(&backup).map_err(|e| e.to_string())?;
            std::fs::write(&path, text).map_err(|e| e.to_string())?;
            Ok(path)
        })();
        match result {
            Ok(p) => QString::from(
                json!({ "ok": true, "path": p.to_string_lossy() })
                    .to_string()
                    .as_str(),
            ),
            Err(e) => QString::from(json!({ "ok": false, "error": e }).to_string().as_str()),
        }
    }

    /// Start flashing `path` on a background thread. The keyboard must already be in bootloader mode.
    fn fw_flash(mut self: Pin<&mut Self>, path: &QString) -> bool {
        {
            let mut st = flash_state().lock().unwrap();
            if st.running {
                return false;
            }
            *st = FlashState {
                running: true,
                ..Default::default()
            };
        }
        // The keyboard is about to disappear, so let go of it.
        self.as_mut().rust_mut().keyboard = None;
        self.as_mut().set_connected(false);
        self.as_mut().set_status(QString::from(
            "Flashing firmware. Do not unplug the keyboard.",
        ));

        let path = path.to_string();
        std::thread::spawn(move || {
            let outcome = (|| -> Result<(), String> {
                let data = std::fs::read(&path)
                    .map_err(|e| format!("Could not read the firmware file: {e}"))?;
                let bootloader =
                    keywright_core::dfu::Bootloader::open_only().map_err(|e| e.to_string())?;
                bootloader
                    .flash(&data, |phase, done, total| {
                        if let Ok(mut st) = flash_state().lock() {
                            st.phase = Some(phase);
                            st.done = done;
                            st.total = total;
                        }
                    })
                    .map_err(|e| e.to_string())
            })();
            if let Ok(mut st) = flash_state().lock() {
                st.running = false;
                st.finished = true;
                st.error = outcome.err();
            }
        });
        true
    }

    fn fw_progress(&self) -> QString {
        let st = flash_state().lock().map(|s| s.clone()).unwrap_or_default();
        QString::from(serde_json::to_string(&st).unwrap_or_default().as_str())
    }

    /// Write a saved backup back to the keyboard. Returns an empty string on success.
    fn fw_restore(&self, path: &QString) -> QString {
        let result = (|| -> Result<(), String> {
            let kb = self
                .rust()
                .keyboard
                .as_ref()
                .ok_or("The keyboard is not connected.")?;
            let text = std::fs::read_to_string(path.to_string()).map_err(|e| e.to_string())?;
            let backup: keywright_core::backup::Backup =
                serde_json::from_str(&text).map_err(|e| e.to_string())?;
            backup.restore(kb).map_err(|e| e.to_string())
        })();
        QString::from(result.err().unwrap_or_default().as_str())
    }
}
