//! Export and restore everything the app can configure, so firmware can be reflashed safely.

use crate::{Keyboard, Result, RgbBasic, layout::Layout};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct Backup {
    pub format: u32,
    pub keyboard: String,
    pub firmware: String,
    pub rows: u8,
    pub cols: u8,
    /// One `rows * cols` keycode grid per layer, in matrix order.
    pub layers: Vec<Vec<u16>>,
    /// `[layer][direction]` for knob 0: direction 0 is counter-clockwise, 1 clockwise.
    pub encoders: Vec<[u16; 2]>,
    pub macro_buffer: Vec<u8>,
    pub rgb: RgbBasic,
}

impl Backup {
    pub fn read(kb: &Keyboard, layout: &Layout) -> Result<Self> {
        let layers = kb.read_keymap(layout)?;
        let encoders = (0..layers.len() as u8)
            .map(|l| Ok([kb.encoder(l, 0, false)?, kb.encoder(l, 0, true)?]))
            .collect::<Result<Vec<_>>>()?;
        Ok(Self {
            format: 1,
            keyboard: layout.name.clone(),
            firmware: kb.firmware_version().unwrap_or_default(),
            rows: layout.rows,
            cols: layout.cols,
            layers,
            encoders,
            macro_buffer: kb.read_macro_buffer()?,
            rgb: kb.rgb_basic()?,
        })
    }

    /// Write everything back and persist the lighting. Returns an error on the first failed write.
    pub fn restore(&self, kb: &Keyboard) -> Result<()> {
        for (i, layer) in self.layers.iter().enumerate() {
            kb.write_layer(i as u8, layer)?;
        }
        for (i, [ccw, cw]) in self.encoders.iter().enumerate() {
            kb.set_encoder(i as u8, 0, false, *ccw)?;
            kb.set_encoder(i as u8, 0, true, *cw)?;
        }
        kb.write_macro_buffer(&self.macro_buffer)?;
        kb.set_rgb_basic(&self.rgb, true)
    }
}
