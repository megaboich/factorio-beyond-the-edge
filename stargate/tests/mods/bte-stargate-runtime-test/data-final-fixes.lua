-- Shortens the build so the test does not wait the real minute, and gives the construction site one
-- unfiltered spare slot after the bill's, to stand in for a stray stack (say, from another mod changing
-- stack sizes) that the construction must spill rather than lose. Everything else is untouched.
data.raw["mod-data"]["bte-stargate-construction"].data.build_ticks = 240
local site = data.raw.container["bte-stargate-construction-site"]
site.inventory_size = site.inventory_size + 1
