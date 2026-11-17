//! Keychron's extended RGB protocol (raw HID command 0xA8): per-key colours, mixed-effect
//! regions, indicator LEDs. Layout follows `keyboards/keychron/common/rgb/keychron_rgb.c`.

use crate::{Error, Keyboard, Result};

const CMD: u8 = 0xA8;
const SAVE: u8 = 0x02;
const GET_INDICATORS: u8 = 0x03;
const SET_INDICATORS: u8 = 0x04;
const LED_COUNT: u8 = 0x05;
const LED_INDEX: u8 = 0x06;
const PK_GET_TYPE: u8 = 0x07;
const PK_SET_TYPE: u8 = 0x08;
const PK_GET_COLOR: u8 = 0x09;
const PK_SET_COLOR: u8 = 0x0A;
const MIXED_INFO: u8 = 0x0B;
const MIXED_GET_REGIONS: u8 = 0x0C;
const MIXED_SET_REGIONS: u8 = 0x0D;
const MIXED_GET_EFFECTS: u8 = 0x0E;
const MIXED_SET_EFFECTS: u8 = 0x0F;

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Hsv {
    pub h: u8,
    pub s: u8,
    pub v: u8,
}

/// One step of a mixed-effect region's playlist.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct RegionEffect {
    pub effect: u8,
    pub hue: u8,
    pub sat: u8,
    pub speed: u8,
    /// How long the step plays, in milliseconds.
    pub time: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Indicators {
    /// Which lock LEDs this keyboard has (bit 0 Num, 1 Caps, 2 Scroll, 3 Compose, 4 Kana).
    pub available: u8,
    /// Which indicators are switched off (same bits).
    pub disabled: u8,
    pub color: Hsv,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MixedInfo {
    pub regions: u8,
    pub effects_per_region: u8,
}

impl Keyboard {
    /// Send an 0xA8 request and check the firmware's status byte (reply byte 2).
    fn kc_rgb(&self, sub: u8, args: &[u8]) -> Result<[u8; 32]> {
        let mut req = vec![CMD, sub];
        req.extend_from_slice(args);
        let r = self.raw_xfer(&req)?;
        if r[2] != 0 {
            return Err(Error::Rejected(sub));
        }
        Ok(r)
    }

    pub fn kc_rgb_led_count(&self) -> Result<u8> {
        Ok(self.kc_rgb(LED_COUNT, &[])?[3])
    }

    /// LED index for every `(row, col)` of the matrix; `None` where the position has no LED.
    pub fn kc_rgb_led_indices(&self, rows: u8, cols: u8) -> Result<Vec<Vec<Option<u8>>>> {
        let mask = (1u32 << cols) - 1;
        let m = mask.to_le_bytes();
        (0..rows)
            .map(|row| {
                let r = self.kc_rgb(LED_INDEX, &[row, m[0], m[1], m[2]])?;
                Ok((0..cols as usize).map(|c| Some(r[3 + c]).filter(|&i| i != 0xFF)).collect())
            })
            .collect()
    }

    pub fn kc_rgb_per_key_type(&self) -> Result<u8> {
        Ok(self.kc_rgb(PK_GET_TYPE, &[])?[3])
    }

    pub fn kc_rgb_set_per_key_type(&self, kind: u8) -> Result<()> {
        self.kc_rgb(PK_SET_TYPE, &[kind]).map(drop)
    }

    pub fn kc_rgb_per_key_colors(&self, count: u8) -> Result<Vec<Hsv>> {
        let mut out = Vec::with_capacity(count as usize);
        while out.len() < count as usize {
            let n = (count as usize - out.len()).min(9) as u8;
            let r = self.kc_rgb(PK_GET_COLOR, &[out.len() as u8, n])?;
            out.extend((0..n as usize).map(|i| Hsv { h: r[3 + i * 3], s: r[4 + i * 3], v: r[5 + i * 3] }));
        }
        Ok(out)
    }

    pub fn kc_rgb_set_per_key_colors(&self, start: u8, colors: &[Hsv]) -> Result<()> {
        for (chunk_i, chunk) in colors.chunks(9).enumerate() {
            let mut args = vec![start + (chunk_i * 9) as u8, chunk.len() as u8];
            for c in chunk {
                args.extend_from_slice(&[c.h, c.s, c.v]);
            }
            self.kc_rgb(PK_SET_COLOR, &args)?;
        }
        Ok(())
    }

    pub fn kc_rgb_mixed_info(&self) -> Result<MixedInfo> {
        let r = self.kc_rgb(MIXED_INFO, &[])?;
        Ok(MixedInfo { regions: r[3], effects_per_region: r[4] })
    }

    /// Which region each LED belongs to.
    pub fn kc_rgb_regions(&self, led_count: u8) -> Result<Vec<u8>> {
        let mut out = Vec::with_capacity(led_count as usize);
        while out.len() < led_count as usize {
            let n = (led_count as usize - out.len()).min(28) as u8;
            let r = self.kc_rgb(MIXED_GET_REGIONS, &[out.len() as u8, n])?;
            out.extend_from_slice(&r[3..3 + n as usize]);
        }
        Ok(out)
    }

    pub fn kc_rgb_set_regions(&self, regions: &[u8]) -> Result<()> {
        for (i, chunk) in regions.chunks(28).enumerate() {
            let mut args = vec![(i * 28) as u8, chunk.len() as u8];
            args.extend_from_slice(chunk);
            self.kc_rgb(MIXED_SET_REGIONS, &args)?;
        }
        Ok(())
    }

    pub fn kc_rgb_region_effects(&self, region: u8, count: u8) -> Result<Vec<RegionEffect>> {
        let mut out = Vec::new();
        while out.len() < count as usize {
            let n = (count as usize - out.len()).min(3) as u8;
            let r = self.kc_rgb(MIXED_GET_EFFECTS, &[region, out.len() as u8, n])?;
            out.extend((0..n as usize).map(|i| {
                let o = 3 + i * 8;
                RegionEffect {
                    effect: r[o],
                    hue: r[o + 1],
                    sat: r[o + 2],
                    speed: r[o + 3],
                    time: u32::from_le_bytes([r[o + 4], r[o + 5], r[o + 6], r[o + 7]]),
                }
            }));
        }
        Ok(out)
    }

    pub fn kc_rgb_set_region_effects(&self, region: u8, effects: &[RegionEffect]) -> Result<()> {
        for (chunk_i, chunk) in effects.chunks(3).enumerate() {
            let mut args = vec![region, (chunk_i * 3) as u8, chunk.len() as u8];
            for e in chunk {
                args.extend_from_slice(&[e.effect, e.hue, e.sat, e.speed]);
                args.extend_from_slice(&e.time.to_le_bytes());
            }
            self.kc_rgb(MIXED_SET_EFFECTS, &args)?;
        }
        Ok(())
    }

    pub fn kc_rgb_indicators(&self) -> Result<Indicators> {
        let r = self.kc_rgb(GET_INDICATORS, &[])?;
        Ok(Indicators { available: r[3], disabled: r[4], color: Hsv { h: r[5], s: r[6], v: r[7] } })
    }

    pub fn kc_rgb_set_indicators(&self, i: &Indicators) -> Result<()> {
        self.kc_rgb(SET_INDICATORS, &[i.disabled, i.color.h, i.color.s, i.color.v]).map(drop)
    }

    /// Persist per-key colours, regions, effect lists and indicator settings.
    pub fn kc_rgb_save(&self) -> Result<()> {
        self.kc_rgb(SAVE, &[]).map(drop)
    }
}
