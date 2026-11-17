import QtQuick

// Animated stand-in for the keyboard's backlight effects. It follows the settings you give it, so
// moving a slider changes what plays. Reactive effects respond to clicks on the keys.
Item {
    id: root
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25
    property int effect: 1
    property int hue: 0
    property int sat: 255
    property int bright: 255
    property int speed: 127
    // Per-key RGB (effect 23): [{h,s,v}] by LED index, and the per-key mode.
    property var perKey: null
    property int perKeyMode: 0
    // Mixed RGB (effect 24): {regions:[...], effects:[[{effect,hue,sat,speed}]]}
    property var mixed: null
    property bool running: visible

    property var frame: []
    property real clock: 0
    property var presses: []          // {i, cx, cy, t0, h}
    property var heat: []
    property var bean: []             // jellybean hues
    property var pixels: []           // pixel rain {on, h}
    property var drops: []            // digital rain heads per column
    property real lastTick: 0
    property real lastAuto: 0
    property real lastRoll: 0

    readonly property int n: keys.length
    readonly property var pts: keys.map(k => ({
        cx: (k.x + k.w / 2) / kbWidth * 224,
        cy: (k.y + k.h / 2) / kbHeight * 64,
        col: Math.floor(k.x + k.w / 2)
    }))

    function wrap(h) { return ((h % 256) + 256) % 256; }
    function hsv(h, s, v) { return Qt.hsva(wrap(h) / 255, Math.max(0, Math.min(255, s)) / 255, Math.max(0, Math.min(255, v)) / 255, 1); }
    function sin8(x) { return (Math.sin(wrap(x) / 256 * 2 * Math.PI) * 0.5 + 0.5) * 255; }
    function ang8(dy, dx) { return (Math.atan2(dy, dx) / (2 * Math.PI) + 0.5) * 256; }

    function press(i) {
        if (i < 0 || i >= n) return;
        const p = pts[i];
        presses = presses.concat([{ i: i, cx: p.cx, cy: p.cy, t0: clock, h: Math.random() * 256 }]).slice(-12);
        if (heat.length === n) { heat[i] = Math.min(255, heat[i] + 120); }
    }
    function reset() {
        presses = [];
        heat = Array(n).fill(0);
        bean = Array.from({ length: n }, () => Math.random() * 256);
        pixels = Array.from({ length: n }, () => ({ on: false, h: 0 }));
        drops = Array.from({ length: 24 }, () => Math.random() * 14 - 4);
    }
    onEffectChanged: reset()
    onNChanged: reset()

    // Colour of key i for a given effect and settings, at time `ms` (animation clock).
    function colorFor(i, e, h, s, v, spd, ms) {
        const p = pts[i];
        const t4 = ms * (spd / 4) / 256;       // QMK's time base for most effects
        const t8 = ms * (spd / 8) / 256;       // and for breathing
        const dx = p.cx - 112, dy = p.cy - 32;
        const dist = Math.sqrt(dx * dx + dy * dy);
        switch (e) {
        case 0: return null;
        case 1: return hsv(h, s, v);
        case 2: return hsv(h, s, v * Math.abs(sin8(t8) - 128) * 2 / 255);
        case 3: {
            const band = sin8(dist * 1.6 - t4 * 2 + ang8(dy, dx) * 0.5);
            return hsv(h, s, v * band / 255);
        }
        case 4: return hsv(t4, s, v);
        case 5: return hsv(p.cx - t4, s, v);
        case 6: return hsv(p.cy * 3 - t4, s, v);
        case 7: return hsv(Math.abs(p.cy - 32) + (p.cx - t4), s, v);
        case 8: return hsv(1.5 * dist + t4, s, v);
        case 9: return hsv(1.5 * Math.min(Math.hypot(p.cx - 56, dy), Math.hypot(p.cx - 168, dy)) + t4, s, v);
        case 10: return hsv(ang8(dy, dx) + t4, s, v);
        case 11: return hsv(dist - t4 - ang8(dy, dx), s, v);
        case 12: {
            const a = t4 / 256 * 2 * Math.PI;
            return hsv(h + (dy * Math.cos(a) * 127 + dx * Math.sin(a) * 127) / 128, s, v);
        }
        case 13: {
            const a = t4 / 256 * 2 * Math.PI;
            return hsv(2 * (dy * Math.cos(a) * 127 + dx * Math.sin(a) * 127) / 128, s, v);
        }
        case 14: return hsv(bean[i], s, v);
        case 15: return pixels[i].on ? hsv(pixels[i].h, s, v) : null;
        case 16: { const hv = heat[i]; return hv > 4 ? hsv(h - (255 - hv) * 0.35, s, Math.min(255, v * hv / 255 + 30)) : null; }
        case 17: {
            const col = p.col % drops.length, head = drops[col], row = Math.floor(p.cy / 64 * 6);
            const d = head - row;
            return d >= 0 && d < 5 ? hsv(h, d === 0 ? Math.max(0, s - 160) : s, v * (1 - d / 5)) : null;
        }
        case 18: case 19: case 20: case 21: case 22: {
            let best = 0, bh = h;
            for (const pr of presses) {
                const age = ms - pr.t0;
                if (age < 0 || age > 1600) continue;
                let f = 0;
                const d = Math.hypot(p.cx - pr.cx, p.cy - pr.cy);
                if (e === 18) f = pr.i === i ? 1 - age / 1200 : 0;
                else if (e === 19) f = Math.abs(p.cy - pr.cy) < 12 ? Math.max(0, 1 - Math.abs(p.cx - pr.cx) / 60) * (1 - age / 1300) : 0;
                else if (e === 20) f = Math.max(0, 1 - Math.abs(Math.abs(p.cx - pr.cx) + Math.abs(p.cy - pr.cy) * 2 - age * 0.12) / 28) * (1 - age / 1600);
                else f = Math.max(0, 1 - Math.abs(d - age * 0.1) / 30) * (1 - age / 1600);
                if (f > best) { best = f; bh = e >= 21 ? pr.h : h; }
            }
            if (e === 22) return best > 0 ? hsv(bh, s, v * Math.max(best, 0.35)) : hsv(h + 128, s, v * 0.35);
            return best > 0.02 ? hsv(bh, s, v * best) : null;
        }
        default: return null;
        }
    }

    function tick() {
        const now = Date.now();
        const dt = lastTick ? Math.min(100, now - lastTick) : 33;
        lastTick = now;
        clock += dt;
        if (n === 0) return;
        const v = bright;

        // Keep the stateful effects moving.
        if (clock - lastAuto > 520 && (effect === 16 || (effect >= 18 && effect <= 22) || (mixed && effect === 24))) {
            lastAuto = clock; press(Math.floor(Math.random() * n));
        }
        if (effect === 14 && clock - lastRoll > 900 / (0.6 + speed / 128)) { lastRoll = clock; for (let k = 0; k < 4; k++) bean[Math.floor(Math.random() * n)] = Math.random() * 256; }
        if (effect === 15 && clock - lastRoll > 260 / (0.6 + speed / 128)) {
            lastRoll = clock;
            const k = Math.floor(Math.random() * n);
            pixels[k] = pixels[k].on ? { on: false, h: 0 } : { on: true, h: Math.random() * 256 };
        }
        if (effect === 16) for (let k = 0; k < n; k++) heat[k] = Math.max(0, heat[k] - dt * 0.07);
        if (effect === 17) for (let c = 0; c < drops.length; c++) { drops[c] += dt * speed / 128 * 0.006; if (drops[c] > 11) drops[c] = -Math.random() * 5; }

        const out = new Array(n);
        for (let i = 0; i < n; i++) {
            let c = null;
            if (effect === 23 && perKey) {
                const led = keys[i].led;
                const pk = led !== null && led !== undefined ? perKey[led] : null;
                c = pk ? hsv(pk.h, pk.s, pk.v * (perKeyMode === 1 ? Math.abs(sin8(clock * (speed / 8) / 256) - 128) * 2 / 255 : 1) * v / 255) : null;
            } else if (effect === 24 && mixed) {
                const led = keys[i].led;
                const r = led !== null && led !== undefined ? mixed.regions[led] : 0;
                const st = mixed.effects[r] ? mixed.effects[r][0] : null;
                c = st ? colorFor(i, st.effect, st.hue, st.sat, v, st.speed, clock) : null;
            } else {
                c = colorFor(i, effect, hue, sat, v, speed, clock);
            }
            out[i] = c ? c : Qt.rgba(0.06, 0.07, 0.1, 1);
        }
        frame = out;
    }
    Timer { interval: 33; repeat: true; running: root.running && root.n > 0; onTriggered: root.tick() }
    Component.onCompleted: reset()

    KeyboardView {
        anchors.fill: parent
        keys: root.keys
        kbWidth: root.kbWidth
        kbHeight: root.kbHeight
        fills: root.frame
        showLabels: false
        onKeyClicked: i => root.press(i)
    }
}
