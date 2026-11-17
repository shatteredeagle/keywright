use keywright_core::{enumerate, Keyboard};

fn main() {
    let devices = enumerate().expect("enumerate");
    if devices.is_empty() {
        eprintln!("no Keychron raw-HID endpoints found");
    }
    for d in devices {
        println!("== {:04x} {} ({})", d.product_id, d.product, d.path);
        let kb = match Keyboard::open(&d) {
            Ok(k) => k,
            Err(e) => { println!("  open failed: {e}"); continue; }
        };
        match kb.protocol_version() {
            Ok(v) => println!("  via protocol {v}"),
            Err(e) => { println!("  no VIA reply: {e}"); continue; }
        }
        if let Ok(u) = kb.uptime_ms() { println!("  uptime {}s", u / 1000); }
        let layers = kb.layer_count().unwrap_or(0);
        println!("  layers {layers}");
        match kb.read_layer(0, 6, 21) {
            Ok(codes) => for row in codes.chunks(21) {
                println!("  {}", row.iter().map(|c| format!("{c:04x}")).collect::<Vec<_>>().join(" "));
            },
            Err(e) => println!("  keymap read failed: {e}"),
        }
    }
}
