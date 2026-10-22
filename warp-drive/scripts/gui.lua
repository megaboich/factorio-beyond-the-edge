local Drive = require("__bte-warp-drive__/scripts/drive")
local Research = require("__bte-warp-drive__/scripts/research")

local Gui = {}

local DRIVE_NAME = "bte-warp-drive-controller"
local CIRCUIT_OUTPUT_NAME = "bte-warp-drive-circuit-output"
local IMPATIENT_SETTING = "bte-warp-drive-severely-impatient"
local GUI_NAME = "bte_warp_drive_window"
local GUI_TOGGLE = "bte_warp_drive_enabled"
local GUI_CIRCUIT_TOGGLE = "bte_warp_drive_circuit_enabled"
local GUI_CIRCUIT_FIRST_SIGNAL = "bte_warp_drive_circuit_first_signal"
local GUI_CIRCUIT_COMPARATOR = "bte_warp_drive_circuit_comparator"
local GUI_CIRCUIT_SECOND_SIGNAL = "bte_warp_drive_circuit_second_signal"
local GUI_CIRCUIT_CONSTANT = "bte_warp_drive_circuit_constant"
local GUI_OUTPUT_WARP_ENABLED = "bte_warp_drive_output_warp_enabled"
local GUI_OUTPUT_WARP_SIGNAL = "bte_warp_drive_output_warp_signal"
local GUI_OUTPUT_DISTANCE_ENABLED = "bte_warp_drive_output_distance_enabled"
local GUI_OUTPUT_DISTANCE_SIGNAL = "bte_warp_drive_output_distance_signal"
local GUI_OUTPUT_CHARGE_ENABLED = "bte_warp_drive_output_charge_enabled"
local GUI_OUTPUT_CHARGE_SIGNAL = "bte_warp_drive_output_charge_signal"
local GUI_OUTPUT_SPEED_ENABLED = "bte_warp_drive_output_speed_enabled"
local GUI_OUTPUT_SPEED_SIGNAL = "bte_warp_drive_output_speed_signal"
local GUI_OUTPUT_TACHYON_DENSITY_ENABLED = "bte_warp_drive_output_tachyon_density_enabled"
local GUI_OUTPUT_TACHYON_DENSITY_SIGNAL = "bte_warp_drive_output_tachyon_density_signal"
local GUI_CLOSE = "bte_warp_drive_close"
local CIRCUIT_PANEL_WIDTH = 272
local MAIN_PANEL_WIDTH = CIRCUIT_PANEL_WIDTH * 2
local PANEL_GAP = 4
local STATUS_LABEL_WIDTH = 160
local STATUS_VALUE_WIDTH = 320
local DETECTOR_MAX_POWER_WATTS = 1000000000
local TICKS_PER_SECOND = 60
local WARP_LEVEL_SIGNAL = {type = "virtual", name = "signal-W"}
local DISTANCE_SIGNAL = {type = "virtual", name = "signal-D"}
local CHARGE_SIGNAL = {type = "virtual", name = "signal-C"}
local SPEED_SIGNAL = {type = "virtual", name = "signal-S"}
local TACHYON_DENSITY_SIGNAL = {type = "virtual", name = "signal-T"}
local CIRCUIT_COMPARATORS = {">", "<", "=", "≥", "≤", "≠"}
local CIRCUIT_COMPARATOR_INDEX = {
  [">"] = 1,
  ["<"] = 2,
  ["="] = 3,
  ["≥"] = 4,
  [">="] = 4,
  ["≤"] = 5,
  ["<="] = 5,
  ["≠"] = 6,
  ["!="] = 6
}
local OUTPUT_TOGGLE_FIELDS = {
  [GUI_OUTPUT_WARP_ENABLED] = "output_warp_enabled",
  [GUI_OUTPUT_DISTANCE_ENABLED] = "output_distance_enabled",
  [GUI_OUTPUT_CHARGE_ENABLED] = "output_charge_enabled",
  [GUI_OUTPUT_SPEED_ENABLED] = "output_speed_enabled",
  [GUI_OUTPUT_TACHYON_DENSITY_ENABLED] = "output_tachyon_density_enabled"
}
local OUTPUT_SIGNAL_FIELDS = {
  [GUI_OUTPUT_WARP_SIGNAL] = {"output_warp_signal", WARP_LEVEL_SIGNAL},
  [GUI_OUTPUT_DISTANCE_SIGNAL] = {"output_distance_signal", DISTANCE_SIGNAL},
  [GUI_OUTPUT_CHARGE_SIGNAL] = {"output_charge_signal", CHARGE_SIGNAL},
  [GUI_OUTPUT_SPEED_SIGNAL] = {"output_speed_signal", SPEED_SIGNAL},
  [GUI_OUTPUT_TACHYON_DENSITY_SIGNAL] = {"output_tachyon_density_signal", TACHYON_DENSITY_SIGNAL}
}
local OUTPUT_SIGNAL_NAMES = {
  [GUI_OUTPUT_WARP_ENABLED] = GUI_OUTPUT_WARP_SIGNAL,
  [GUI_OUTPUT_DISTANCE_ENABLED] = GUI_OUTPUT_DISTANCE_SIGNAL,
  [GUI_OUTPUT_CHARGE_ENABLED] = GUI_OUTPUT_CHARGE_SIGNAL,
  [GUI_OUTPUT_SPEED_ENABLED] = GUI_OUTPUT_SPEED_SIGNAL,
  [GUI_OUTPUT_TACHYON_DENSITY_ENABLED] = GUI_OUTPUT_TACHYON_DENSITY_SIGNAL
}
local SIGNAL_RICH_TEXT_TAG = {
  item = "item",
  fluid = "fluid",
  virtual = "virtual-signal",
  entity = "entity",
  recipe = "recipe"
}

local snapshot_callback
local engagement_changed_callback

function Gui.configure(config)
  if snapshot_callback or engagement_changed_callback then
    error("Warp Drive GUI callbacks may only be configured once")
  end
  snapshot_callback = assert(config.snapshot)
  engagement_changed_callback = assert(config.engagement_changed)
end

local function bold_number(value)
  return "[font=default-bold]" .. tostring(value) .. "[/font]"
end

local function format_energy(joules)
  if joules >= 1000000000 then
    return bold_number(string.format("%.2f", joules / 1000000000)) .. " GJ"
  end
  if joules >= 1000000 then
    return bold_number(string.format("%.2f", joules / 1000000)) .. " MJ"
  end
  return bold_number(string.format("%.2f", joules / 1000)) .. " kJ"
end

local function format_power(watts)
  if watts >= 1000000000 then
    return bold_number(string.format("%.2f", watts / 1000000000)) .. " GW"
  end
  if watts >= 1000000 then
    return bold_number(string.format("%.2f", watts / 1000000)) .. " MW"
  end
  return bold_number(string.format("%.2f", watts / 1000)) .. " kW"
end

