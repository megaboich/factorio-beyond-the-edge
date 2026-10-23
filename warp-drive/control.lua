local Drive = require("scripts.drive")
local Research = require("scripts.research")
local Gui = require("scripts.gui")
local Warp = require("scripts.warp")

local DRIVE_NAME = "bte-warp-drive-controller"
local UPDATE_TICKS = 10
local RESEARCH_UPDATE_TICKS = 60

Gui.configure({
  snapshot = Warp.snapshot,
  engagement_changed = Warp.engagement_changed
})

if script.active_mods["bte-warp-drive-runtime-test"] then
  remote.add_interface("bte-warp-drive-runtime-test", {
    reserve_energy = function(platform_index, value)
      local record = Drive.get(platform_index)
      if not record then
        return nil
      end
      if value ~= nil then
        record.reserve_energy = value
      end
      return record.reserve_energy or 0
    end,
    set_engagement = function(platform_index, enabled, circuit_enabled)
      local record = Drive.get(platform_index)
      if not record then
        return nil
      end
      record.enabled = enabled
      record.circuit_enabled = circuit_enabled
      Drive.normalize_engagement(record)
      Warp.engagement_changed(record, false)
      return true
    end,
    sound_state = function(platform_index)
      local record = Drive.get(platform_index)
      if not record then
        return nil
      end
      return {
        state = record.state,
        cooldown_until = record.cooldown_until,
        last_exit_reason = record.last_exit_reason,
        charge_next_tick = record.charge_sound_next_tick,
        charge_step = record.charge_sound_step,
        warp_next_tick = record.warp_sound_next_tick,
        background_index = record.warp_background_sound_index,
        shockwaves_sent = record.shockwaves_sent,
        anomalies = record.anomalies and #record.anomalies or 0
      }
    end
  })
end

script.on_init(function()
  Drive.init_storage()
  Research.reset_caches()
  Drive.rebuild()
end)

script.on_configuration_changed(function()
  Drive.init_storage()
  Research.reset_caches()
  Drive.rebuild()
end)

for _, event in pairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}) do
  script.on_event(event, function(event_data)
    Drive.register_from_event(event_data)
  end, {{filter = "name", name = DRIVE_NAME}})
end

for _, event in pairs({
  defines.events.on_pre_player_mined_item,
  defines.events.on_robot_pre_mined,
  defines.events.on_space_platform_pre_mined,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy
}) do
  script.on_event(event, function(event_data)
    Drive.unregister_entity(event_data.entity)
  end, {{filter = "name", name = DRIVE_NAME}})
end

for _, event in pairs({
  defines.events.on_player_built_tile,
  defines.events.on_player_mined_tile,
  defines.events.on_robot_built_tile,
  defines.events.on_robot_mined_tile,
  defines.events.on_space_platform_built_tile,
  defines.events.on_space_platform_mined_tile,
  defines.events.script_raised_set_tiles
}) do
  script.on_event(event, Warp.platform_tiles_changed)
end

script.on_nth_tick(UPDATE_TICKS, function()
  for platform_index, record in pairs(Drive.records()) do
    if not Warp.update(record) then
      Drive.remove(platform_index, record)
    else
      local platform = record.entity.surface.platform
      if platform then
        Drive.update_output_signals(record, platform, Research.tachyon_density(platform))
      end
    end
  end
end)

script.on_nth_tick(RESEARCH_UPDATE_TICKS, function()
  Research.update()
  Gui.refresh_open_windows()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  Gui.refresh_for_setting(event.setting)
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local player = game.get_player(event.player_index)
  local blueprint = event.record or event.stack or (player and player.blueprint_to_setup)
  Drive.tag_blueprint(blueprint, event.mapping)
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  if not event.source or not event.source.valid or event.source.name ~= DRIVE_NAME
      or not event.destination or not event.destination.valid or event.destination.name ~= DRIVE_NAME then
    return
  end
  local source_platform = event.source.surface.platform
  local destination_platform = event.destination.surface.platform
  local source_record = source_platform and storage.drives[source_platform.index]
  local destination_record = destination_platform and storage.drives[destination_platform.index]
  if source_record and destination_record then
    Drive.apply_settings(destination_record, Drive.serialize_settings(source_record))
  end
end)
