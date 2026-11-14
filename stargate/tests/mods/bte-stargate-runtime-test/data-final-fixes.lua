-- Shortens the build so the test does not wait the real minute, and gives the construction site one
-- unfiltered spare slot after the bill's, to stand in for a stray stack (say, from another mod changing
-- stack sizes) that the construction must spill rather than lose. Everything else is untouched.
data.raw["mod-data"]["bte-stargate-construction"].data.build_ticks = 240
local site = data.raw.container["bte-stargate-construction-site"]
site.inventory_size = site.inventory_size + 1
-- A small capacitor, so a gate charges in a fraction of a second rather than ten.
-- Its 20 % reserve then carries the upkeep for two seconds, as the real gate's does, so the upkeep
-- shrinks with it.
data.raw["mod-data"]["bte-stargate-power"].data.capacity = 0.3e9
data.raw["mod-data"]["bte-stargate-power"].data.upkeep = 30e6
-- A power source that feeds tertiary consumers such as the gate's capacitor (the vanilla interface
-- is tertiary itself, and tertiary does not feed tertiary).
local source = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
source.name = "bte-stargate-test-power"
source.energy_source.usage_priority = "primary-output"
data:extend({source})
-- A machine-like load, to check that a charging gate leaves the factory its power.
local load = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
load.name = "bte-stargate-test-load"
load.energy_source.usage_priority = "secondary-input"
data:extend({load})
