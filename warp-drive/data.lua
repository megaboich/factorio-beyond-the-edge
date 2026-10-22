require("prototypes.items")
require("prototypes.entities")
require("prototypes.recipes")
require("prototypes.technologies")

local sounds = {
  {
    type = "sound",
    name = "warp-drive-command",
    filename = "__warp-drive__/resources/audio/warp-command.ogg",
    volume = 1
  },
  {
    type = "sound",
    name = "warp-drive-activation",
    filename = "__warp-drive__/resources/audio/warp-activation.ogg",
    volume = 1
  },
  {
    type = "sound",
    name = "warp-drive-deactivation",
    filename = "__warp-drive__/resources/audio/warp-deactivation.ogg",
    volume = 1
  },
  {
    type = "sound",
    name = "warp-drive-background-01",
    filename = "__warp-drive__/resources/audio/warp-background-01.ogg",
    category = "ambient",
    volume = 1
  },
  {
    type = "sound",
    name = "warp-drive-background-02",
    filename = "__warp-drive__/resources/audio/warp-background-02.ogg",
    category = "ambient",
    volume = 1
  }
}

for index = 1, 20 do
  sounds[#sounds + 1] = {
    type = "sound",
    name = string.format("warp-drive-buzz-%02d", index),
    filename = string.format("__warp-drive__/resources/audio/warp-buzz-%02d.ogg", index),
    category = "ambient",
    volume = 1
  }
  sounds[#sounds + 1] = {
    type = "sound",
    name = string.format("warp-drive-failed-activation-%02d", index),
    filename = string.format(
      "__warp-drive__/resources/audio/warp-failed-activation-%02d.ogg", index),
    category = "ambient",
    volume = 1
  }
end

data:extend(sounds)

data:extend({
  {
    type = "custom-input",
    name = "warp-drive-open",
    key_sequence = "",
    linked_game_control = "open-gui",
    consuming = "none"
  }
})
