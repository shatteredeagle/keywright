//! VIA raw-HID protocol client for QMK keyboards (Keychron Q6 Max first).

use hidapi::{HidApi, HidDevice};
use std::time::Duration;

pub const KEYCHRON_VID: u16 = 0x3434;
const RAW_USAGE_PAGE: u16 = 0xFF60;
const RAW_USAGE: u16 = 0x61;
const REPORT_LEN: usize = 32;
const TIMEOUT: Duration = Duration::from_millis(500);

const CMD_PROTOCOL_VERSION: u8 = 0x01;
const CMD_GET_KEYBOARD_VALUE: u8 = 0x02;
const CMD_LAYER_COUNT: u8 = 0x11;
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
}