local function format_duration(seconds)
  if seconds < 60 then
    return {"bte-warp-drive.duration-seconds", math.ceil(seconds)}
  end
  if seconds < 3600 then
    return {"bte-warp-drive.duration-minutes-seconds", math.floor(seconds / 60), math.floor(seconds % 60)}
  end
  if seconds < 86400 then
    return {"bte-warp-drive.duration-hours-minutes", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)}
  end
  if seconds < 31536000 then
    return {"bte-warp-drive.duration-days-hours", math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600)}
  end
  return {"bte-warp-drive.duration-years-days", math.floor(seconds / 31536000), math.floor(seconds % 31536000 / 86400)}
end

local function format_km(value)
  local text = string.format("%.0f", value)
  while true do
    local grouped, replaced = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
    text = grouped
    if replaced == 0 then
      return text
    end
  end
end

local function location_label(location)
  return {"", string.format("[%s=%s] ", location.type, location.name), location.localised_name}
end

local function add_requirement(parent, name, caption)
  local row = parent.add({type = "flow", name = name .. "_row", direction = "horizontal"})
  row.style.horizontally_stretchable = true
  row.style.vertical_align = "center"
  local icon = row.add({
    type = "sprite",
    name = name .. "_icon",
    sprite = "utility/status_not_working"
  })
  icon.style.size = 18
  icon.style.stretch_image_to_widget_size = true
  local label = row.add({type = "label", name = name .. "_label", caption = caption})
  label.style.width = STATUS_LABEL_WIDTH - 26
  label.style.single_line = false
  local value = row.add({type = "label", name = name, caption = ""})
  value.style.width = STATUS_VALUE_WIDTH
  value.style.single_line = false
  return value
end

local function add_status_row(parent, name, label)
  local row = parent.add({type = "flow", name = name .. "_row", direction = "horizontal"})
  row.style.horizontally_stretchable = true
  local label_element = row.add({type = "label", name = name .. "_label", caption = label})
  label_element.style.width = STATUS_LABEL_WIDTH
  label_element.style.single_line = false
  local result = row.add({type = "label", name = name})
  result.style.width = STATUS_VALUE_WIDTH
  result.style.single_line = false
  return result
end

local function add_section_heading(parent, caption, name)
  local heading = parent.add({type = "label", name = name, caption = caption, style = "heading_2_label"})
  heading.style.top_margin = 8
  heading.style.bottom_margin = 4
  return heading
end

local function signal_rich_text(signal)
  local signal_type = signal.type or "item"
  local tag = SIGNAL_RICH_TEXT_TAG[signal_type]
  if not tag then
    return "[img=" .. signal_type .. "/" .. signal.name .. "]"
  end
  local quality = signal.quality and signal.quality ~= "normal"
    and ",quality=" .. signal.quality or ""
  return "[" .. tag .. "=" .. signal.name .. quality .. "]"
end

