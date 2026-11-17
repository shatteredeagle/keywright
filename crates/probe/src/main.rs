use keywright_core::{enumerate, keycode, layout::Layout, Keyboard};

fn main() {
    let layout = Layout::q6_max_ansi();
    for d in enumerate().expect("enumerate") {
        println!("== {:04x} {} ({})", d.product_id, d.product, d.path);
        let kb = match Keyboard::open(&d) {
            Ok(k) => k,
            Err(e) => { println!("  open failed: {e}"); continue; }
        };
        match kb.protocol_version() {
            Ok(v) => println!("  via protocol {v}"),
            Err(e) => { println!("  no VIA reply: {e}"); continue; }
        }
        match kb.rgb_basic() { Ok(r) => println!("  rgb {r:?}"), Err(e) => println!("  rgb basic: {e}") }
        match kb.keychron_rgb_info() {
            Ok((v, n)) => println!("  keychron rgb protocol {v}, {n} leds"),
            Err(e) => println!("  keychron rgb: {e}"),
        }
        let Ok(layers) = kb.read_keymap(&layout) else { println!("  keymap read failed"); continue };
        println!("  layers {}", layers.len());
        for (i, layer) in layers.iter().enumerate().take(1) {
            println!("  layer {i}:");
            let mut row = 0.0f32;
            let mut line = String::new();
            for k in &layout.keys {
                if k.y != row { println!("    {line}"); line.clear(); row = k.y; }
                let code = layer[k.row as usize * layout.cols as usize + k.col as usize];
                line += &format!("{:<7}", keycode::name(code));
            }
            println!("    {line}");
        }
    }
}
