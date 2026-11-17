//! Parse the VIA keyboard definition (KLE-style layout) into key rectangles.

use serde::Deserialize;
use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct Key {
    pub row: u8,
    pub col: u8,
    /// Position and size in key units (1.0 = one standard key).
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
    /// Cap color from the definition, `#rrggbb`.
    pub color: String,
    /// Encoder index when this entry is a knob rotation decal (`e0`), not a switch.
    pub encoder: Option<u8>,
}

#[derive(Debug, Deserialize)]
struct Matrix {
    rows: u8,
    cols: u8,
}

#[derive(Debug, Deserialize)]
struct Definition {
    name: String,
    matrix: Matrix,
    layouts: Layouts,
    #[serde(default)]
    menus: Value,
}

#[derive(Debug, Deserialize)]
struct Layouts {
    keymap: Vec<Vec<Value>>,
}

#[derive(Debug, Clone)]
pub struct Layout {
    pub name: String,
    pub rows: u8,
    pub cols: u8,
    pub keys: Vec<Key>,
    /// Backlight effect names and ids from the definition's Lighting menu.
    pub rgb_effects: Vec<(String, u8)>,
}

fn find_effects(v: &Value) -> Option<Vec<(String, u8)>> {
    match v {
        Value::Object(o) => {
            let is_effect = o
                .get("content")
                .and_then(|c| c.get(0))
                .and_then(Value::as_str)
                == Some("id_qmk_rgb_matrix_effect");
            if is_effect {
                return o.get("options").and_then(Value::as_array).map(|opts| {
                    opts.iter()
                        .filter_map(|p| Some((p.get(0)?.as_str()?.to_string(), p.get(1)?.as_u64()? as u8)))
                        .collect()
                });
            }
            o.values().find_map(find_effects)
        }
        Value::Array(a) => a.iter().find_map(find_effects),
        _ => None,
    }
}

impl Layout {
    pub fn parse(json: &str) -> serde_json::Result<Self> {
        let def: Definition = serde_json::from_str(json)?;
        let mut keys = Vec::new();
        let (mut y, mut color) = (0.0f32, String::from("#cccccc"));
        for row in &def.layouts.keymap {
            let mut x = 0.0f32;
            let (mut w, mut h) = (1.0f32, 1.0f32);
            for item in row {
                match item {
                    Value::Object(o) => {
                        let num = |k: &str| o.get(k).and_then(Value::as_f64).map(|v| v as f32);
                        x += num("x").unwrap_or(0.0);
                        y += num("y").unwrap_or(0.0);
                        w = num("w").unwrap_or(w);
                        h = num("h").unwrap_or(h);
                        if let Some(c) = o.get("c").and_then(Value::as_str) {
                            color = c.to_string();
                        }
                    }
                    Value::String(s) => {
                        let mut lines = s.split('\n');
                        let mut pos = lines.next().unwrap_or("").split(',');
                        let (Some(r), Some(c)) = (pos.next(), pos.next()) else { continue };
                        let (Ok(row_i), Ok(col_i)) = (r.trim().parse(), c.trim().parse()) else { continue };
                        let encoder = lines
                            .last()
                            .and_then(|l| l.strip_prefix('e'))
                            .and_then(|n| n.parse().ok());
                        keys.push(Key { row: row_i, col: col_i, x, y, w, h, color: color.clone(), encoder });
                        x += w;
                        (w, h) = (1.0, 1.0);
                    }
                    _ => {}
                }
            }
            y += 1.0;
        }
        let rgb_effects = find_effects(&def.menus).unwrap_or_default();
        Ok(Layout { name: def.name, rows: def.matrix.rows, cols: def.matrix.cols, keys, rgb_effects })
    }

    /// The bundled Q6 Max ANSI (knob) definition from Keychron's firmware repo.
    pub fn q6_max_ansi() -> Self {
        Self::parse(include_str!("../data/q6_max_ansi_encoder.json")).expect("bundled layout is valid")
    }

    pub fn size(&self) -> (f32, f32) {
        let r = self.keys.iter().fold((0.0f32, 0.0f32), |a, k| (a.0.max(k.x + k.w), a.1.max(k.y + k.h)));
        r
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn q6_max_has_expected_keys() {
        let l = Layout::q6_max_ansi();
        assert_eq!((l.rows, l.cols), (6, 20));
        assert_eq!(l.keys.len(), 109);
        let (w, h) = l.size();
        assert!((w - 22.5).abs() < 0.01 && (h - 6.25).abs() < 0.01, "{w}x{h}");
        assert!(l.keys.iter().any(|k| k.encoder == Some(0)));
        assert_eq!(l.rgb_effects.len(), 23);
        assert_eq!(l.rgb_effects[0], ("None".to_string(), 0));
    }
}
