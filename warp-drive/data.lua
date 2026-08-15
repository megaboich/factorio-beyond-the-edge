require("prototypes.items")
require("prototypes.entities")
require("prototypes.recipes")
require("prototypes.technologies")

data:extend({
  {
    type = "sound",
    name = "warp-drive-enter",
    filename = "__space-age__/sound/entity/platform-thruster/thruster-engine-activate-1.ogg",
    volume = 1.2,
    speed = 1.25,
    audible_distance_modifier = 3
  },
  {
    type = "sound",
    name = "warp-drive-exit",
    filename = "__space-age__/sound/entity/platform-thruster/thruster-engine-deactivate-1.ogg",
    volume = 1.2,
    speed = 0.7,
    audible_distance_modifier = 3
  },
  {
    type = "custom-input",
    name = "warp-drive-open",
    key_sequence = "",
    linked_game_control = "open-gui",
    consuming = "none"
  }
})
