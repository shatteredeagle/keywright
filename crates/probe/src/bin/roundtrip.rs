//! Write-then-restore check against real hardware. Leaves the keyboard as it found it.
use keywright_core::{enumerate, layout::Layout, Keyboard};

fn main() {
    let layout = Layout::q6_max_ansi();
    let d = enumerate().unwrap().into_iter().find(|d| d.product_id == 0x0860).expect("Q6 Max on cable");
    let kb = Keyboard::open(&d).unwrap();

    // RGB speed only (brightness is clamped by the firmware, so never rewrite it): RAM only, no save.
    let orig = kb.rgb_basic().unwrap();
    let speed = orig.speed.wrapping_sub(1);
    kb.custom_set(3, 3, &[speed]).unwrap();
    let got = kb.rgb_basic().unwrap();
    kb.custom_set(3, 3, &[orig.speed]).unwrap();
    assert_eq!(got.speed, speed, "rgb write did not read back");
    assert_eq!(kb.rgb_basic().unwrap(), orig, "rgb not restored");
    println!("rgb roundtrip ok (speed {} -> {} -> {})", orig.speed, got.speed, orig.speed);

    // Keycode: top layer, Esc position, change, read back, restore.
    let top = kb.layer_count().unwrap() - 1;
    let before = kb.read_layer(top, layout.rows as usize, layout.cols as usize).unwrap();
    let probe_code = if before[0] == 0x0004 { 0x0005 } else { 0x0004 };
    kb.set_keycode(top, 0, 0, probe_code).unwrap();
    let mid = kb.read_layer(top, layout.rows as usize, layout.cols as usize).unwrap();
    kb.set_keycode(top, 0, 0, before[0]).unwrap();
    let after = kb.read_layer(top, layout.rows as usize, layout.cols as usize).unwrap();
    assert_eq!(mid[0], probe_code, "keycode write did not read back");
    assert_eq!(after, before, "layer not restored");
    println!("keycode roundtrip ok on layer {top} ({:04x} -> {:04x} -> {:04x})", before[0], mid[0], after[0]);
}
