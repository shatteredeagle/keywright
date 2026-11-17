use keywright_core::{enumerate, macros, Keyboard};
fn main() {
    let d = enumerate().unwrap().into_iter().find(|d| d.product_id == 0x0860 || d.product_id == 0xd030).unwrap();
    let kb = Keyboard::open(&d).unwrap();
    let count = kb.macro_count().unwrap() as usize;
    let buf = kb.read_macro_buffer().unwrap();
    let list = macros::decode(&buf, count);
    println!("{count} macros, buffer {} bytes", buf.len());
    for (i, m) in list.iter().enumerate().filter(|(_, m)| !m.is_empty()) { println!("macro {i}: {m:?}"); }
    println!("re-encodes identically: {}", macros::encode(&list, buf.len()).unwrap() == buf);
}
