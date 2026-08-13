require("prototypes.items")
require("prototypes.entities")
require("prototypes.recipes")
require("prototypes.technologies")

data:extend({
  {
    type = "custom-input",
    name = "warp-drive-open",
    key_sequence = "",
    linked_game_control = "open-gui",
    consuming = "none"
  }
})
