-- Generates five candidate Keywright app icons (32x32 pixel art) with Aseprite.
-- Run: aseprite -b --script make_icons.lua

local function hex(h, a)
  h = h:gsub("#", "")
  return app.pixelColor.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), a or 255)
end

local function new_icon(name)
  local spr = Sprite(32, 32, ColorMode.RGB)
  spr.filename = name
  return spr, spr.cels[1].image
end

local function px(img, x, y, c)
  if x >= 0 and x < 32 and y >= 0 and y < 32 then img:drawPixel(x, y, c) end
end
local function rect(img, x, y, w, h, c)
  for j = y, y + h - 1 do for i = x, x + w - 1 do px(img, i, j, c) end end
end
local function rrect(img, x, y, w, h, r, c)
  for j = 0, h - 1 do
    for i = 0, w - 1 do
      local dx = math.max(r - i, i - (w - 1 - r), 0)
      local dy = math.max(r - j, j - (h - 1 - r), 0)
      if dx * dx + dy * dy <= r * r + r * 0.5 then px(img, x + i, y + j, c) end
    end
  end
end
local function disc(img, cx, cy, r, c)
  for j = -r, r do for i = -r, r do if i * i + j * j <= r * r + r * 0.5 then px(img, cx + i, cy + j, c) end end end
end
local function hsv(h, s, v)
  local c = Color{ hue = h % 360, saturation = s, value = v }
  return app.pixelColor.rgba(c.red, c.green, c.blue, 255)
end
local function background(img, top, bottom)
  local t, b = Color{ r = tonumber(top:sub(2, 3), 16), g = tonumber(top:sub(4, 5), 16), b = tonumber(top:sub(6, 7), 16) },
               Color{ r = tonumber(bottom:sub(2, 3), 16), g = tonumber(bottom:sub(4, 5), 16), b = tonumber(bottom:sub(6, 7), 16) }
  for y = 0, 31 do
    local k = y / 31
    local c = app.pixelColor.rgba(math.floor(t.red + (b.red - t.red) * k), math.floor(t.green + (b.green - t.green) * k), math.floor(t.blue + (b.blue - t.blue) * k), 255)
    for x = 0, 31 do
      local dx = math.max(6 - x, x - 25, 0)
      local dy = math.max(6 - y, y - 25, 0)
      if dx * dx + dy * dy <= 36 + 3 then px(img, x, y, c) end
    end
  end
end
local K = {
  "X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X",
}
local function glyph(img, x, y, c)
  for j, row in ipairs(K) do
    for i = 1, #row do if row:sub(i, i) == "X" then px(img, x + i - 1, y + j - 1, c) end end
  end
end
local function save(spr, name)
  spr:saveAs(app.fs.joinPath(app.fs.currentPath, name .. ".ase"))
end

-- 1. Keycap with underglow -----------------------------------------------------------------
do
  local spr, img = new_icon("keycap")
  background(img, "#262a3b", "#14161f")
  -- underglow
  for x = 5, 26 do px(img, x, 27, hsv(190 + (x - 5) * 6, 0.8, 0.95)) end
  for x = 7, 24 do px(img, x, 28, hsv(190 + (x - 7) * 6, 0.7, 0.55)) end
  rrect(img, 6, 17, 20, 10, 2, hex("#8f96aa"))   -- side
  rrect(img, 6, 17, 20, 7, 2, hex("#a9afc2"))
  rrect(img, 8, 5, 16, 16, 3, hex("#e9ebf2"))    -- top face
  rrect(img, 9, 6, 14, 3, 1, hex("#ffffff"))     -- highlight
  rrect(img, 10, 8, 12, 11, 2, hex("#dfe2ec"))
  glyph(img, 13, 10, hex("#2c3146"))
  save(spr, "icon1-keycap")
end

-- 2. RGB knob -------------------------------------------------------------------------------
do
  local spr, img = new_icon("knob")
  background(img, "#202436", "#10121a")
  for a = 0, 359 do
    local r = math.rad(a)
    for rad = 12, 14, 0.5 do
      px(img, math.floor(16 + rad * math.cos(r) + 0.5), math.floor(16 + rad * math.sin(r) + 0.5), hsv(a, 0.85, 1))
    end
  end
  disc(img, 16, 16, 10, hex("#3b4058"))
  disc(img, 16, 16, 9, hex("#565c78"))
  disc(img, 15, 15, 7, hex("#6a7190"))
  rect(img, 15, 8, 2, 6, hex("#ffffff"))         -- indicator
  px(img, 12, 12, hex("#8890b0")); px(img, 13, 11, hex("#8890b0"))
  save(spr, "icon2-knob")
end

-- 3. Three glowing keys ---------------------------------------------------------------------
do
  local spr, img = new_icon("keys")
  background(img, "#1c1f2c", "#0e1017")
  local keys = { { 3, "#ff4d6d", "#ff9fb2" }, { 12, "#37e08a", "#9ff5c9" }, { 21, "#4d9fff", "#a5cdff" } }
  for _, k in ipairs(keys) do
    local x = k[1]
    -- glow
    rrect(img, x - 1, 9, 10, 15, 3, hex(k[2], 70))
    rrect(img, x, 10, 8, 13, 2, hex("#2a2e40"))
    rrect(img, x, 10, 8, 10, 2, hex(k[2]))
    rect(img, x + 1, 11, 6, 2, hex(k[3]))
  end
  for x = 3, 28 do px(img, x, 25, hsv(340 - (x - 3) * 4, 0.8, 0.9)) end
  save(spr, "icon3-keys")
end

-- 4. Gear around a keycap -------------------------------------------------------------------
do
  local spr, img = new_icon("gear")
  background(img, "#27304a", "#141a2b")
  disc(img, 16, 16, 11, hex("#f0a63a"))
  for a = 0, 315, 45 do
    local r = math.rad(a)
    local cx, cy = math.floor(16 + 11 * math.cos(r) + 0.5), math.floor(16 + 11 * math.sin(r) + 0.5)
    disc(img, cx, cy, 2, hex("#f0a63a"))
  end
  disc(img, 16, 16, 8, hex("#c97d1c"))
  rrect(img, 10, 10, 12, 12, 2, hex("#e9ebf2"))
  rrect(img, 10, 10, 12, 4, 1, hex("#ffffff"))
  glyph(img, 14, 12, hex("#2c3146"))
  save(spr, "icon4-gear")
end

-- 5. Full keyboard silhouette ---------------------------------------------------------------
do
  local spr, img = new_icon("board")
  background(img, "#232739", "#10121a")
  rrect(img, 2, 8, 28, 17, 3, hex("#3a4060"))
  rrect(img, 3, 9, 26, 15, 2, hex("#1b1e2d"))
  for row = 0, 2 do
    for col = 0, 6 do
      local x, y = 5 + col * 3, 11 + row * 4
      local hue = 200 + col * 22 + row * 14
      rect(img, x, y, 2, 3, hsv(hue, 0.7, 1))
    end
  end
  rect(img, 8, 21, 9, 2, hex("#8a92b8"))         -- space bar
  disc(img, 25, 13, 3, hex("#5b6288"))           -- knob
  disc(img, 25, 13, 2, hex("#8a92b8"))
  px(img, 25, 11, hex("#ffffff"))
  save(spr, "icon5-board")
end
