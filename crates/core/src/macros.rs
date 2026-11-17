//! Macro buffer encoding used by QMK's dynamic keymap (`send_string` format).
//!
//! Plain bytes are typed as text. `0x01` starts an action: `01 01 kc` taps a key, `01 02 kc` holds
//! it down, `01 03 kc` releases it, `01 04 <digits> <separator>` waits that many milliseconds.
//! Macros are separated by a `0x00` byte, and the buffer's final byte must stay `0`.

use serde::{Deserialize, Serialize};

const PREFIX: u8 = 0x01;
const DELAY_SEPARATOR: u8 = b'|';

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum MacroAction {
    /// Typed text. May contain `\n` (Enter) and `\t` (Tab).
    Text { text: String },
    Tap { code: u8 },
    Down { code: u8 },
    Up { code: u8 },
    Delay { ms: u32 },
}

pub type Macro = Vec<MacroAction>;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum MacroError {
    #[error("macros need {needed} bytes but the keyboard has room for {room}")]
    TooLong { needed: usize, room: usize },
    #[error("text can only contain plain ASCII, Enter and Tab (found {0:?})")]
    BadText(char),
}

/// Split a keyboard macro buffer into `count` macros. Missing macros come back empty.
pub fn decode(buffer: &[u8], count: usize) -> Vec<Macro> {
    let mut out: Vec<Macro> = Vec::new();
    let mut current: Macro = Vec::new();
    let mut text = String::new();
    let flush = |current: &mut Macro, text: &mut String| {
        if !text.is_empty() {
            current.push(MacroAction::Text { text: std::mem::take(text) });
        }
    };
    let mut i = 0;
    while i < buffer.len() && out.len() < count {
        let b = buffer[i];
        i += 1;
        match b {
            0 => {
                flush(&mut current, &mut text);
                out.push(std::mem::take(&mut current));
            }
            PREFIX => {
                flush(&mut current, &mut text);
                let Some(&sub) = buffer.get(i) else { break };
                i += 1;
                match sub {
                    1..=3 => {
                        let Some(&code) = buffer.get(i) else { break };
                        i += 1;
                        current.push(match sub {
                            1 => MacroAction::Tap { code },
                            2 => MacroAction::Down { code },
                            _ => MacroAction::Up { code },
                        });
                    }
                    4 => {
                        let mut ms = 0u32;
                        while let Some(&d) = buffer.get(i).filter(|d| d.is_ascii_digit()) {
                            ms = ms.saturating_mul(10).saturating_add((d - b'0') as u32);
                            i += 1;
                        }
                        // The firmware consumes the byte after the digits; a NUL there ends the macro.
                        let end = buffer.get(i).copied().unwrap_or(0);
                        i += 1;
                        current.push(MacroAction::Delay { ms });
                        if end == 0 {
                            out.push(std::mem::take(&mut current));
                        }
                    }
                    _ => {}
                }
            }
            c => text.push(c as char),
        }
    }
    out.resize(count, Vec::new());
    out
}

/// Pack macros into a buffer of exactly `size` bytes.
pub fn encode(macros: &[Macro], size: usize) -> Result<Vec<u8>, MacroError> {
    let mut out = Vec::new();
    for m in macros {
        for action in m {
            match action {
                MacroAction::Text { text } => {
                    for ch in text.chars() {
                        match ch {
                            '\n' | '\t' | ' '..='~' => out.push(ch as u8),
                            other => return Err(MacroError::BadText(other)),
                        }
                    }
                }
                MacroAction::Tap { code } => out.extend([PREFIX, 1, *code]),
                MacroAction::Down { code } => out.extend([PREFIX, 2, *code]),
                MacroAction::Up { code } => out.extend([PREFIX, 3, *code]),
                MacroAction::Delay { ms } => {
                    out.extend([PREFIX, 4]);
                    out.extend(ms.to_string().bytes());
                    out.push(DELAY_SEPARATOR);
                }
            }
        }
        out.push(0);
    }
    // The last byte of the buffer must stay zero, or the firmware ignores every macro.
    if out.len() >= size {
        return Err(MacroError::TooLong { needed: out.len() + 1, room: size });
    }
    out.resize(size, 0);
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_the_hideout_macro() {
        let mut buf = b"\n/hideout\n\0".to_vec();
        buf.resize(64, 0);
        let m = decode(&buf, 16);
        assert_eq!(m[0], vec![MacroAction::Text { text: "\n/hideout\n".into() }]);
        assert!(m[1].is_empty() && m.len() == 16);
    }

    #[test]
    fn round_trips_every_action() {
        let macros = vec![
            vec![
                MacroAction::Tap { code: 0x28 },
                MacroAction::Text { text: "/dnd".into() },
                MacroAction::Delay { ms: 250 },
                MacroAction::Down { code: 0xE1 },
                MacroAction::Tap { code: 0x04 },
                MacroAction::Up { code: 0xE1 },
            ],
            vec![],
            vec![MacroAction::Text { text: "hi".into() }],
        ];
        let buf = encode(&macros, 128).unwrap();
        let mut back = decode(&buf, 3);
        assert_eq!(back.remove(0), macros[0]);
        assert_eq!(buf.len(), 128);
        assert_eq!(*buf.last().unwrap(), 0);
        assert_eq!(decode(&buf, 3), macros);
    }

    #[test]
    fn rejects_overflow_and_odd_text() {
        let big = vec![vec![MacroAction::Text { text: "x".repeat(20) }]];
        assert!(matches!(encode(&big, 16), Err(MacroError::TooLong { .. })));
        let odd = vec![vec![MacroAction::Text { text: "é".into() }]];
        assert_eq!(encode(&odd, 64), Err(MacroError::BadText('é')));
    }
}
