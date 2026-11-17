//! STM32 DfuSe bootloader client: find the bootloader, check a firmware image, flash and verify it.
//!
//! Flashing replaces the keyboard's firmware. Everything here is deliberately conservative: only
//! sectors the image covers are erased, the result is read back and compared, and an image is
//! refused unless it looks like a firmware for this chip.

use crate::{Error, Result};
use rusb::{Context, DeviceHandle, Direction, Recipient, RequestType, UsbContext, request_type};
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::time::Duration;

pub const ST_VID: u16 = 0x0483;
pub const DFU_PID: u16 = 0xDF11;
/// Flash starts here on STM32 parts and the firmware is linked for this address.
pub const FLASH_START: u32 = 0x0800_0000;
/// The Q6 Max's STM32F401 has 256 KB of flash and 64 KB of RAM.
const FLASH_SIZE: u32 = 256 * 1024;
const RAM_START: u32 = 0x2000_0000;
const RAM_END: u32 = 0x2001_0000;
const TRANSFER_SIZE: usize = 2048;
const TIMEOUT: Duration = Duration::from_secs(5);

const DFU_DNLOAD: u8 = 1;
const DFU_UPLOAD: u8 = 2;
const DFU_GETSTATUS: u8 = 3;
const DFU_CLRSTATUS: u8 = 4;
const DFU_ABORT: u8 = 6;

