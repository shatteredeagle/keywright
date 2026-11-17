//! QMK keycode to display name, covering the basic range plus Keychron/QMK specials.

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
        assert_eq!(name(0x7E00), "7E00");
    }
}
