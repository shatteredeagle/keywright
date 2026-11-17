//! VIA raw-HID protocol client for QMK keyboards (Keychron Q6 Max first).

pub mod backup;
pub mod keycode;
pub mod layout;

use hidapi::{HidApi, HidDevice};
use std::time::Duration;

pub const KEYCHRON_VID: u16 = 0x3434;
const RAW_USAGE_PAGE: u16 = 0xFF60;
const RAW_USAGE: u16 = 0x61;
const REPORT_LEN: usize = 32;
const TIMEOUT: Duration = Duration::from_millis(500);

const CMD_PROTOCOL_VERSION: u8 = 0x01;
const CMD_GET_KEYBOARD_VALUE: u8 = 0x02;
const CMD_SET_KEYCODE: u8 = 0x05;
const CMD_SET_VALUE: u8 = 0x07;
const CMD_GET_VALUE: u8 = 0x08;
const CMD_SAVE_VALUES: u8 = 0x09;
const CMD_KEYCHRON_RGB: u8 = 0xA8;
const CMD_MACRO_BUFFER_SIZE: u8 = 0x0D;
const CMD_MACRO_GET_BUFFER: u8 = 0x0E;
const CMD_MACRO_SET_BUFFER: u8 = 0x0F;
const CMD_LAYER_COUNT: u8 = 0x11;
const CMD_KEYMAP_SET_BUFFER: u8 = 0x13;
const CMD_ENCODER_GET: u8 = 0x14;
const CMD_ENCODER_SET: u8 = 0x15;
const CMD_KC_FIRMWARE_VERSION: u8 = 0xA1;
const CMD_KEYMAP_BUFFER: u8 = 0x12;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("hid: {0}")]
    Hid(#[from] hidapi::HidError),
    #[error("no reply from device")]
    Timeout,
    #[error("device does not support command {0:#04x}")]
    Unhandled(u8),
}

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Clone)]
pub struct DeviceInfo {
    pub product_id: u16,
    pub product: String,
    pub path: String,
}

/// Find every Keychron raw-HID (VIA) endpoint: keyboards on a cable and 2.4 GHz receivers.
pub fn enumerate() -> Result<Vec<DeviceInfo>> {
    let api = HidApi::new()?;
    Ok(api
        .device_list()
        .filter(|d| {
            d.vendor_id() == KEYCHRON_VID
                && d.usage_page() == RAW_USAGE_PAGE
                && d.usage() == RAW_USAGE
        })
        .map(|d| DeviceInfo {
            product_id: d.product_id(),
            product: d.product_string().unwrap_or("?").trim().to_string(),
            path: d.path().to_string_lossy().into_owned(),
        })
        .collect())
}

pub struct Keyboard {
    dev: HidDevice,
}

impl Keyboard {
    pub fn open(info: &DeviceInfo) -> Result<Self> {
        let api = HidApi::new()?;
        let path = std::ffi::CString::new(info.path.clone()).expect("path has no NUL");
        Ok(Self { dev: api.open_path(&path)? })
    }

    /// Send one 32-byte request and return the 32-byte reply.
    fn xfer(&self, req: &[u8]) -> Result<[u8; REPORT_LEN]> {
        // hidapi wants a leading report-id byte; VIA uses no report ids, so 0.
        let mut out = [0u8; REPORT_LEN + 1];
        out[1..1 + req.len()].copy_from_slice(req);
        self.dev.write(&out)?;
        let mut reply = [0u8; REPORT_LEN];
        let n = self.dev.read_timeout(&mut reply, TIMEOUT.as_millis() as i32)?;
        if n == 0 {
            return Err(Error::Timeout);
        }
        if reply[0] == 0xFF {
            return Err(Error::Unhandled(req[0]));
        }
        Ok(reply)
    }

    pub fn protocol_version(&self) -> Result<u16> {
        let r = self.xfer(&[CMD_PROTOCOL_VERSION])?;
        Ok(u16::from_be_bytes([r[1], r[2]]))
    }

    pub fn uptime_ms(&self) -> Result<u32> {
        let r = self.xfer(&[CMD_GET_KEYBOARD_VALUE, 0x01])?;
        Ok(u32::from_be_bytes([r[2], r[3], r[4], r[5]]))
    }

    pub fn layer_count(&self) -> Result<u8> {
        Ok(self.xfer(&[CMD_LAYER_COUNT])?[1])
    }

    /// Read `rows * cols` keycodes for one layer.
    pub fn read_layer(&self, layer: u8, rows: usize, cols: usize) -> Result<Vec<u16>> {
        let total = rows * cols * 2;
        let base = layer as usize * total;
        let mut bytes = Vec::with_capacity(total);
        while bytes.len() < total {
            let off = (base + bytes.len()) as u16;
            let n = (total - bytes.len()).min(28) as u8;
            let o = off.to_be_bytes();
            let r = self.xfer(&[CMD_KEYMAP_BUFFER, o[0], o[1], n])?;
            bytes.extend_from_slice(&r[4..4 + n as usize]);
        }
        Ok(bytes.chunks(2).map(|c| u16::from_be_bytes([c[0], c[1]])).collect())
    }

    /// Read one VIA custom value (`channel`, `value_id`); returns the payload after the echoed ids.
    pub fn custom_get(&self, channel: u8, value_id: u8) -> Result<[u8; 4]> {
        let r = self.xfer(&[CMD_GET_VALUE, channel, value_id])?;
        Ok([r[3], r[4], r[5], r[6]])
    }

    /// Write one keycode; the keyboard stores it immediately.
    pub fn set_keycode(&self, layer: u8, row: u8, col: u8, code: u16) -> Result<()> {
        let c = code.to_be_bytes();
        self.xfer(&[CMD_SET_KEYCODE, layer, row, col, c[0], c[1]]).map(drop)
    }

