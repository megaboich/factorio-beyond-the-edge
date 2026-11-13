local Construction = require("scripts.construction")

local UPDATE_TICKS = 30
local SITE = {{filter = "name", name = "bte-stargate-construction-site"}}

script.on_init(Construction.rebuild)
script.on_configuration_changed(Construction.rebuild)

for _, event in pairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}) do
  script.on_event(event, function(event_data)
    Construction.register(event_data.entity)
  end, SITE)
end

script.on_event(defines.events.on_entity_cloned, function(event_data)
  Construction.register(event_data.destination)
end, SITE)

script.on_nth_tick(UPDATE_TICKS, Construction.update)