const STATE_IDLE: u8 = 2;
const STATE_DNLOAD_IDLE: u8 = 5;
const STATE_DNBUSY: u8 = 4;
const STATE_ERROR: u8 = 10;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct BootloaderInfo {
    pub bus: u8,
    pub address: u8,
    pub serial: String,
    /// The bootloader's description of its internal flash, e.g. `@Internal Flash /0x08000000/04*016Kg,...`.
    pub layout: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FlashLayout {
    pub start: u32,
    /// `(address, size)` of every erase sector, in order.
    pub sectors: Vec<(u32, u32)>,
}

impl FlashLayout {
    /// Parse a DfuSe memory string such as `@Internal Flash  /0x08000000/04*016Kg,01*064Kg,01*128Kg`.
    pub fn parse(s: &str) -> Option<Self> {
        let mut parts = s.split('/');
        parts.next()?;
        let start = u32::from_str_radix(parts.next()?.trim().trim_start_matches("0x"), 16).ok()?;
        let mut sectors = Vec::new();
        let mut addr = start;
        for group in parts.next()?.split(',') {
            let (count, rest) = group.trim().split_once('*')?;
            let count: u32 = count.trim().parse().ok()?;
            let digits: String = rest.chars().take_while(char::is_ascii_digit).collect();
            let unit = rest[digits.len()..].chars().next()?;
            let mut size: u32 = digits.parse().ok()?;
            size *= match unit {
                'K' => 1024,
                'M' => 1024 * 1024,
                'B' => 1,
                _ => return None,
            };
            for _ in 0..count {
                sectors.push((addr, size));
                addr += size;
            }
        }
        Some(Self { start, sectors })
    }

    pub fn total(&self) -> u32 {
        self.sectors.iter().map(|s| s.1).sum()
    }

    /// Sectors that overlap `len` bytes written from the start of flash.
    pub fn sectors_for(&self, len: u32) -> Vec<(u32, u32)> {
        self.sectors.iter().copied().filter(|&(a, _)| a < self.start + len).collect()
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct ImageInfo {
    pub size: usize,
    pub sha256: String,
    pub stack_pointer: u32,
    pub reset_vector: u32,
}

/// Check that `data` looks like firmware for this chip. Returns every problem found.
pub fn check_image(data: &[u8]) -> std::result::Result<ImageInfo, Vec<String>> {
    let mut problems = Vec::new();
    if data.len() < 1024 {
        problems.push(format!("The file is only {} bytes, far too small for firmware.", data.len()));
        return Err(problems);
    }
    if data.len() as u32 > FLASH_SIZE {
        problems.push(format!("The file is {} bytes, larger than the keyboard's {} KB of flash.", data.len(), FLASH_SIZE / 1024));
    }
    let word = |i: usize| u32::from_le_bytes([data[i], data[i + 1], data[i + 2], data[i + 3]]);
    let (sp, reset) = (word(0), word(4));
    if !(RAM_START..=RAM_END).contains(&sp) {
        problems.push(format!("The first word ({sp:#010x}) is not a valid stack address for this chip, so this is probably not a raw .bin firmware."));
    }
    if reset & 1 == 0 || !(FLASH_START..FLASH_START + FLASH_SIZE).contains(&(reset & !1)) {
        problems.push(format!("The reset vector ({reset:#010x}) does not point into this chip's flash."));
    }
    if problems.is_empty() {
        Ok(ImageInfo { size: data.len(), sha256: sha256_hex(data), stack_pointer: sp, reset_vector: reset })
    } else {
        Err(problems)
    }
}

pub fn sha256_hex(data: &[u8]) -> String {
    Sha256::digest(data).iter().map(|b| format!("{b:02x}")).collect()
}

/// What stage a flash operation is in.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Phase {
    Erase,
    Write,
    Verify,
    Restart,
}

/// Every STM32 bootloader currently attached.
pub fn find_bootloaders() -> Result<Vec<BootloaderInfo>> {
    let ctx = Context::new()?;
    let mut found = Vec::new();
    for device in ctx.devices()?.iter() {
        let Ok(desc) = device.device_descriptor() else { continue };
        if desc.vendor_id() != ST_VID || desc.product_id() != DFU_PID {
            continue;
        }
        let (mut serial, mut layout) = (String::new(), String::new());
        if let Ok(handle) = device.open() {
            serial = desc.serial_number_string_index().and_then(|i| handle.read_string_descriptor_ascii(i).ok()).unwrap_or_default();
            layout = flash_layout_string(&device, &handle).unwrap_or_default();
        }
        found.push(BootloaderInfo { bus: device.bus_number(), address: device.address(), serial, layout });
    }
    Ok(found)
}

fn flash_layout_string(device: &rusb::Device<Context>, handle: &DeviceHandle<Context>) -> Option<String> {
    let config = device.active_config_descriptor().ok()?;
    for interface in config.interfaces() {
        for setting in interface.descriptors() {
            if setting.interface_number() == 0 && setting.setting_number() == 0 {
                let idx = setting.description_string_index()?;
                return handle.read_string_descriptor_ascii(idx).ok();
            }
        }
    }
    None
}

pub struct Bootloader {
    handle: DeviceHandle<Context>,
    pub layout: FlashLayout,
}

impl Bootloader {
    /// Open the one attached bootloader. Refuses when there is not exactly one, because the
    /// bootloader cannot say which keyboard it belongs to.
    pub fn open_only() -> Result<Self> {
        let ctx = Context::new()?;
        let matches: Vec<_> = ctx
            .devices()?
            .iter()
            .filter(|d| d.device_descriptor().map(|x| x.vendor_id() == ST_VID && x.product_id() == DFU_PID).unwrap_or(false))
            .collect();
        match matches.len() {
            0 => return Err(Error::Dfu("No bootloader found. Put the keyboard in bootloader mode first.".into())),
            1 => {}
            n => return Err(Error::Dfu(format!("{n} STM32 bootloaders are attached. Unplug the others so only the keyboard remains."))),
        }
        let device = &matches[0];
        let handle = device.open().map_err(|e| Error::Dfu(open_hint(e)))?;
        let layout_str = flash_layout_string(device, &handle).ok_or_else(|| Error::Dfu("The bootloader did not describe its flash.".into()))?;
        let layout = FlashLayout::parse(&layout_str).ok_or_else(|| Error::Dfu(format!("Unrecognised flash layout: {layout_str}")))?;
        if layout.start != FLASH_START || layout.total() != FLASH_SIZE {
            return Err(Error::Dfu(format!(
                "This bootloader reports {} KB of flash at {:#x}. Keywright only flashes the Q6 Max's 256 KB STM32F401.",
                layout.total() / 1024,
                layout.start
            )));
        }
        let mut handle = handle;
        let _ = handle.set_auto_detach_kernel_driver(true);
        handle.claim_interface(0).map_err(|e| Error::Dfu(open_hint(e)))?;
        handle.set_alternate_setting(0, 0)?;
        Ok(Self { handle, layout })
    }

    fn status(&self) -> Result<(u8, u32, u8)> {
        let mut b = [0u8; 6];
        self.handle.read_control(request_type(Direction::In, RequestType::Class, Recipient::Interface), DFU_GETSTATUS, 0, 0, &mut b, TIMEOUT)?;
        Ok((b[0], u32::from_le_bytes([b[1], b[2], b[3], 0]), b[4]))
    }

    fn request_out(&self, req: u8, value: u16, data: &[u8]) -> Result<()> {
        self.handle.write_control(request_type(Direction::Out, RequestType::Class, Recipient::Interface), req, value, 0, data, TIMEOUT)?;
        Ok(())
    }

    fn clear_error(&self) -> Result<()> {
        for _ in 0..4 {
            let (_, _, state) = self.status()?;
            match state {
                STATE_IDLE => return Ok(()),
                STATE_ERROR => self.request_out(DFU_CLRSTATUS, 0, &[])?,
                _ => self.request_out(DFU_ABORT, 0, &[])?,
            }
        }
        Err(Error::Dfu("The bootloader would not return to idle.".into()))
    }

    /// Wait for a download request to finish.
    fn settle(&self) -> Result<()> {
        for _ in 0..200 {
            let (status, poll, state) = self.status()?;
            if status != 0 {
                return Err(Error::Dfu(format!("The bootloader reported error code {status}.")));
            }
            if state == STATE_DNBUSY {
                std::thread::sleep(Duration::from_millis(poll.max(1) as u64));
                continue;
            }
            if state == STATE_DNLOAD_IDLE || state == STATE_IDLE {
                return Ok(());
            }
            if state == STATE_ERROR {
                return Err(Error::Dfu("The bootloader entered its error state.".into()));
            }
        }
        Err(Error::Dfu("The bootloader did not finish in time.".into()))
    }

    /// DfuSe command: `0x21` sets the address pointer, `0x41` erases the sector at an address.
    fn command(&self, op: u8, addr: u32) -> Result<()> {
        let a = addr.to_le_bytes();
        self.request_out(DFU_DNLOAD, 0, &[op, a[0], a[1], a[2], a[3]])?;
        self.settle()?;
        // Back to idle so the next block request is accepted.
        self.request_out(DFU_ABORT, 0, &[])?;
        Ok(())
    }

    fn read_block(&self, block: u16, len: usize) -> Result<Vec<u8>> {
        let mut buf = vec![0u8; len];
        let n = self.handle.read_control(request_type(Direction::In, RequestType::Class, Recipient::Interface), DFU_UPLOAD, block, 0, &mut buf, TIMEOUT)?;
        buf.truncate(n);
        Ok(buf)
    }

    /// Erase, write, verify and restart. `progress` is called with the phase and how far along it is.
    pub fn flash(&self, image: &[u8], mut progress: impl FnMut(Phase, usize, usize)) -> Result<()> {
        check_image(image).map_err(|p| Error::Dfu(p.join(" ")))?;
        self.clear_error()?;

        let sectors = self.layout.sectors_for(image.len() as u32);
        for (i, &(addr, _)) in sectors.iter().enumerate() {
            progress(Phase::Erase, i, sectors.len());
            self.command(0x41, addr)?;
        }
        progress(Phase::Erase, sectors.len(), sectors.len());

        self.command(0x21, FLASH_START)?;
        let blocks = image.len().div_ceil(TRANSFER_SIZE);
        for (i, chunk) in image.chunks(TRANSFER_SIZE).enumerate() {
            progress(Phase::Write, i, blocks);
            self.request_out(DFU_DNLOAD, 2 + i as u16, chunk)?;
            self.settle()?;
        }
        progress(Phase::Write, blocks, blocks);
        self.request_out(DFU_ABORT, 0, &[])?;

        // Read everything back and compare before the keyboard is allowed to run it.
        self.command(0x21, FLASH_START)?;
        for (i, chunk) in image.chunks(TRANSFER_SIZE).enumerate() {
            progress(Phase::Verify, i, blocks);
            let back = self.read_block(2 + i as u16, chunk.len())?;
            if back != chunk {
                return Err(Error::Dfu(format!("Verification failed in block {i}: the keyboard holds different data than was written. Do not unplug it. Flash again.")));
            }
        }
        progress(Phase::Verify, blocks, blocks);
        self.request_out(DFU_ABORT, 0, &[])?;

        // Leave the bootloader and run the new firmware.
        progress(Phase::Restart, 0, 1);
        self.command(0x21, FLASH_START)?;
        let _ = self.request_out(DFU_DNLOAD, 0, &[]);
        let _ = self.status();
        progress(Phase::Restart, 1, 1);
        Ok(())
    }
}

fn open_hint(e: rusb::Error) -> String {
    let base = format!("Could not open the bootloader ({e}).");
    if cfg!(target_os = "windows") {
        format!("{base} On Windows the bootloader needs the WinUSB driver; install it with Zadig, then try again.")
    } else if cfg!(target_os = "linux") {
        format!("{base} Check that the udev rule from the Keywright package is installed, then unplug and replug the keyboard.")
    } else {
        base
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LAYOUT: &str = "@Internal Flash  /0x08000000/04*016Kg,01*064Kg,01*128Kg";

    #[test]
    fn parses_the_stm32f401_layout() {
        let l = FlashLayout::parse(LAYOUT).unwrap();
        assert_eq!(l.start, 0x0800_0000);
        assert_eq!(l.sectors.len(), 6);
        assert_eq!(l.total(), 256 * 1024);
        assert_eq!(l.sectors[4], (0x0801_0000, 64 * 1024));
        assert_eq!(l.sectors[5], (0x0802_0000, 128 * 1024));
    }

    #[test]
    fn erases_only_the_sectors_an_image_covers() {
        let l = FlashLayout::parse(LAYOUT).unwrap();
        assert_eq!(l.sectors_for(100_000).len(), 5); // 4x16K + 64K = 128K covers 100 KB? no: sector 5 starts at 128K
        assert_eq!(l.sectors_for(140_000).len(), 6);
        assert_eq!(l.sectors_for(1).len(), 1);
    }

    #[test]
    fn rejects_things_that_are_not_firmware() {
        assert!(check_image(&[0u8; 100]).is_err());
        let mut img = vec![0u8; 4096];
        assert!(check_image(&img).is_err()); // zero stack pointer
        img[..4].copy_from_slice(&0x2000_0400u32.to_le_bytes());
        img[4..8].copy_from_slice(&0x0800_811du32.to_le_bytes());
        assert!(check_image(&img).is_ok());
        img[4..8].copy_from_slice(&0x0800_811cu32.to_le_bytes()); // not a Thumb address
        assert!(check_image(&img).is_err());
        let mut huge = vec![0u8; 300 * 1024];
        huge[..4].copy_from_slice(&0x2000_0400u32.to_le_bytes());
        huge[4..8].copy_from_slice(&0x0800_811du32.to_le_bytes());
        assert!(check_image(&huge).is_err());
    }
}