    /// Write a VIA custom value to RAM. Call `save_channel` to persist it.
    pub fn custom_set(&self, channel: u8, value_id: u8, data: &[u8]) -> Result<()> {
        let mut req = vec![CMD_SET_VALUE, channel, value_id];
        req.extend_from_slice(data);
        self.xfer(&req).map(drop)
    }

    pub fn save_channel(&self, channel: u8) -> Result<()> {
        self.xfer(&[CMD_SAVE_VALUES, channel]).map(drop)
    }

    /// Apply backlight settings; with `save` they survive a power cycle.
    /// The firmware clamps brightness 255 to 254 on write, so callers should not rewrite untouched fields.
    pub fn set_rgb_basic(&self, v: &RgbBasic, save: bool) -> Result<()> {
        // Keychron's firmware persists only when a single value changed since the last save,
        // so each value is saved on its own.
        let writes: [(u8, &[u8]); 4] = [
            (1, &[v.brightness]),
            (2, &[v.effect]),
            (3, &[v.speed]),
            (4, &[v.hue, v.saturation]),
        ];
        for (id, data) in writes {
            self.custom_set(RGB_CHANNEL, id, data)?;
            if save {
                self.save_channel(RGB_CHANNEL)?;
            }
        }
        Ok(())
    }

    /// Basic backlight state: brightness, effect, speed, hue, saturation.
    pub fn rgb_basic(&self) -> Result<RgbBasic> {
        let get = |id| self.custom_get(RGB_CHANNEL, id);
        let color = get(4)?;
        Ok(RgbBasic {
            brightness: get(1)?[0],
            effect: get(2)?[0],
            speed: get(3)?[0],
            hue: color[0],
            saturation: color[1],
        })
    }

    /// Keychron RGB extension: protocol version and LED count.
    pub fn keychron_rgb_info(&self) -> Result<(u8, u8)> {
        let ver = self.xfer(&[CMD_KEYCHRON_RGB, 0x01])?;
        let leds = self.xfer(&[CMD_KEYCHRON_RGB, 0x05])?;
        Ok((ver[3], leds[3]))
    }

    /// Keychron firmware version string (VIA protocol 0xA1).
    pub fn firmware_version(&self) -> Result<String> {
        let r = self.xfer(&[CMD_KC_FIRMWARE_VERSION])?;
        let end = r[1..].iter().position(|&b| b == 0).unwrap_or(REPORT_LEN - 1);
        Ok(String::from_utf8_lossy(&r[1..1 + end]).into_owned())
    }

    pub fn macro_buffer_size(&self) -> Result<u16> {
        let r = self.xfer(&[CMD_MACRO_BUFFER_SIZE])?;
        Ok(u16::from_be_bytes([r[1], r[2]]))
    }

    pub fn read_macro_buffer(&self) -> Result<Vec<u8>> {
        let total = self.macro_buffer_size()? as usize;
        let mut out = Vec::with_capacity(total);
        while out.len() < total {
            let o = (out.len() as u16).to_be_bytes();
            let n = (total - out.len()).min(28) as u8;
            let r = self.xfer(&[CMD_MACRO_GET_BUFFER, o[0], o[1], n])?;
            out.extend_from_slice(&r[4..4 + n as usize]);
        }
        Ok(out)
    }

    pub fn write_macro_buffer(&self, data: &[u8]) -> Result<()> {
        for (i, chunk) in data.chunks(28).enumerate() {
            let o = ((i * 28) as u16).to_be_bytes();
            let mut req = vec![CMD_MACRO_SET_BUFFER, o[0], o[1], chunk.len() as u8];
            req.extend_from_slice(chunk);
            self.xfer(&req)?;
        }
        Ok(())
    }

    /// Encoder (knob) binding for one layer: `clockwise` selects the direction.
    pub fn encoder(&self, layer: u8, index: u8, clockwise: bool) -> Result<u16> {
        let r = self.xfer(&[CMD_ENCODER_GET, layer, index, clockwise as u8])?;
        Ok(u16::from_be_bytes([r[4], r[5]]))
    }

    pub fn set_encoder(&self, layer: u8, index: u8, clockwise: bool, code: u16) -> Result<()> {
        let c = code.to_be_bytes();
        self.xfer(&[CMD_ENCODER_SET, layer, index, clockwise as u8, c[0], c[1]]).map(drop)
    }

    /// Replace one whole layer at once.
    pub fn write_layer(&self, layer: u8, codes: &[u16]) -> Result<()> {
        let bytes: Vec<u8> = codes.iter().flat_map(|c| c.to_be_bytes()).collect();
        let base = layer as usize * bytes.len();
        for (i, chunk) in bytes.chunks(28).enumerate() {
            let o = ((base + i * 28) as u16).to_be_bytes();
            let mut req = vec![CMD_KEYMAP_SET_BUFFER, o[0], o[1], chunk.len() as u8];
            req.extend_from_slice(chunk);
            self.xfer(&req)?;
        }
        Ok(())
    }

    /// Read every layer as a map keyed by (row, col) from the layout.
    pub fn read_keymap(&self, layout: &layout::Layout) -> Result<Vec<Vec<u16>>> {
        let layers = self.layer_count()?;
        (0..layers)
            .map(|l| self.read_layer(l, layout.rows as usize, layout.cols as usize))
            .collect()
    }
}

pub const RGB_CHANNEL: u8 = 3;

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct RgbBasic {
    pub brightness: u8,
    pub effect: u8,
    pub speed: u8,
    pub hue: u8,
    pub saturation: u8,
}
