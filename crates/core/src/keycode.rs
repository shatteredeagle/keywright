//! QMK keycode to display name, covering the basic range plus Keychron/QMK specials.

/// Keychron custom keycodes (`customKeycodes` in the VIA definition), in order from 0x7E00.
pub const KEYCHRON_SHORT: [&str; 16] = [
    "LOpt", "ROpt", "LCmd", "RCmd", "MCtl", "LPad", "Task", "File",
    "SShot", "Cortana", "Siri", "BT1", "BT2", "BT3", "2.4G", "Batt",
];

pub fn name(code: u16) -> String {
    match code {
        0x0000 => String::new(),
        0x0001 => "▽".into(),
        0x0004..=0x001D => char::from(b'A' + (code - 0x04) as u8).to_string(),
        0x001E..=0x0026 => char::from(b'1' + (code - 0x1E) as u8).to_string(),
        0x0027 => "0".into(),
        0x0028 => "Enter".into(),
        0x0029 => "Esc".into(),
        0x002A => "Bksp".into(),
        0x002B => "Tab".into(),
        0x002C => "Space".into(),
        0x002D => "-".into(),
        0x002E => "=".into(),
        0x002F => "[".into(),
        0x0030 => "]".into(),
        0x0031 => "\\".into(),
        0x0033 => ";".into(),
        0x0034 => "'".into(),
        0x0035 => "`".into(),
        0x0036 => ",".into(),
        0x0037 => ".".into(),
        0x0038 => "/".into(),
        0x0039 => "Caps".into(),
        0x003A..=0x0045 => format!("F{}", code - 0x3A + 1),
        0x0046 => "PrtSc".into(),
        0x0047 => "ScrLk".into(),
        0x0048 => "Pause".into(),
        0x0049 => "Ins".into(),
        0x004A => "Home".into(),
        0x004B => "PgUp".into(),
        0x004C => "Del".into(),
        0x004D => "End".into(),
        0x004E => "PgDn".into(),
        0x004F => "→".into(),
        0x0050 => "←".into(),
        0x0051 => "↓".into(),
        0x0052 => "↑".into(),
        0x0053 => "NumLk".into(),
        0x0054 => "KP /".into(),
        0x0055 => "KP *".into(),
        0x0056 => "KP -".into(),
        0x0057 => "KP +".into(),
        0x0058 => "KP Ent".into(),
        0x0059..=0x0061 => format!("KP {}", code - 0x59 + 1),
        0x0062 => "KP 0".into(),
        0x0063 => "KP .".into(),
        0x0065 => "Menu".into(),
        0x00A8 => "Mute".into(),
        0x00A9 => "Vol+".into(),
        0x00AA => "Vol-".into(),
        0x00AB => "Next".into(),
        0x00AC => "Prev".into(),
        0x00AE => "Play".into(),
        0x00BD => "Bright-".into(),
        0x00BE => "Bright+".into(),
        0x00E0 => "LCtrl".into(),
        0x00E1 => "LShift".into(),
        0x00E2 => "LAlt".into(),
        0x00E3 => "LWin".into(),
        0x00E4 => "RCtrl".into(),
        0x00E5 => "RShift".into(),
        0x00E6 => "RAlt".into(),
        0x00E7 => "RWin".into(),
        0x0068..=0x0073 => format!("F{}", code - 0x68 + 13),
        0x7013 => "NKRO".into(),
        0x7700..=0x777F => format!("Macro {}", code - 0x7700),
        0x7820 => "RGB".into(),
        0x7821 => "Mode+".into(),
        0x7822 => "Mode-".into(),
        0x7823 => "Hue+".into(),
        0x7824 => "Hue-".into(),
        0x7825 => "Sat+".into(),
        0x7826 => "Sat-".into(),
        0x7827 => "Light+".into(),
        0x7828 => "Light-".into(),
        0x7829 => "Speed+".into(),
        0x782A => "Speed-".into(),
        0x5220..=0x523F => format!("Fn{}", code - 0x5220),
        0x7E00..=0x7E0F => KEYCHRON_SHORT[(code - 0x7E00) as usize].into(),
        _ => format!("{code:04X}"),
    }
}

#[cfg(test)]
mod tests {
    use super::name;

    #[test]
    fn basic_names() {
        assert_eq!(name(0x0004), "A");
        assert_eq!(name(0x001E), "1");
        assert_eq!(name(0x0027), "0");
        assert_eq!(name(0x003A), "F1");
        assert_eq!(name(0x0045), "F12");
        assert_eq!(name(0x0059), "KP 1");
        assert_eq!(name(0x7E00), "LOpt");
        assert_eq!(name(0x5221), "Fn1");
    }
}

/// Pickable keycodes grouped for the key picker: `(group, code, label)`.
pub fn catalog() -> Vec<(&'static str, u16, String)> {
    let group = |c: u16| match c {
        0x04..=0x1D => "Letters",
        0x1E..=0x27 => "Numbers",
        0x28..=0x38 | 0x65 => "Punctuation & editing",
        0x39 | 0xE0..=0xE7 => "Modifiers & locks",
        0x3A..=0x45 => "Function",
        0x46..=0x52 => "Navigation",
        0x53..=0x63 => "Keypad",
        _ => "Media",
    };
    (0x04u16..=0xE7)
        .filter(|c| !(0x66..=0xA7).contains(c) && !(0xB0..=0xBC).contains(c) && !(0xBF..=0xDF).contains(c))
        .map(|c| (group(c), c, name(c)))
        .filter(|(_, c, n)| *n != format!("{c:04X}") && !n.is_empty())
        .collect()
}
