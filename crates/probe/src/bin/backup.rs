//! `backup save <file>` writes the keyboard's configuration to JSON; `backup verify <file>` compares.
//! `backup restore <file>` writes a saved configuration back.
use keywright_core::{backup::Backup, enumerate, layout::Layout, Keyboard};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (cmd, path) = match (args.get(1), args.get(2)) {
        (Some(c), Some(p)) => (c.as_str(), p.as_str()),
        _ => return eprintln!("usage: backup <save|verify|restore> <file.json>"),
    };
    let layout = Layout::q6_max_ansi();
    let d = enumerate().unwrap().into_iter().find(|d| d.product_id == 0x0860 || d.product_id == 0xd030).expect("Q6 Max on the cable or 2.4G receiver");
    let kb = Keyboard::open(&d).unwrap();
    match cmd {
        "save" => {
            let b = Backup::read(&kb, &layout).unwrap();
            std::fs::write(path, serde_json::to_string_pretty(&b).unwrap()).unwrap();
            println!("saved {} layers, {} macro bytes, firmware {:?} -> {path}", b.layers.len(), b.macro_buffer.len(), b.firmware);
        }
        "verify" => {
            let saved: Backup = serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap();
            let now = Backup::read(&kb, &layout).unwrap();
            let same = saved.layers == now.layers && saved.encoders == now.encoders && saved.macro_buffer == now.macro_buffer;
            println!("keymap/knob/macros {}; rgb saved {:?} now {:?}", if same { "MATCH" } else { "DIFFER" }, saved.rgb, now.rgb);
        }
        "restore" => {
            let saved: Backup = serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap();
            saved.restore(&kb).unwrap();
            println!("restored from {path}");
        }
        _ => eprintln!("unknown command"),
    }
}