local function circuit_network_tooltip(network, color)
  local color_caption = {"bte-warp-drive.circuit-network-color-" .. color}
  if not network then
    return {"bte-warp-drive.circuit-network-tooltip-disconnected", color_caption}
  end
  local signals = network.signals or {}
  local heading = #signals > 0
    and {"bte-warp-drive.circuit-network-tooltip-heading-signals", color_caption,
      network.network_id, network.connected_circuit_count, #signals}
    or {"bte-warp-drive.circuit-network-tooltip-heading", color_caption,
      network.network_id, network.connected_circuit_count}
  local tooltip = {"", heading}
  if #signals > 0 then
    local signal_lines = ""
    for _, entry in ipairs(signals) do
      signal_lines = signal_lines .. "\n" .. signal_rich_text(entry.signal)
        .. "  " .. tostring(entry.count)
    end
    tooltip[#tooltip + 1] = signal_lines
  end
  return tooltip
end

local function player_circuit_network(record, wire_id)
  -- The hidden output combinator shares the controller's networks but is an implementation
  -- detail, so connectivity shown to players counts only their external circuit links.
  local connector = record.entity.get_wire_connector(wire_id, false)
  local has_external_connection = false
  local has_output_connection = false
  if connector then
    for _, connection in pairs(connector.connections) do
      local owner = connection.target.owner
      if owner and owner.valid and owner.name == CIRCUIT_OUTPUT_NAME then
        has_output_connection = true
      else
        has_external_connection = true
      end
    end
  end
  if not has_external_connection then
    return nil
  end
  local network = record.entity.get_circuit_network(wire_id)
  if network and has_output_connection then
    network = {
      network_id = network.network_id,
      connected_circuit_count = math.max(0, network.connected_circuit_count - 1),
      signals = network.signals
    }
  end
  if network and network.connected_circuit_count == 0 then
    return nil
  end
  return network
end

local function update_circuit_network_row(element, record, color, wire_id)
  local network = player_circuit_network(record, wire_id)
  local signal_count = network and network.signals and #network.signals or 0
  local color_caption = {"bte-warp-drive.circuit-network-color-" .. color}
  if not network then
    element.caption = {"bte-warp-drive.circuit-network-disconnected", color_caption}
  elseif signal_count > 0 then
    element.caption = {"bte-warp-drive.circuit-network-connected-signals", color_caption,
      network.network_id, network.connected_circuit_count, signal_count}
  else
    element.caption = {"bte-warp-drive.circuit-network-connected", color_caption,
      network.network_id, network.connected_circuit_count}
  end
  element.tooltip = circuit_network_tooltip(network, color)
end

local function add_circuit_network_row(parent, name, color)
  local label = parent.add({
    type = "label",
    name = name,
    caption = {"bte-warp-drive.circuit-network-disconnected",
      {"bte-warp-drive.circuit-network-color-" .. color}}
  })
  label.style.single_line = false
  label.style.width = CIRCUIT_PANEL_WIDTH - 24
end

local function add_labeled_checkbox(parent, name, caption, tooltip, state)
  local checkbox = parent.add({
    type = "checkbox",
    name = name,
    caption = caption,
    state = state,
    tooltip = tooltip
  })
  checkbox.style.width = CIRCUIT_PANEL_WIDTH - 24
end

local function add_circuit_output(parent, enabled_name, signal_name, caption, tooltip,
    enabled, signal)
  local row = parent.add({type = "flow", name = enabled_name .. "_row", direction = "horizontal"})
  row.style.horizontally_stretchable = true
  row.style.vertical_align = "center"
  local checkbox = row.add({
    type = "checkbox",
    name = enabled_name,
    caption = caption,
    state = enabled,
    tooltip = tooltip
  })
  checkbox.style.width = CIRCUIT_PANEL_WIDTH - 68
  row.add({
    type = "choose-elem-button",
    name = signal_name,
    elem_type = "signal",
    signal = signal
  })
end

local function update_gui_height(player)
  local frame = player.gui.screen[GUI_NAME]
  local body = frame and frame.bte_warp_drive_body
  local scroll = body and body.bte_warp_drive_content_scroll
  if scroll then
    scroll.style.maximal_height = math.max(300,
      player.display_resolution.height / player.display_scale - 100)
  end
end

local function status(section, name)
  local row = section[name .. "_row"]
  return row and row[name]
end

-- GUI trees survive save/load and mod updates. Reject stale or incomplete layouts so refresh
-- can redraw them instead of indexing elements that the current code did not create.
local function view_from_frame(frame)
  if not frame or frame.tags.layout_version ~= 8 then
    return nil
  end
  local body = frame and frame.bte_warp_drive_body
  local scroll = body and body.bte_warp_drive_content_scroll
  local content = scroll and scroll.bte_warp_drive_content
  local detector = content and content.bte_warp_drive_detector_section
  local research = content and content.bte_warp_drive_research_section
  local warp = content and content.bte_warp_drive_warp_section
  local circuit = body and body.bte_warp_drive_circuit_panel
  local networks = circuit and circuit.bte_warp_drive_circuit_networks
  local editor = circuit and circuit.bte_warp_drive_circuit_editor
  local circuit_state = circuit and circuit.bte_warp_drive_circuit_state
  if not content or not detector or not research or not warp or not circuit or not networks
      or not editor or not circuit_state
      or not content.bte_warp_drive_mode_help
      or not content.bte_warp_drive_alert
      or not content.bte_warp_drive_alert.bte_warp_drive_alert_details
      or not content.bte_warp_drive_alert.bte_warp_drive_alert_details.bte_warp_drive_alert_header
      or not content.bte_warp_drive_alert.bte_warp_drive_alert_details.bte_warp_drive_alert_header.bte_warp_drive_alert_sprite
      or not content.bte_warp_drive_alert.bte_warp_drive_alert_details.bte_warp_drive_alert_header.bte_warp_drive_alert_text
      or not content.bte_warp_drive_alert.bte_warp_drive_alert_details.bte_warp_drive_alert_boost
      or not content.bte_warp_drive_alert.bte_warp_drive_alert_details.bte_warp_drive_alert_speed
      or not content.bte_warp_drive_alert.bte_warp_drive_alert_details.bte_warp_drive_alert_charge_progress
      or not content.bte_warp_drive_location_heading
      or not content.bte_warp_drive_location_row
      or not content.bte_warp_drive_location_row.bte_warp_drive_location_label
      or not content.bte_warp_drive_location_row.bte_warp_drive_location
      or not detector.bte_warp_drive_detector_bar
      or not status(research, "bte_warp_drive_average_lab_rate")
      or not research.bte_warp_drive_detector_help
      or not research.bte_warp_drive_completion_section
      or not status(research.bte_warp_drive_completion_section, "bte_warp_drive_research_estimate")
      or not warp.bte_warp_drive_requirement_control_row
      or not warp.bte_warp_drive_requirement_acceleration_row
      or not circuit[GUI_TOGGLE]
      or not circuit[GUI_CIRCUIT_TOGGLE]
      or not editor[GUI_CIRCUIT_FIRST_SIGNAL]
      or not editor[GUI_CIRCUIT_COMPARATOR]
      or not editor[GUI_CIRCUIT_SECOND_SIGNAL]
      or not editor[GUI_CIRCUIT_CONSTANT]
      or not circuit[GUI_OUTPUT_WARP_ENABLED .. "_row"]
      or not circuit[GUI_OUTPUT_DISTANCE_ENABLED .. "_row"]
      or not circuit[GUI_OUTPUT_CHARGE_ENABLED .. "_row"]
      or not circuit[GUI_OUTPUT_SPEED_ENABLED .. "_row"]
      or not circuit[GUI_OUTPUT_TACHYON_DENSITY_ENABLED .. "_row"]
      or not networks.bte_warp_drive_circuit_red_network
      or not networks.bte_warp_drive_circuit_green_network then
    return nil
  end
  for _, name in pairs({
    "bte_warp_drive_detector_status", "bte_warp_drive_detector_power"
  }) do
    if not status(detector, name) then
      return nil
    end
  end
  for _, name in pairs({
    "bte_warp_drive_signal_multiplier", "bte_warp_drive_detector_speed",
    "bte_warp_drive_detector_power_multiplier", "bte_warp_drive_tachyon_rate",
    "bte_warp_drive_research_status", "bte_warp_drive_research_branch", "bte_warp_drive_working_labs",
    "bte_warp_drive_average_lab_rate", "bte_warp_drive_research_bonus",
    "bte_warp_drive_research_progress"
  }) do
    if not status(research, name) then
      return nil
    end
  end
  for _, name in pairs({
    "bte_warp_drive_requirement_control", "bte_warp_drive_requirement_travel",
    "bte_warp_drive_requirement_clearance", "bte_warp_drive_requirement_cooldown",
    "bte_warp_drive_requirement_charge", "bte_warp_drive_requirement_power",
    "bte_warp_drive_requirement_speed", "bte_warp_drive_requirement_acceleration"
  }) do
    local row = warp[name .. "_row"]
    if not row or not row[name .. "_icon"] or not row[name .. "_label"] or not row[name] then
      return nil
    end
  end
  for enabled_name in pairs(OUTPUT_TOGGLE_FIELDS) do
    local row = circuit[enabled_name .. "_row"]
    local signal_name = OUTPUT_SIGNAL_NAMES[enabled_name]
    if not row or not row[enabled_name] or not signal_name or not row[signal_name] then
      return nil
    end
  end
  return {
    frame = frame,
    content = content,
    detector = detector,
    research = research,
    warp = warp,
    circuit = circuit,
    networks = networks,
    editor = editor,
    circuit_state = circuit_state
  }
end

local function requirement(view, name, state, caption)
  local row = view.warp[name .. "_row"]
  local presentation = {
    pass = {"utility/check_mark_green", "green_label", "label"},
    fail = {"utility/status_not_working", "red_label", "label"},
    warning = {"utility/status_yellow", "orange_label", "label"},
    disabled = {"utility/status_inactive", "grey_label", "grey_label"}
  }
  local selected = presentation[state]
  row[name .. "_icon"].sprite = selected[1]
  row[name .. "_label"].style = selected[2]
  row[name].caption = caption
  row[name].style = selected[3]
end

local function render_mode(view, record, snapshot)
  local practical = snapshot.practical
  view.detector.visible = not practical
  view.research.visible = not practical
  view.warp.visible = practical
  view.content.bte_warp_drive_location_heading.caption = practical
    and {"bte-warp-drive.current-position-section"} or {"bte-warp-drive.location-section"}
  view.content.bte_warp_drive_location_row.bte_warp_drive_location_label.visible = not practical
  view.content.bte_warp_drive_location_row.bte_warp_drive_location.style.width = practical
    and STATUS_LABEL_WIDTH + STATUS_VALUE_WIDTH or STATUS_VALUE_WIDTH
  view.content.bte_warp_drive_mode_help.visible = not practical
  local alert = view.content.bte_warp_drive_alert
  local details = alert.bte_warp_drive_alert_details
  local header = details.bte_warp_drive_alert_header
  local alert_sprite = header.bte_warp_drive_alert_sprite
  local alert_text = header.bte_warp_drive_alert_text
  local alert_boost = details.bte_warp_drive_alert_boost
  local alert_speed = details.bte_warp_drive_alert_speed
  local charge_progress = details.bte_warp_drive_alert_charge_progress
  alert.visible = practical
  local active = record.state == "warp" and record.warp_warning ~= "power"
  local charging = record.state == "charging"
  alert_boost.visible = active or (not charging and record.state ~= "warp")
  alert_speed.visible = active
  charge_progress.visible = charging
  if record.warp_warning == "power" then
    alert_sprite.sprite = "utility/danger_icon"
    alert_text.style = "bold_red_label"
    alert_text.caption = {"bte-warp-drive.warning-power"}
  elseif record.state == "warp" then
    alert_sprite.sprite = "utility/status_working"
    alert_text.style = "label"
    alert_text.caption = {"bte-warp-drive.active-warp-level",
      string.format("%.1f", record.warp_level or 1)}
    alert_boost.caption = {"bte-warp-drive.active-warp-boost",
      string.format("%.2f", snapshot.warp_boost)}
    alert_speed.caption = {"bte-warp-drive.active-warp-effective-speed",
      string.format("%.2f", snapshot.effective_speed)}
  elseif charging then
    alert_sprite.sprite = "utility/status_yellow"
    alert_text.style = "orange_label"
    alert_text.caption = {"bte-warp-drive.charging-status"}
    charge_progress.value = snapshot.charge_ratio
    charge_progress.caption = {"bte-warp-drive.percent-value",
      math.floor(snapshot.charge_ratio * 100)}
    alert_speed.visible = true
    alert_speed.caption = {"bte-warp-drive.charging-remaining",
      format_energy(math.max(0, snapshot.required_charge - snapshot.stored_charge))}
  elseif record.last_exit_reason and record.state ~= "warp" then
    alert_sprite.sprite = "utility/status_not_working"
    alert_text.style = "label"
    alert_text.caption = {"bte-warp-drive.inactive-status"}
    alert_boost.caption = {"bte-warp-drive.last-deactivation-reason",
      {"bte-warp-drive.deactivation-reason-" .. record.last_exit_reason}}
  else
    alert_sprite.sprite = "utility/status_not_working"
    alert_text.style = "label"
    alert_text.caption = {"bte-warp-drive.inactive-status"}
    alert_boost.caption = {"bte-warp-drive.last-deactivation-reason",
      {"bte-warp-drive.deactivation-reason-none"}}
  end
end

local function render_research(view, record, snapshot, research_snapshot)
  local practical = snapshot.practical
  status(view.detector, "bte_warp_drive_detector_status").caption = {
    "bte-warp-drive.state-" .. (practical and "complete" or record.state)
  }
  status(view.detector, "bte_warp_drive_detector_power").caption = {
    "bte-warp-drive.power-value",
    format_power(record.detector_power or 0),
    format_power(DETECTOR_MAX_POWER_WATTS),
    math.floor((record.detector_power or 0) / DETECTOR_MAX_POWER_WATTS * 100)
  }
  local detector_power_fraction = math.min(1,
    (record.detector_power or 0) / DETECTOR_MAX_POWER_WATTS)
  view.detector.bte_warp_drive_detector_bar.value = detector_power_fraction
  view.detector.bte_warp_drive_detector_bar.caption = {
    "bte-warp-drive.percent-value", math.floor(detector_power_fraction * 100)
  }
  local branch = research_snapshot.branch
  local researching_practical = research_snapshot.researching_practical
  status(view.research, "bte_warp_drive_research_branch").caption = {
    "bte-warp-drive.branch-" .. (branch or "unknown")
  }
  status(view.research, "bte_warp_drive_research_status").caption = practical
    and {"bte-warp-drive.research-status-complete"}
    or (researching_practical and {"bte-warp-drive.research-status-active"}
      or {"bte-warp-drive.research-status-inactive"})
  local best = research_snapshot.deepest_location
  local best_name = best and location_label(best) or {"bte-warp-drive.location-unknown"}
  local emphasized_best_name = {"", "[font=default-bold]", best_name, "[/font]"}
  local location = view.content.bte_warp_drive_location_row.bte_warp_drive_location
  if snapshot.location then
    location.caption = {"bte-warp-drive.location-parked", location_label(snapshot.location)}
  elseif snapshot.route_from then
    location.caption = {
      "bte-warp-drive.location-transit-distance",
      location_label(snapshot.route_from),
      location_label(snapshot.route_to),
      format_km(snapshot.remaining_km)
    }
  else
    location.caption = {"bte-warp-drive.location-unknown"}
  end
  status(view.research, "bte_warp_drive_signal_multiplier").caption = {
    "bte-warp-drive.density-value", string.format("%.1f", research_snapshot.density)
  }
  status(view.research, "bte_warp_drive_detector_speed").caption = {
    "bte-warp-drive.detector-speed-value",
    string.format("%.2f", research_snapshot.detector_speed),
    string.format("%.2f", research_snapshot.detector_speed_factor)
  }
  status(view.research, "bte_warp_drive_detector_power_multiplier").caption = {
    "bte-warp-drive.multiplier-value", string.format("%.2f", research_snapshot.power_ratio)
  }
  view.research.bte_warp_drive_detector_help.caption = practical
    and {"bte-warp-drive.detector-help-complete"} or {
      "bte-warp-drive.detector-help-" .. (branch or "unknown"),
      emphasized_best_name,
      string.format("%.0f", research_snapshot.maximum_density)
    }
  status(view.research, "bte_warp_drive_tachyon_rate").caption = {
    "bte-warp-drive.tachyon-value", string.format("%.2f", research_snapshot.detector_signal)
  }
  status(view.research, "bte_warp_drive_working_labs").caption = bold_number(research_snapshot.lab_count)
  view.research.bte_warp_drive_average_lab_rate_row.visible = researching_practical
  if researching_practical then
    status(view.research, "bte_warp_drive_average_lab_rate").caption = {
      "bte-warp-drive.research-rate-value", string.format("%.4f", research_snapshot.average_lab_rate)
    }
  end
  status(view.research, "bte_warp_drive_research_bonus").caption = {
    "bte-warp-drive.research-rate-value", string.format("%.2f", research_snapshot.bonus_rate)
  }
  view.research.bte_warp_drive_research_progress_row.visible = researching_practical
  view.research.bte_warp_drive_completion_section.visible = researching_practical
  if researching_practical then
    status(view.research, "bte_warp_drive_research_progress").caption = {
      "bte-warp-drive.percent-value", string.format("%.6f", research_snapshot.progress * 100)
    }
    status(view.research.bte_warp_drive_completion_section, "bte_warp_drive_research_estimate").caption =
      research_snapshot.total_rate > 0 and {"bte-warp-drive.estimate-value",
        format_duration(research_snapshot.remaining_units / research_snapshot.total_rate),
        string.format("%.2f", research_snapshot.total_rate)}
      or {"bte-warp-drive.estimate-unavailable"}
  end
end

local function render_warp_requirements(view, record, snapshot)
  local control_state, control_caption
  if record.enabled then
    control_state = "pass"
    control_caption = {"bte-warp-drive.requirement-control-automatic"}
  elseif record.circuit_enabled and snapshot.circuit_active then
    control_state = "pass"
    control_caption = {"bte-warp-drive.requirement-control-circuit-active"}
  elseif record.circuit_enabled then
    control_state = "warning"
    control_caption = {"bte-warp-drive.requirement-control-circuit-waiting"}
  else
    control_state = "disabled"
    control_caption = {"bte-warp-drive.requirement-control-disabled"}
  end
  requirement(view, "bte_warp_drive_requirement_control", control_state, control_caption)
  local reserve_active = record.state == "warp" or snapshot.preparation_ready
  requirement(view, "bte_warp_drive_requirement_charge", not reserve_active and "disabled"
      or (snapshot.charge_ratio >= 0.999 and "pass" or "warning"),
    {"bte-warp-drive.charge-value", format_energy(snapshot.stored_charge),
      format_energy(snapshot.required_charge), math.floor(snapshot.charge_ratio * 100)})
  local speed_state = not snapshot.control_active and "disabled"
    or (snapshot.speed_ready and "pass"
      or (record.state == "warp" and record.speed_exit_at and "warning" or "fail"))
  local speed_caption = speed_state == "warning"
    and {"bte-warp-drive.requirement-speed-warning", string.format("%.1f", snapshot.speed),
      string.format("%.1f", math.max(0, record.speed_exit_at - game.tick) / TICKS_PER_SECOND)}
    or {"bte-warp-drive.requirement-speed-value", string.format("%.1f", snapshot.speed)}
  requirement(view, "bte_warp_drive_requirement_speed", speed_state, speed_caption)
  local power_active = record.state == "warp" or record.state == "charging"
  local power_state = not snapshot.control_active and "disabled"
    or (not power_active and "disabled"
      or ((record.state == "charging" or record.warp_ramp_state == "stabilizing")
        and "warning" or (snapshot.power_ready and "pass" or "fail")))
  requirement(view, "bte_warp_drive_requirement_power", power_state,
    {"bte-warp-drive.requirement-power-value", format_power(record.support_power or 0)})
  local ramp_state = record.warp_ramp_state or "inactive"
  local acceleration_state = (not snapshot.control_active or record.state ~= "warp") and "disabled"
    or (ramp_state == "accelerating" and "pass"
      or (ramp_state == "reserve" and "fail" or "warning"))
  requirement(view, "bte_warp_drive_requirement_acceleration", acceleration_state,
    {"bte-warp-drive.ramp-" .. ramp_state})
  requirement(view, "bte_warp_drive_requirement_travel", not snapshot.control_active and "disabled"
      or (snapshot.travel_active and snapshot.destination and "pass" or "fail"),
    snapshot.destination and location_label(snapshot.destination)
      or {"bte-warp-drive.requirement-travel-inactive"})
  requirement(view, "bte_warp_drive_requirement_clearance", not snapshot.control_active and "disabled"
      or (snapshot.clearance and "pass" or "fail"),
    snapshot.clearance and {"bte-warp-drive.requirement-clearance-clear"}
      or (snapshot.closest_endpoint and snapshot.endpoint_blocked
        and {"bte-warp-drive.requirement-clearance-blocked",
          format_km(snapshot.endpoint_distance_km), location_label(snapshot.closest_endpoint)}
        or {"bte-warp-drive.requirement-clearance-unavailable"}))
  requirement(view, "bte_warp_drive_requirement_cooldown", not snapshot.control_active and "disabled"
      or (snapshot.cooldown_ready and "pass" or "fail"),
    snapshot.cooldown_ready and {"bte-warp-drive.requirement-cooldown-ready"}
      or {"bte-warp-drive.requirement-cooldown-waiting", math.ceil(snapshot.cooldown_seconds)})
end

local function output_controls(view, enabled_name, signal_name)
  local row = view.circuit[enabled_name .. "_row"]
  return row[enabled_name], row[signal_name]
end

local function render_circuit_network(view, record, snapshot)
  view.circuit[GUI_TOGGLE].state = record.enabled
  view.circuit[GUI_TOGGLE].caption = {"bte-warp-drive."
    .. (snapshot.practical and "enabled" or "research-enabled")}
  view.circuit[GUI_TOGGLE].tooltip = {"bte-warp-drive."
    .. (snapshot.practical and "enabled-tooltip" or "research-enabled-tooltip")}
  view.circuit[GUI_TOGGLE].enabled = true
  view.circuit[GUI_CIRCUIT_TOGGLE].state = record.circuit_enabled
  view.circuit[GUI_CIRCUIT_TOGGLE].caption = {"bte-warp-drive."
    .. (snapshot.practical and "circuit-enabled" or "research-circuit-enabled")}
  view.circuit[GUI_CIRCUIT_TOGGLE].tooltip = {"bte-warp-drive."
    .. (snapshot.practical and "circuit-enabled-tooltip"
      or "research-circuit-enabled-tooltip")}
  view.circuit[GUI_CIRCUIT_TOGGLE].enabled = true
  view.editor.enabled = record.circuit_enabled
  view.editor[GUI_CIRCUIT_FIRST_SIGNAL].elem_value = record.circuit_first_signal
  view.editor[GUI_CIRCUIT_COMPARATOR].selected_index = CIRCUIT_COMPARATOR_INDEX[
    record.circuit_comparator] or 1
  view.editor[GUI_CIRCUIT_SECOND_SIGNAL].elem_value = record.circuit_second_signal
  view.editor[GUI_CIRCUIT_CONSTANT].visible = record.circuit_second_signal == nil
  local toggle, signal = output_controls(view, GUI_OUTPUT_WARP_ENABLED, GUI_OUTPUT_WARP_SIGNAL)
  toggle.state = record.output_warp_enabled ~= false
  signal.elem_value = record.output_warp_signal or WARP_LEVEL_SIGNAL
  signal.enabled = record.output_warp_enabled ~= false
  view.circuit[GUI_OUTPUT_WARP_ENABLED .. "_row"].visible = snapshot.practical
  toggle, signal = output_controls(view, GUI_OUTPUT_DISTANCE_ENABLED, GUI_OUTPUT_DISTANCE_SIGNAL)
  toggle.state = record.output_distance_enabled == true
  signal.elem_value = record.output_distance_signal or DISTANCE_SIGNAL
  signal.enabled = record.output_distance_enabled == true
  toggle, signal = output_controls(view, GUI_OUTPUT_CHARGE_ENABLED, GUI_OUTPUT_CHARGE_SIGNAL)
  toggle.state = record.output_charge_enabled ~= false
  signal.elem_value = record.output_charge_signal or CHARGE_SIGNAL
  signal.enabled = record.output_charge_enabled ~= false
  view.circuit[GUI_OUTPUT_CHARGE_ENABLED .. "_row"].visible = snapshot.practical
  toggle, signal = output_controls(view, GUI_OUTPUT_SPEED_ENABLED, GUI_OUTPUT_SPEED_SIGNAL)
  toggle.state = record.output_speed_enabled ~= false
  signal.elem_value = record.output_speed_signal or SPEED_SIGNAL
  signal.enabled = record.output_speed_enabled ~= false
  view.circuit[GUI_OUTPUT_SPEED_ENABLED .. "_row"].visible = snapshot.practical
  toggle, signal = output_controls(view, GUI_OUTPUT_TACHYON_DENSITY_ENABLED,
    GUI_OUTPUT_TACHYON_DENSITY_SIGNAL)
  toggle.state = record.output_tachyon_density_enabled == true
  signal.elem_value = record.output_tachyon_density_signal or TACHYON_DENSITY_SIGNAL
  signal.enabled = record.output_tachyon_density_enabled == true
  view.circuit[GUI_OUTPUT_TACHYON_DENSITY_ENABLED .. "_row"].visible = not snapshot.practical
  view.circuit_state.visible = record.circuit_enabled and snapshot.circuit_active
  update_circuit_network_row(view.networks.bte_warp_drive_circuit_red_network, record, "red",
    defines.wire_connector_id.circuit_red)
  update_circuit_network_row(view.networks.bte_warp_drive_circuit_green_network, record, "green",
    defines.wire_connector_id.circuit_green)
end

local update_gui

local function draw_gui(player, record)
  local old = player.gui.screen[GUI_NAME]
  if old then
    old.destroy()
  end
  if not record.entity or not record.entity.valid then
    return
  end
  local frame = player.gui.screen.add({type = "frame", name = GUI_NAME, direction = "vertical"})
  frame.tags = {platform_index = record.platform_index, layout_version = 8}
  frame.style.width = MAIN_PANEL_WIDTH + PANEL_GAP + CIRCUIT_PANEL_WIDTH + 24
  frame.auto_center = true
  local title = frame.add({type = "flow", name = "bte_warp_drive_title", direction = "horizontal"})
  title.style.vertical_align = "center"
  title.drag_target = frame
  title.add({type = "sprite", sprite = "entity/warp-drive-controller"})
  local title_label = title.add({type = "label", caption = {"bte-warp-drive.title"}, style = "frame_title"})
  title_label.style.left_margin = 8
  local spacer = title.add({type = "empty-widget", style = "draggable_space_header"})
  spacer.style.horizontally_stretchable = true
  spacer.style.height = 24
  spacer.drag_target = frame
  title.add({type = "sprite-button", name = GUI_CLOSE, sprite = "utility/close", style = "frame_action_button"})

  local body = frame.add({type = "flow", name = "bte_warp_drive_body", direction = "horizontal"})
  body.style.width = MAIN_PANEL_WIDTH + PANEL_GAP + CIRCUIT_PANEL_WIDTH
  body.style.horizontal_spacing = PANEL_GAP
  body.style.vertical_align = "top"
  local scroll = body.add({
    type = "scroll-pane",
    name = "bte_warp_drive_content_scroll",
    direction = "vertical",
    style = "scroll_pane_in_shallow_frame"
  })
  scroll.style.width = MAIN_PANEL_WIDTH
  local content = scroll.add({type = "flow", name = "bte_warp_drive_content", direction = "vertical"})
  content.style.padding = 12
  content.style.width = 512
  local mode_help = content.add({
    type = "label",
    name = "bte_warp_drive_mode_help",
    caption = {"bte-warp-drive.mode-experimental-help"}
  })
  mode_help.style.single_line = false
  mode_help.style.top_margin = 4
  mode_help.style.bottom_margin = 8
  local alert = content.add({type = "flow", name = "bte_warp_drive_alert", direction = "vertical"})
  alert.style.height = 76
  alert.style.top_margin = 6
  alert.style.bottom_margin = 8
  local alert_details = alert.add({
    type = "flow",
    name = "bte_warp_drive_alert_details",
    direction = "vertical"
  })
  alert_details.style.width = 480
  local alert_header = alert_details.add({
    type = "flow",
    name = "bte_warp_drive_alert_header",
    direction = "horizontal"
  })
  alert_header.style.vertical_align = "center"
  alert_header.style.horizontal_spacing = 8
  local alert_sprite = alert_header.add({
    type = "sprite",
    name = "bte_warp_drive_alert_sprite",
    sprite = "utility/status_inactive"
  })
  alert_sprite.style.size = 18
  alert_sprite.style.stretch_image_to_widget_size = true
  local alert_text = alert_header.add({
    type = "label",
    name = "bte_warp_drive_alert_text",
    caption = {"bte-warp-drive.inactive-status"}
  })
  alert_text.style.single_line = false
  alert_text.style.width = 454
  local alert_boost = alert_details.add({
    type = "label",
    name = "bte_warp_drive_alert_boost",
    caption = ""
  })
  alert_boost.style.left_margin = 26
  alert_boost.style.width = 454
  alert_boost.style.single_line = false
  local charge_progress = alert_details.add({
    type = "progressbar",
    name = "bte_warp_drive_alert_charge_progress",
    value = 0,
    caption = {"bte-warp-drive.percent-value", 0},
    style = "production_progressbar"
  })
  charge_progress.style.left_margin = 26
  charge_progress.style.width = 454
  local alert_speed = alert_details.add({
    type = "label",
    name = "bte_warp_drive_alert_speed",
    caption = ""
  })
  alert_speed.style.left_margin = 26
  alert_speed.style.width = 454
  alert_speed.style.single_line = false

  local detector = content.add({type = "flow", name = "bte_warp_drive_detector_section", direction = "vertical"})
  detector.style.horizontally_stretchable = true
  detector.add({type = "line"})
  add_section_heading(detector, {"bte-warp-drive.detector-section"})
  add_status_row(detector, "bte_warp_drive_detector_status", {"bte-warp-drive.detector-status"})
  add_status_row(detector, "bte_warp_drive_detector_power", {"bte-warp-drive.detector-power"})
  local detector_bar = detector.add({type = "progressbar", name = "bte_warp_drive_detector_bar", value = 0, style = "production_progressbar"})
  detector_bar.style.horizontally_stretchable = true
  detector_bar.style.bottom_margin = 8

  add_section_heading(content, {"bte-warp-drive.location-section"}, "bte_warp_drive_location_heading")
  local location_row = content.add({type = "flow", name = "bte_warp_drive_location_row", direction = "horizontal"})
  local location_label_element = location_row.add({type = "label", name = "bte_warp_drive_location_label", caption = {"bte-warp-drive.location"}})
  location_label_element.style.width = STATUS_LABEL_WIDTH
  location_label_element.style.single_line = false
  local location = location_row.add({type = "label", name = "bte_warp_drive_location", caption = ""})
  location.style.width = STATUS_VALUE_WIDTH
  location.style.single_line = false

  local research = content.add({type = "flow", name = "bte_warp_drive_research_section", direction = "vertical"})
  research.style.horizontally_stretchable = true
  add_status_row(research, "bte_warp_drive_signal_multiplier", {"bte-warp-drive.signal-multiplier"})
  add_status_row(research, "bte_warp_drive_detector_speed", {"bte-warp-drive.detector-speed"})
  add_status_row(research, "bte_warp_drive_detector_power_multiplier", {"bte-warp-drive.detector-power-signal"})
  add_status_row(research, "bte_warp_drive_tachyon_rate", {"bte-warp-drive.tachyon-rate"})
  add_section_heading(research, {"bte-warp-drive.research-section"})
  add_status_row(research, "bte_warp_drive_research_status", {"bte-warp-drive.research-status"})
  add_status_row(research, "bte_warp_drive_research_branch", {"bte-warp-drive.research-branch"})
  add_status_row(research, "bte_warp_drive_working_labs", {"bte-warp-drive.working-labs"})
  add_status_row(research, "bte_warp_drive_average_lab_rate", {"bte-warp-drive.average-lab-rate"})
  add_status_row(research, "bte_warp_drive_research_bonus", {"bte-warp-drive.research-bonus"})
  add_status_row(research, "bte_warp_drive_research_progress", {"bte-warp-drive.research-progress"})
  local completion = research.add({type = "flow", name = "bte_warp_drive_completion_section", direction = "vertical"})
  completion.style.horizontally_stretchable = true
  add_section_heading(completion, {"bte-warp-drive.completion-section"}, "bte_warp_drive_completion_heading")
  add_status_row(completion, "bte_warp_drive_research_estimate", {"bte-warp-drive.research-estimate"})
  add_section_heading(research, {"bte-warp-drive.research-help-section"}, "bte_warp_drive_research_help_heading")
  local help = research.add({type = "label", name = "bte_warp_drive_detector_help", caption = {"bte-warp-drive.detector-help-unknown"}})
  help.style.single_line = false
  help.style.bottom_margin = 8

  local warp = content.add({type = "flow", name = "bte_warp_drive_warp_section", direction = "vertical"})
  warp.style.horizontally_stretchable = true
  warp.add({type = "line"})
  add_section_heading(warp, {"bte-warp-drive.warp-section"})
  add_requirement(warp, "bte_warp_drive_requirement_control", {"bte-warp-drive.requirement-control-label"})
  add_requirement(warp, "bte_warp_drive_requirement_travel", {"bte-warp-drive.requirement-travel-label"})
  add_requirement(warp, "bte_warp_drive_requirement_clearance", {"bte-warp-drive.requirement-clearance-label"})
  add_requirement(warp, "bte_warp_drive_requirement_cooldown", {"bte-warp-drive.requirement-cooldown-label"})
  add_requirement(warp, "bte_warp_drive_requirement_charge", {"bte-warp-drive.requirement-charge-label"})
  add_requirement(warp, "bte_warp_drive_requirement_power", {"bte-warp-drive.requirement-power-label"})
  add_requirement(warp, "bte_warp_drive_requirement_speed", {"bte-warp-drive.requirement-speed-label"})
  add_requirement(warp, "bte_warp_drive_requirement_acceleration", {"bte-warp-drive.requirement-acceleration-label"})

  local circuit = body.add({type = "frame", name = "bte_warp_drive_circuit_panel", direction = "vertical", style = "inside_shallow_frame"})
  circuit.style.width = CIRCUIT_PANEL_WIDTH
  circuit.style.padding = 12
  add_section_heading(circuit, {"bte-warp-drive.circuit-panel"})
  local networks = circuit.add({type = "flow", name = "bte_warp_drive_circuit_networks", direction = "vertical"})
  networks.style.bottom_margin = 8
  add_circuit_network_row(networks, "bte_warp_drive_circuit_red_network", "red")
  add_circuit_network_row(networks, "bte_warp_drive_circuit_green_network", "green")
  add_labeled_checkbox(circuit, GUI_TOGGLE, {"bte-warp-drive.enabled"}, {"bte-warp-drive.enabled-tooltip"}, true)
  add_labeled_checkbox(circuit, GUI_CIRCUIT_TOGGLE, {"bte-warp-drive.circuit-enabled"}, {"bte-warp-drive.circuit-enabled-tooltip"}, false)
  local editor = circuit.add({type = "flow", name = "bte_warp_drive_circuit_editor", direction = "horizontal"})
  editor.style.vertical_align = "center"
  editor.style.top_margin = 8
  editor.add({type = "choose-elem-button", name = GUI_CIRCUIT_FIRST_SIGNAL, elem_type = "signal", signal = record.circuit_first_signal})
  local comparator = editor.add({type = "drop-down", name = GUI_CIRCUIT_COMPARATOR, items = CIRCUIT_COMPARATORS, selected_index = CIRCUIT_COMPARATOR_INDEX[record.circuit_comparator] or 1})
  comparator.style.width = 60
  editor.add({type = "choose-elem-button", name = GUI_CIRCUIT_SECOND_SIGNAL, elem_type = "signal", signal = record.circuit_second_signal})
  local constant = editor.add({type = "textfield", name = GUI_CIRCUIT_CONSTANT, text = tostring(record.circuit_constant or 0), numeric = true, allow_decimal = false, allow_negative = true})
  constant.style.width = 72
  local circuit_state = circuit.add({type = "flow", name = "bte_warp_drive_circuit_state", direction = "horizontal"})
  circuit_state.style.vertical_align = "center"
  circuit_state.style.bottom_margin = 8
  local circuit_state_icon = circuit_state.add({type = "sprite", name = "bte_warp_drive_circuit_state_icon", sprite = "utility/status_working"})
  circuit_state_icon.style.size = 18
  circuit_state_icon.style.stretch_image_to_widget_size = true
  circuit_state.add({type = "label", name = "bte_warp_drive_circuit_state_label", caption = {"bte-warp-drive.circuit-condition-active"}, style = "green_label"})
  circuit.add({type = "line"})
  add_section_heading(circuit, {"bte-warp-drive.circuit-outputs"})
  add_circuit_output(circuit, GUI_OUTPUT_WARP_ENABLED, GUI_OUTPUT_WARP_SIGNAL,
    {"bte-warp-drive.output-warp-level"}, {"bte-warp-drive.output-warp-level-tooltip"},
    record.output_warp_enabled ~= false, record.output_warp_signal or WARP_LEVEL_SIGNAL)
  add_circuit_output(circuit, GUI_OUTPUT_DISTANCE_ENABLED, GUI_OUTPUT_DISTANCE_SIGNAL,
    {"bte-warp-drive.output-distance"}, {"bte-warp-drive.output-distance-tooltip"},
    record.output_distance_enabled == true, record.output_distance_signal or DISTANCE_SIGNAL)
  add_circuit_output(circuit, GUI_OUTPUT_CHARGE_ENABLED, GUI_OUTPUT_CHARGE_SIGNAL,
    {"bte-warp-drive.output-charge"}, {"bte-warp-drive.output-charge-tooltip"},
    record.output_charge_enabled ~= false, record.output_charge_signal or CHARGE_SIGNAL)
  add_circuit_output(circuit, GUI_OUTPUT_SPEED_ENABLED, GUI_OUTPUT_SPEED_SIGNAL,
    {"bte-warp-drive.output-speed"}, {"bte-warp-drive.output-speed-tooltip"},
    record.output_speed_enabled ~= false, record.output_speed_signal or SPEED_SIGNAL)
  add_circuit_output(circuit, GUI_OUTPUT_TACHYON_DENSITY_ENABLED,
    GUI_OUTPUT_TACHYON_DENSITY_SIGNAL,
    {"bte-warp-drive.output-tachyon-density"}, {"bte-warp-drive.output-tachyon-density-tooltip"},
    record.output_tachyon_density_enabled == true,
    record.output_tachyon_density_signal or TACHYON_DENSITY_SIGNAL)
  player.opened = frame
  update_gui_height(player)
  update_gui(player, record)
end

update_gui = function(player, record)
  local frame = player.gui.screen[GUI_NAME]
  if not frame or not record.entity or not record.entity.valid then
    if frame then
      frame.destroy()
    end
    return
  end
  local platform = record.entity.surface.platform
  if not platform then
    frame.destroy()
    return
  end
  local view = view_from_frame(frame)
  if not view then
    draw_gui(player, record)
    return
  end
  local snapshot = snapshot_callback and snapshot_callback(record)
  local research_snapshot = Research.snapshot(record)
  if not snapshot or not research_snapshot then
    frame.destroy()
    return
  end
  frame.tags = {platform_index = record.platform_index, layout_version = 8}
  render_mode(view, record, snapshot)
  render_research(view, record, snapshot, research_snapshot)
  render_warp_requirements(view, record, snapshot)
  render_circuit_network(view, record, snapshot)
end

function Gui.refresh_open_windows()
  for _, player in pairs(game.connected_players) do
    local frame = player.gui.screen[GUI_NAME]
    if frame then
      local record = Drive.get(frame.tags.platform_index)
      if record then
        update_gui(player, record)
      else
        frame.destroy()
      end
    end
  end
end

function Gui.refresh_for_setting(setting)
  if setting == IMPATIENT_SETTING then
    Gui.refresh_open_windows()
  end
end

local function gui_record(element)
  local frame = element
  while frame and frame.name ~= GUI_NAME do
    frame = frame.parent
  end
  return frame and Drive.get(frame.tags.platform_index)
end

local function refresh_after_condition_change(element, player_index)
  local record = gui_record(element)
  if record then
    if engagement_changed_callback then
      engagement_changed_callback(record, true)
    end
    if snapshot_callback then
      update_gui(game.get_player(player_index), record)
    end
  end
end

local handlers = {}

function handlers.on_gui_opened(event)
  local entity = event.entity
  if not entity or entity.name ~= DRIVE_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  -- Clear the native combinator GUI before drawing ours; doing this before the cursor check
  -- preserves Factorio's wire and planner interactions without exposing internal slots.
  player.opened = nil
  local cursor = player.cursor_stack
  if cursor and cursor.valid_for_read then
    return
  end
  local platform = entity.surface.platform
  local record = platform and Drive.get(platform.index)
  if record then
    draw_gui(player, record)
  end
end

function handlers.on_custom_open(event)
  local player = game.get_player(event.player_index)
  local entity = player and player.selected
  if not entity or not entity.valid or entity.name ~= DRIVE_NAME then
    return
  end
  local cursor = player.cursor_stack
  if cursor and cursor.valid_for_read then
    return
  end
  local platform = entity.surface.platform
  local record = platform and Drive.get(platform.index)
  if record then
    player.opened = nil
    draw_gui(player, record)
  end
end

function handlers.on_gui_click(event)
  local element = event.element
  if not element or not element.valid or element.name ~= GUI_CLOSE then
    return
  end
  local player = game.get_player(event.player_index)
  player.opened = nil
  local frame = player.gui.screen[GUI_NAME]
  if frame then
    frame.destroy()
  end
end

function handlers.on_gui_checked_state_changed(event)
  local element = event.element
  if not element or not element.valid then
    return
  end
  local record = gui_record(element)
  if not record then
    return
  end
  local output_field = OUTPUT_TOGGLE_FIELDS[element.name]
  if output_field then
    record[output_field] = element.state
  elseif element.name == GUI_TOGGLE then
    record.enabled = element.state
    if element.state then
      record.circuit_enabled = false
    end
    Drive.normalize_engagement(record)
  elseif element.name == GUI_CIRCUIT_TOGGLE then
    record.circuit_enabled = element.state
    if element.state then
      record.enabled = false
    end
    Drive.normalize_engagement(record)
  else
    return
  end
  if not output_field and engagement_changed_callback then
    engagement_changed_callback(record, false)
  end
  if snapshot_callback then
    update_gui(game.get_player(event.player_index), record)
  end
end

function handlers.on_gui_elem_changed(event)
  local element = event.element
  if not element or not element.valid then
    return
  end
  local record = gui_record(element)
  if not record then
    return
  end
  local output = OUTPUT_SIGNAL_FIELDS[element.name]
  if output then
    record[output[1]] = element.elem_value or output[2]
    element.elem_value = record[output[1]]
  elseif element.name == GUI_CIRCUIT_FIRST_SIGNAL then
    record.circuit_first_signal = element.elem_value
  elseif element.name == GUI_CIRCUIT_SECOND_SIGNAL then
    record.circuit_second_signal = element.elem_value
  else
    return
  end
  if output then
    if snapshot_callback then
      update_gui(game.get_player(event.player_index), record)
    end
  else
    refresh_after_condition_change(element, event.player_index)
  end
end

function handlers.on_gui_selection_state_changed(event)
  local element = event.element
  if not element or not element.valid or element.name ~= GUI_CIRCUIT_COMPARATOR then
    return
  end
  local record = gui_record(element)
  if record then
    record.circuit_comparator = CIRCUIT_COMPARATORS[element.selected_index] or ">"
    refresh_after_condition_change(element, event.player_index)
  end
end

function handlers.on_gui_text_changed(event)
  local element = event.element
  if not element or not element.valid or element.name ~= GUI_CIRCUIT_CONSTANT then
    return
  end
  local record = gui_record(element)
  local value = tonumber(element.text)
  if record and value then
    record.circuit_constant = math.max(-2147483648, math.min(2147483647, value))
  end
end

function handlers.on_gui_confirmed(event)
  local element = event.element
  if not element or not element.valid or element.name ~= GUI_CIRCUIT_CONSTANT then
    return
  end
  local record = gui_record(element)
  if not record then
    return
  end
  local value = tonumber(element.text)
  record.circuit_constant = value and math.max(-2147483648,
    math.min(2147483647, math.floor(value))) or (record.circuit_constant or 0)
  element.text = tostring(record.circuit_constant)
  refresh_after_condition_change(element, event.player_index)
end

function handlers.on_display_changed(event)
  local player = game.get_player(event.player_index)
  if player and player.gui.screen[GUI_NAME] then
    update_gui_height(player)
    player.gui.screen[GUI_NAME].force_auto_center()
  end
end

function handlers.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  local frame = player.gui.screen[GUI_NAME]
  if frame and event.element == frame then
    frame.destroy()
  end
end

Gui.handlers = handlers

-- Integration test mods require this module to call its helpers directly. Only the owning mod
-- may register the event handlers, because Factorio permits one handler per event per mod.
if script.mod_name == "bte-warp-drive" then
  script.on_event(defines.events.on_gui_opened, handlers.on_gui_opened)
  script.on_event("bte-warp-drive-open", handlers.on_custom_open)
  script.on_event(defines.events.on_gui_click, handlers.on_gui_click)
  script.on_event(defines.events.on_gui_checked_state_changed,
    handlers.on_gui_checked_state_changed)
  script.on_event(defines.events.on_gui_elem_changed, handlers.on_gui_elem_changed)
  script.on_event(defines.events.on_gui_selection_state_changed,
    handlers.on_gui_selection_state_changed)
  script.on_event(defines.events.on_gui_text_changed, handlers.on_gui_text_changed)
  script.on_event(defines.events.on_gui_confirmed, handlers.on_gui_confirmed)
  script.on_event(defines.events.on_player_display_resolution_changed,
    handlers.on_display_changed)
  script.on_event(defines.events.on_player_display_scale_changed,
    handlers.on_display_changed)
  script.on_event(defines.events.on_gui_closed, handlers.on_gui_closed)
end

return Gui
