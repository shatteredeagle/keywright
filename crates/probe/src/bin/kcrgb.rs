use keywright_core::{Keyboard, enumerate, kcrgb::RegionEffect, layout::Layout};

fn main() {
    let layout = Layout::q6_max_ansi();
    let d = enumerate()
        .unwrap()
        .into_iter()
        .find(|d| d.product_id == 0x0860 || d.product_id == 0xd030)
        .expect("keyboard");
    let kb = Keyboard::open(&d).unwrap();
    let n = kb.kc_rgb_led_count().unwrap();
    println!("leds {n}");
    println!("indicators {:?}", kb.kc_rgb_indicators().unwrap());
    println!("per-key type {}", kb.kc_rgb_per_key_type().unwrap());
    let info = kb.kc_rgb_mixed_info().unwrap();
    println!("mixed {:?}", info);
    let idx = kb.kc_rgb_led_indices(layout.rows, layout.cols).unwrap();
    let mapped = idx.iter().flatten().filter(|i| i.is_some()).count();
    println!(
        "keys with an LED: {mapped}; layout keys {}",
        layout.keys.len()
    );
    let missing: Vec<_> = layout
        .keys
        .iter()
        .filter(|k| idx[k.row as usize][k.col as usize].is_none())
        .map(|k| (k.row, k.col))
        .collect();
    println!("layout keys without LED: {missing:?}");
    let colors = kb.kc_rgb_per_key_colors(n).unwrap();
    println!("first colours {:?}", &colors[..3]);
    let regions = kb.kc_rgb_regions(n).unwrap();
    println!("regions {:?}", &regions[..12]);
    for r in 0..info.regions {
        println!(
            "region {r} effects {:?}",
            kb.kc_rgb_region_effects(r, info.effects_per_region)
                .unwrap()
        );
    }
    // Find the first effect id that mixed-effect lists reject (= MIXED_RGB), restoring afterwards.
    let saved = kb
        .kc_rgb_region_effects(0, info.effects_per_region)
        .unwrap();
    let mut probe = saved.clone();
    let mut first_rejected = None;
    for id in 20u8..60 {
        probe[0] = RegionEffect {
            effect: id,
            ..saved[0]
        };
        if kb.kc_rgb_set_region_effects(0, &probe[..1]).is_err() {
            first_rejected = Some(id);
            break;
        }
    }
    kb.kc_rgb_set_region_effects(0, &saved).unwrap();
    assert_eq!(
        kb.kc_rgb_region_effects(0, info.effects_per_region)
            .unwrap(),
        saved
    );
    println!("first effect id mixed lists reject (= MIXED_RGB): {first_rejected:?}  (restored)");
}
