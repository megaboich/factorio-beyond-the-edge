require("prototypes.items")
require("prototypes.entities")
require("prototypes.recipes")
require("prototypes.technologies")

-- Every drive sound uses the game-effects mixer. The "ambient" category is the music slider,
-- which defaults to a third of game effects and made charging nearly inaudible.
local function sound(name, file)
  return {
    type = "sound",
    name = name,
    filename = "__bte-warp-drive__/resources/audio/" .. file .. ".ogg",
    category = "game-effect",
    volume = 1
  }
end

local sounds = {
  sound("bte-warp-drive-activation", "warp-activation"),
  sound("bte-warp-drive-deactivation", "warp-deactivation"),
  sound("bte-warp-drive-background-01", "warp-background-01"),
  sound("bte-warp-drive-background-02", "warp-background-02")
}

for index = 1, 20 do
  sounds[#sounds + 1] = sound(
    string.format("bte-warp-drive-buzz-%02d", index), string.format("warp-buzz-%02d", index))
  sounds[#sounds + 1] = sound(
    string.format("bte-warp-drive-failed-activation-%02d", index),
    string.format("warp-failed-activation-%02d", index))
end

data:extend(sounds)

data:extend({
  {
    type = "custom-input",
    name = "bte-warp-drive-open",
    key_sequence = "",
    linked_game_control = "open-gui",
    consuming = "none"
  }
})
