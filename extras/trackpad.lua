-- Optional trackpad settings for ~/.config/hypr/input.lua (Omarchy 4.x, Lua config).
-- Merge into your existing hl.config({ input = { ... } }) block, then: hyprctl reload
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,        -- macOS-style (reversed) scrolling; Omarchy default is false
      clickfinger_behavior = false, -- right-click = press the lower-right corner (default: two-finger click)
    },
  },
})
