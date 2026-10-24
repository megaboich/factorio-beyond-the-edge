local Drive = require("__bte-warp-drive__/scripts/drive")
local Research = require("__bte-warp-drive__/scripts/research")

local Gui = {}

local DRIVE_NAME = "bte-warp-drive-controller"
local TITLE_SPRITE = "entity/" .. DRIVE_NAME
local CIRCUIT_OUTPUT_NAME = "bte-warp-drive-circuit-output"
local IMPATIENT_SETTING = "bte-warp-drive-severely-impatient"
local GUI_NAME = "bte_warp_drive_window"
local GUI_TABS = "bte_warp_drive_tabs"
local GUI_ENGAGE = "bte_warp_drive_engage"
local GUI_DISENGAGE = "bte_warp_drive_disengage"
local GUI_BOOST_START = "bte_warp_drive_boost_start"
local GUI_BOOST_STOP = "bte_warp_drive_boost_stop"
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
local LAYOUT_VERSION = 13
-- Tabs in display order; the selected one is remembered per player in storage.gui_tabs.
local TABS = {"warp", "detector", "signals"}
local TAB_INDEX = {warp = 1, detector = 2, signals = 3}
local LEFT_WIDTH = 520
local CIRCUIT_PANEL_WIDTH = 272
local PAGE_GAP = 8
local PAGE_WIDTH = LEFT_WIDTH + PAGE_GAP + CIRCUIT_PANEL_WIDTH
local PREVIEW_SIZE = 136
-- The header preview is a live camera rather than an entity-preview, because the drive's core
-- animation is drawn as script render objects that an entity-preview never shows. The building's
-- sprite is about 11.5 tiles tall and centred 1.16 tiles above the entity, so the camera aims there
-- and zooms to fit it: 32 px per tile at zoom 1.
local PREVIEW_OFFSET_Y = -1.16
local PREVIEW_ZOOM = PREVIEW_SIZE / (32 * 11.5)
local HEADER_GAP = 12
local HEADER_MAIN_WIDTH = PAGE_WIDTH - PREVIEW_SIZE - HEADER_GAP
local CONTROL_BUTTON_GAP = 8
local CONTROL_BUTTON_WIDTH = (HEADER_MAIN_WIDTH - CONTROL_BUTTON_GAP) / 2
local CONTROL_BUTTON_HEIGHT = 40
local BOOST_BUTTON_WIDTH = (LEFT_WIDTH - 24 - CONTROL_BUTTON_GAP) / 2
local BOOST_BUTTON_HEIGHT = 28
local STATUS_LABEL_WIDTH = 190
local STATUS_VALUE_WIDTH = LEFT_WIDTH - 24 - STATUS_LABEL_WIDTH - 12
local PAGE_HEIGHT_MIN = 240
local PAGE_HEIGHT_MAX = 440
-- Display height left for the tab pages after the title, header, tab strip, and screen margin.
local PAGE_HEIGHT_RESERVED = 360
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
-- Read Signals rows in display order: toggle element, signal element, locale stem, and whether the
-- output exists before Practical research, after it, or in both modes.
local OUTPUTS = {
  {GUI_OUTPUT_WARP_ENABLED, GUI_OUTPUT_WARP_SIGNAL, "output-warp-level", "practical"},
  {GUI_OUTPUT_DISTANCE_ENABLED, GUI_OUTPUT_DISTANCE_SIGNAL, "output-distance", "practical"},
  {GUI_OUTPUT_CHARGE_ENABLED, GUI_OUTPUT_CHARGE_SIGNAL, "output-charge", "practical"},
  {GUI_OUTPUT_SPEED_ENABLED, GUI_OUTPUT_SPEED_SIGNAL, "output-speed", "practical"},
  {GUI_OUTPUT_TACHYON_DENSITY_ENABLED, GUI_OUTPUT_TACHYON_DENSITY_SIGNAL, "output-tachyon-density", "both"}
}
local SIGNAL_RICH_TEXT_TAG = {
  item = "item",
  fluid = "fluid",
  virtual = "virtual-signal",
  entity = "entity",
  recipe = "recipe"
}
-- The warp engage and disengage conditions, then the Tachyon Science Boost detector's start and
-- stop conditions, share one editor layout; their element names are
-- `bte_warp_drive_<key>_<part>`, and CONDITION_ELEMENTS maps each name back to its record field.
local CONDITION_KEYS = {"activate", "deactivate", "detector_start", "detector_stop"}
local WARP_CONDITIONS = {activate = true, deactivate = true}
local CONDITION_ELEMENTS = {}
for _, key in ipairs(CONDITION_KEYS) do
  for _, part in ipairs({"enabled", "first_signal", "comparator", "second_signal", "constant"}) do
    CONDITION_ELEMENTS["bte_warp_drive_" .. key .. "_" .. part] = {key = key, part = part}
  end
end
local REQUIREMENT_PRESENTATION = {
  pass = {"utility/check_mark_green", "green_label", "label"},
  fail = {"utility/status_not_working", "red_label", "label"},
  warning = {"utility/status_yellow", "orange_label", "label"},
  disabled = {"utility/status_inactive", "grey_label", "grey_label"}
}
local STATUS_ICONS = {
  good = "utility/status_working",
  warning = "utility/status_yellow",
  bad = "utility/status_not_working",
  danger = "utility/danger_icon",
  off = "utility/status_inactive"
}
local STATUS_STYLES = {
  good = "bold_green_label",
  warning = "bold_orange_label",
  bad = "bold_red_label",
  danger = "bold_red_label",
  off = "bold_label"
}

local snapshot_callback
local button_callbacks

function Gui.configure(config)
  if snapshot_callback or button_callbacks then
    error("Warp Drive GUI callbacks may only be configured once")
  end
  snapshot_callback = assert(config.snapshot)
  button_callbacks = {
    [GUI_ENGAGE] = assert(config.engage),
    [GUI_DISENGAGE] = assert(config.disengage),
    [GUI_BOOST_START] = assert(config.start_detector),
    [GUI_BOOST_STOP] = assert(config.stop_detector)
  }
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

local function condition_locale(key, practical)
  local stem = (key:gsub("_", "-")) .. "-condition"
  return "bte-warp-drive." .. ((practical or WARP_CONDITIONS[key]) and "" or "research-") .. stem
end

-- Builders. Every element that rendering touches has a unique name, so the view can index the
-- whole tree by name; see view_from_frame.

local function add_heading(parent, name, caption)
  local heading = parent.add({type = "label", name = name, caption = caption, style = "heading_2_label"})
  heading.style.top_margin = 4
  heading.style.bottom_margin = 2
  return heading
end

local function add_status_row(parent, name, caption)
  local row = parent.add({type = "flow", name = name .. "_row", direction = "horizontal"})
  local label = row.add({type = "label", name = name .. "_label", caption = caption})
  label.style.width = STATUS_LABEL_WIDTH
  label.style.single_line = false
  local value = row.add({type = "label", name = name, caption = ""})
  value.style.width = STATUS_VALUE_WIDTH
  value.style.single_line = false
end

local function add_requirement(parent, name, caption)
  local row = parent.add({type = "flow", name = name .. "_row", direction = "horizontal"})
  row.style.vertical_align = "center"
  local icon = row.add({type = "sprite", name = name .. "_icon", sprite = "utility/status_inactive"})
  icon.style.size = 18
  icon.style.stretch_image_to_widget_size = true
  local label = row.add({type = "label", name = name .. "_label", caption = caption})
  label.style.width = STATUS_LABEL_WIDTH - 22
  label.style.single_line = false
  local value = row.add({type = "label", name = name, caption = ""})
  value.style.width = STATUS_VALUE_WIDTH
  value.style.single_line = false
end

local function add_bar(parent, name)
  local bar = parent.add({type = "progressbar", name = name, value = 0, style = "production_progressbar"})
  bar.style.horizontally_stretchable = true
  bar.style.top_margin = 2
  bar.style.bottom_margin = 4
end

local function add_button(parent, name, style, width, height, font)
  local button = parent.add({type = "button", name = name, caption = "", style = style})
  button.style.width = width
  button.style.height = height
  button.style.font = font
end

-- One condition: a checkbox with a dot that lights green while the condition holds, then its
-- signal, comparator, and signal-or-constant editor.
local function add_condition_editor(parent, key, condition)
  local prefix = "bte_warp_drive_" .. key
  local header = parent.add({type = "flow", name = prefix .. "_header", direction = "horizontal"})
  header.style.vertical_align = "center"
  header.style.top_margin = 6
  local checkbox = header.add({type = "checkbox", name = prefix .. "_enabled",
    caption = {condition_locale(key, true)}, state = condition.enabled})
  checkbox.style.horizontally_stretchable = true
  local state = header.add({type = "sprite", name = prefix .. "_state", sprite = STATUS_ICONS.off})
  state.style.size = 16
  state.style.stretch_image_to_widget_size = true
  local editor = parent.add({type = "flow", name = prefix .. "_editor", direction = "horizontal"})
  editor.style.vertical_align = "center"
  editor.style.top_margin = 2
  editor.add({type = "choose-elem-button", name = prefix .. "_first_signal", elem_type = "signal",
    signal = condition.first_signal})
  local comparator = editor.add({type = "drop-down", name = prefix .. "_comparator",
    items = CIRCUIT_COMPARATORS, selected_index = CIRCUIT_COMPARATOR_INDEX[condition.comparator] or 1})
  comparator.style.width = 60
  editor.add({type = "choose-elem-button", name = prefix .. "_second_signal", elem_type = "signal",
    signal = condition.second_signal})
  local constant = editor.add({type = "textfield", name = prefix .. "_constant",
    text = tostring(condition.constant or 0), numeric = true, allow_decimal = false,
    allow_negative = true})
  constant.style.width = 72
end

local function add_circuit_output(parent, output, record)
  local enabled_name, signal_name, stem = output[1], output[2], output[3]
  local row = parent.add({type = "flow", name = enabled_name .. "_row", direction = "horizontal"})
  row.style.vertical_align = "center"
  local checkbox = row.add({type = "checkbox", name = enabled_name, caption = {"bte-warp-drive." .. stem},
    tooltip = {"bte-warp-drive." .. stem .. "-tooltip"}, state = record[OUTPUT_TOGGLE_FIELDS[enabled_name]] == true})
  checkbox.style.width = CIRCUIT_PANEL_WIDTH - 68
  local field = OUTPUT_SIGNAL_FIELDS[signal_name]
  row.add({type = "choose-elem-button", name = signal_name, elem_type = "signal",
    signal = record[field[1]] or field[2]})
end

-- A tab page: a scrolling status column on the left and a framed column on the right.
local function add_page(tabs, key)
  local tab = tabs.add({type = "tab", name = "bte_warp_drive_tab_" .. key, caption = ""})
  local page = tabs.add({type = "flow", name = "bte_warp_drive_" .. key .. "_page", direction = "horizontal"})
  page.style.horizontal_spacing = PAGE_GAP
  tabs.add_tab(tab, page)
  local scroll = page.add({type = "scroll-pane", name = "bte_warp_drive_" .. key .. "_scroll",
    direction = "vertical", style = "scroll_pane_in_shallow_frame"})
  scroll.style.width = LEFT_WIDTH
  scroll.style.vertically_stretchable = true
  scroll.horizontal_scroll_policy = "never"
  local left = scroll.add({type = "flow", name = "bte_warp_drive_" .. key .. "_left", direction = "vertical"})
  left.style.padding = 12
  left.style.vertical_spacing = 2
  local right = page.add({type = "frame", name = "bte_warp_drive_" .. key .. "_right",
    direction = "vertical", style = "inside_shallow_frame_with_padding"})
  right.style.width = CIRCUIT_PANEL_WIDTH
  right.style.vertically_stretchable = true
  return left, right
end

local function page_height(player)
  local available = player.display_resolution.height / player.display_scale - PAGE_HEIGHT_RESERVED
  return math.max(PAGE_HEIGHT_MIN, math.min(PAGE_HEIGHT_MAX, available))
end

local function update_gui_height(player)
  local frame = player.gui.screen[GUI_NAME]
  local tabs = frame and frame.bte_warp_drive_tabs
  if tabs then
    for _, key in ipairs(TABS) do
      local page = tabs["bte_warp_drive_" .. key .. "_page"]
      if page then
        page.style.height = page_height(player)
      end
    end
  end
end

local function remembered_tab(player, practical)
  local tabs = storage.gui_tabs
  return tabs and tabs[player.index] or (practical and "warp" or "detector")
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
  frame.tags = {platform_index = record.platform_index, layout_version = LAYOUT_VERSION}
  frame.auto_center = true
  local title = frame.add({type = "flow", name = "bte_warp_drive_title", direction = "horizontal"})
  title.style.vertical_align = "center"
  title.drag_target = frame
  title.add({type = "sprite", sprite = TITLE_SPRITE})
  local title_label = title.add({type = "label", caption = {"bte-warp-drive.title"}, style = "frame_title"})
  title_label.style.left_margin = 8
  title_label.ignored_by_interaction = true
  local spacer = title.add({type = "empty-widget", style = "draggable_space_header"})
  spacer.style.horizontally_stretchable = true
  spacer.style.height = 24
  spacer.drag_target = frame
  title.add({type = "sprite-button", name = GUI_CLOSE, sprite = "utility/close", style = "frame_action_button"})

  -- Header: what the drive is doing and the two main buttons, the same on every tab.
  local header_frame = frame.add({type = "frame", name = "bte_warp_drive_header",
    direction = "horizontal", style = "inside_shallow_frame_with_padding"})
  header_frame.style.width = PAGE_WIDTH + 24
  local header = header_frame.add({type = "flow", direction = "horizontal"})
  header.style.horizontal_spacing = HEADER_GAP
  local preview_frame = header.add({type = "frame", style = "deep_frame_in_shallow_frame"})
  local position = record.entity.position
  local preview = preview_frame.add({type = "camera", name = "bte_warp_drive_preview",
    position = {position.x, position.y + PREVIEW_OFFSET_Y},
    surface_index = record.entity.surface.index, zoom = PREVIEW_ZOOM})
  preview.style.size = PREVIEW_SIZE
  local main = header.add({type = "flow", name = "bte_warp_drive_header_main", direction = "vertical"})
  main.style.width = HEADER_MAIN_WIDTH
  main.style.height = PREVIEW_SIZE
  main.style.vertical_spacing = 2
  local status_line = main.add({type = "flow", name = "bte_warp_drive_status_line", direction = "horizontal"})
  status_line.style.vertical_align = "center"
  status_line.style.horizontal_spacing = 8
  local icon = status_line.add({type = "sprite", name = "bte_warp_drive_status_icon", sprite = STATUS_ICONS.off})
  icon.style.size = 20
  icon.style.stretch_image_to_widget_size = true
  local text = status_line.add({type = "label", name = "bte_warp_drive_status_text", style = "bold_label"})
  text.style.font = "default-large-bold"
  local detail = main.add({type = "label", name = "bte_warp_drive_status_detail", caption = ""})
  detail.style.single_line = false
  detail.style.width = HEADER_MAIN_WIDTH
  local progress = main.add({type = "progressbar", name = "bte_warp_drive_status_progress", value = 0,
    style = "production_progressbar"})
  progress.style.width = HEADER_MAIN_WIDTH
  local route = main.add({type = "label", name = "bte_warp_drive_route", caption = ""})
  route.style.single_line = false
  route.style.width = HEADER_MAIN_WIDTH
  local filler = main.add({type = "empty-widget"})
  filler.style.vertically_stretchable = true
  local controls = main.add({type = "flow", name = "bte_warp_drive_controls", direction = "horizontal"})
  controls.style.horizontal_spacing = CONTROL_BUTTON_GAP
  add_button(controls, GUI_ENGAGE, "green_button", CONTROL_BUTTON_WIDTH, CONTROL_BUTTON_HEIGHT, "default-large-bold")
  add_button(controls, GUI_DISENGAGE, "red_button", CONTROL_BUTTON_WIDTH, CONTROL_BUTTON_HEIGHT, "default-large-bold")

  local tabs = frame.add({type = "tabbed-pane", name = GUI_TABS})
  tabs.style.top_margin = 8

  -- Warp tab: entry requirements and the warp field on the left, engage and disengage conditions
  -- on the right. Before Practical research it only explains how warp unlocks.
  local warp, warp_circuit = add_page(tabs, "warp")
  local locked = warp.add({type = "label", name = "bte_warp_drive_warp_locked",
    caption = {"bte-warp-drive.mode-experimental-help"}})
  locked.style.single_line = false
  locked.style.width = LEFT_WIDTH - 24
  local requirements = warp.add({type = "flow", name = "bte_warp_drive_requirements", direction = "vertical"})
  add_heading(requirements, "bte_warp_drive_requirements_heading", {"bte-warp-drive.requirements-section"})
  add_requirement(requirements, "bte_warp_drive_requirement_travel", {"bte-warp-drive.requirement-travel-label"})
  add_requirement(requirements, "bte_warp_drive_requirement_clearance", {"bte-warp-drive.requirement-clearance-label"})
  add_requirement(requirements, "bte_warp_drive_requirement_cooldown", {"bte-warp-drive.requirement-cooldown-label"})
  add_requirement(requirements, "bte_warp_drive_requirement_speed", {"bte-warp-drive.requirement-speed-label"})
  local field = warp.add({type = "flow", name = "bte_warp_drive_field", direction = "vertical"})
  field.add({type = "line"}).style.top_margin = 6
  add_heading(field, "bte_warp_drive_field_heading", {"bte-warp-drive.field-section"})
  add_status_row(field, "bte_warp_drive_reserve", {"bte-warp-drive.requirement-charge-label"})
  add_status_row(field, "bte_warp_drive_reserve_detail", "")
  add_status_row(field, "bte_warp_drive_charge_eta", {"bte-warp-drive.field-charge-eta-label"})
  add_status_row(field, "bte_warp_drive_warp_level", {"bte-warp-drive.field-warp-level-label"})
  add_requirement(field, "bte_warp_drive_requirement_power", {"bte-warp-drive.requirement-power-label"})
  add_requirement(field, "bte_warp_drive_requirement_acceleration", {"bte-warp-drive.requirement-acceleration-label"})
  local field_idle = warp.add({type = "label", name = "bte_warp_drive_field_idle", caption = {"bte-warp-drive.field-idle"}})
  field_idle.style.single_line = false
  field_idle.style.width = LEFT_WIDTH - 24
  field_idle.style.top_margin = 8
  field_idle.style.font_color = {0.6, 0.6, 0.6}
  add_heading(warp_circuit, "bte_warp_drive_warp_circuit_heading", {"bte-warp-drive.circuit-control"})
  add_condition_editor(warp_circuit, "activate", record.activate)
  add_condition_editor(warp_circuit, "deactivate", record.deactivate)
  local warp_circuit_locked = warp_circuit.add({type = "label", name = "bte_warp_drive_warp_circuit_locked",
    caption = {"bte-warp-drive.circuit-control-locked"}})
  warp_circuit_locked.style.single_line = false
  warp_circuit_locked.style.width = CIRCUIT_PANEL_WIDTH - 24

  -- Detector tab: the tachyon detector, as research acceleration before Practical research and
  -- as the Tachyon Science Boost after it, with its start and stop conditions on the right.
  local detector, detector_circuit = add_page(tabs, "detector")
  local boost_controls = detector.add({type = "flow", name = "bte_warp_drive_boost_controls", direction = "horizontal"})
  boost_controls.style.horizontal_spacing = CONTROL_BUTTON_GAP
  boost_controls.style.bottom_margin = 4
  add_button(boost_controls, GUI_BOOST_START, "green_button", BOOST_BUTTON_WIDTH, BOOST_BUTTON_HEIGHT, "default-bold")
  add_button(boost_controls, GUI_BOOST_STOP, "red_button", BOOST_BUTTON_WIDTH, BOOST_BUTTON_HEIGHT, "default-bold")
  add_heading(detector, "bte_warp_drive_detector_heading", "")
  add_status_row(detector, "bte_warp_drive_detector_status", {"bte-warp-drive.detector-status"})
  add_status_row(detector, "bte_warp_drive_detector_power", {"bte-warp-drive.detector-power"})
  add_bar(detector, "bte_warp_drive_detector_bar")
  add_status_row(detector, "bte_warp_drive_signal_multiplier", {"bte-warp-drive.signal-multiplier"})
  local signal = detector.add({type = "flow", name = "bte_warp_drive_signal_section", direction = "vertical"})
  add_status_row(signal, "bte_warp_drive_detector_speed", {"bte-warp-drive.detector-speed"})
  add_status_row(signal, "bte_warp_drive_detector_power_multiplier", {"bte-warp-drive.detector-power-signal"})
  add_status_row(signal, "bte_warp_drive_tachyon_rate", {"bte-warp-drive.tachyon-rate"})
  detector.add({type = "line"}).style.top_margin = 6
  add_heading(detector, "bte_warp_drive_research_heading", "")
  add_status_row(detector, "bte_warp_drive_research_status", {"bte-warp-drive.research-status"})
  add_status_row(detector, "bte_warp_drive_research_branch", {"bte-warp-drive.research-branch"})
  add_status_row(detector, "bte_warp_drive_working_labs", {"bte-warp-drive.working-labs"})
  add_status_row(detector, "bte_warp_drive_average_lab_rate", {"bte-warp-drive.average-lab-rate"})
  add_status_row(detector, "bte_warp_drive_research_bonus", {"bte-warp-drive.research-bonus"})
  add_status_row(detector, "bte_warp_drive_research_progress", {"bte-warp-drive.research-progress"})
  add_status_row(detector, "bte_warp_drive_research_estimate", {"bte-warp-drive.research-estimate"})
  add_heading(detector_circuit, "bte_warp_drive_detector_circuit_heading", {"bte-warp-drive.circuit-control"})
  add_condition_editor(detector_circuit, "detector_start", record.detector_start)
  add_condition_editor(detector_circuit, "detector_stop", record.detector_stop)

  -- Signals tab: wire connections on the left, readable outputs on the right.
  local signals, outputs = add_page(tabs, "signals")
  add_heading(signals, "bte_warp_drive_networks_heading", {"bte-warp-drive.circuit-panel"})
  for _, color in ipairs({"red", "green"}) do
    local label = signals.add({type = "label", name = "bte_warp_drive_circuit_" .. color .. "_network", caption = ""})
    label.style.single_line = false
    label.style.width = LEFT_WIDTH - 24
  end
  local hint = signals.add({type = "label", caption = {"bte-warp-drive.circuit-wiring-hint"}})
  hint.style.single_line = false
  hint.style.width = LEFT_WIDTH - 24
  hint.style.top_margin = 8
  hint.style.font_color = {0.6, 0.6, 0.6}
  add_heading(outputs, "bte_warp_drive_outputs_heading", {"bte-warp-drive.circuit-outputs"})
  for _, output in ipairs(OUTPUTS) do
    add_circuit_output(outputs, output, record)
  end

  player.opened = frame
  local snapshot = snapshot_callback and snapshot_callback(record)
  tabs.selected_tab_index = TAB_INDEX[remembered_tab(player, snapshot and snapshot.practical)] or 1
  update_gui_height(player)
  update_gui(player, record)
end

-- GUI trees survive save/load and mod updates. Index the window by element name and reject stale
-- or incomplete layouts, so refresh redraws them instead of indexing elements the current code did
-- not create.
local REQUIRED_ELEMENTS = {
  "bte_warp_drive_preview", "bte_warp_drive_status_icon", "bte_warp_drive_status_text",
  "bte_warp_drive_status_detail", "bte_warp_drive_status_progress", "bte_warp_drive_route",
  GUI_ENGAGE, GUI_DISENGAGE, GUI_TABS, GUI_BOOST_START, GUI_BOOST_STOP,
  "bte_warp_drive_tab_warp", "bte_warp_drive_tab_detector", "bte_warp_drive_tab_signals",
  "bte_warp_drive_warp_locked", "bte_warp_drive_requirements", "bte_warp_drive_field",
  "bte_warp_drive_field_idle", "bte_warp_drive_reserve", "bte_warp_drive_reserve_detail",
  "bte_warp_drive_reserve_detail_label", "bte_warp_drive_charge_eta", "bte_warp_drive_warp_level",
  "bte_warp_drive_warp_right", "bte_warp_drive_warp_circuit_locked", "bte_warp_drive_boost_controls",
  "bte_warp_drive_detector_heading", "bte_warp_drive_detector_status", "bte_warp_drive_detector_power",
  "bte_warp_drive_detector_bar", "bte_warp_drive_signal_multiplier", "bte_warp_drive_signal_section",
  "bte_warp_drive_detector_speed", "bte_warp_drive_detector_power_multiplier",
  "bte_warp_drive_tachyon_rate", "bte_warp_drive_research_heading", "bte_warp_drive_research_status",
  "bte_warp_drive_research_branch", "bte_warp_drive_research_branch_label",
  "bte_warp_drive_working_labs", "bte_warp_drive_average_lab_rate",
  "bte_warp_drive_research_bonus", "bte_warp_drive_research_progress",
  "bte_warp_drive_research_estimate", "bte_warp_drive_circuit_red_network",
  "bte_warp_drive_circuit_green_network"
}
for _, name in ipairs({"travel", "clearance", "cooldown", "speed", "power", "acceleration"}) do
  local requirement = "bte_warp_drive_requirement_" .. name
  for _, suffix in ipairs({"", "_row", "_icon", "_label"}) do
    REQUIRED_ELEMENTS[#REQUIRED_ELEMENTS + 1] = requirement .. suffix
  end
end
for _, key in ipairs(CONDITION_KEYS) do
  for _, part in ipairs({"_header", "_enabled", "_state", "_editor", "_first_signal", "_comparator",
      "_second_signal", "_constant"}) do
    REQUIRED_ELEMENTS[#REQUIRED_ELEMENTS + 1] = "bte_warp_drive_" .. key .. part
  end
end
for _, output in ipairs(OUTPUTS) do
  REQUIRED_ELEMENTS[#REQUIRED_ELEMENTS + 1] = output[1] .. "_row"
  REQUIRED_ELEMENTS[#REQUIRED_ELEMENTS + 1] = output[1]
  REQUIRED_ELEMENTS[#REQUIRED_ELEMENTS + 1] = output[2]
end

local function index_elements(element, view)
  if element.name ~= "" then
    view[element.name] = element
  end
  for _, child in pairs(element.children) do
    index_elements(child, view)
  end
end

local function view_from_frame(frame)
  if not frame or frame.tags.layout_version ~= LAYOUT_VERSION then
    return nil
  end
  local view = {}
  index_elements(frame, view)
  for _, name in ipairs(REQUIRED_ELEMENTS) do
    if not view[name] then
      return nil
    end
  end
  return view
end

-- Rendering.

local function set_row_visible(view, name, visible)
  view[name .. "_row"].visible = visible
end

local function set_status(view, name, caption)
  view[name].caption = caption
end

local function requirement(view, name, state, caption)
  local selected = REQUIREMENT_PRESENTATION[state]
  view[name .. "_icon"].sprite = selected[1]
  -- Assigning a style resets the element's custom size, so the column widths are reapplied.
  local label = view[name .. "_label"]
  label.style = selected[2]
  label.style.width = STATUS_LABEL_WIDTH - 22
  label.style.single_line = false
  local value = view[name]
  value.caption = caption
  value.style = selected[3]
  value.style.width = STATUS_VALUE_WIDTH
  value.style.single_line = false
end

local function render_button(button, key, blocker)
  button.caption = {"bte-warp-drive." .. key}
  button.enabled = blocker == nil
  button.tooltip = {"bte-warp-drive." .. key .. "-" .. (blocker and "blocked-" .. blocker or "tooltip")}
end

-- The last deactivation reason, or `fallback` (default empty) before the drive's first exit.
local function last_reason(record, fallback)
  if not record.last_exit_reason then
    return fallback or ""
  end
  return {"bte-warp-drive.last-deactivation-reason",
    {"bte-warp-drive.deactivation-reason-" .. record.last_exit_reason}}
end

-- The header's headline, detail line, and progress bar for the drive's current state.
local function header_status(record, snapshot)
  if not snapshot.practical then
    local power = record.detector_power or 0
    local tone = not record.detector_on and "off"
      or ((record.detector_power_ratio or 0) > 0.01 and "good" or "warning")
    local text = not record.detector_on and "header-detector-off"
      or (tone == "good" and "header-detecting" or "header-detector-no-power")
    return tone, {"bte-warp-drive." .. text}, {"bte-warp-drive.header-warp-locked"},
      math.min(1, power / DETECTOR_MAX_POWER_WATTS),
      {"bte-warp-drive.power-value", format_power(power), format_power(DETECTOR_MAX_POWER_WATTS),
        math.floor(power / DETECTOR_MAX_POWER_WATTS * 100)}
  end
  if record.warp_warning == "power" then
    return "danger", {"bte-warp-drive.header-reserve-draining"}, {"bte-warp-drive.warning-power"},
      snapshot.charge_ratio, {"bte-warp-drive.percent-value", math.floor(snapshot.charge_ratio * 100)}
  elseif record.state == "warp" then
    local detail = record.speed_exit_at
      and {"bte-warp-drive.requirement-speed-warning", string.format("%.1f", snapshot.speed),
        string.format("%.1f", math.max(0, record.speed_exit_at - game.tick) / TICKS_PER_SECOND)}
      or {"bte-warp-drive.header-warp-detail", string.format("%.2f", snapshot.warp_boost),
        format_km(snapshot.effective_speed)}
    return record.speed_exit_at and "warning" or "good",
      {"bte-warp-drive.active-warp-level", string.format("%.1f", record.warp_level or 1)}, detail
  elseif record.state == "charging" then
    return "warning", {"bte-warp-drive.charging-status"},
      {"bte-warp-drive.charging-remaining",
        format_energy(math.max(0, snapshot.required_charge - snapshot.stored_charge))},
      snapshot.charge_ratio, {"bte-warp-drive.percent-value", math.floor(snapshot.charge_ratio * 100)}
  end
  local blocker = snapshot.engage_blocker
  if not blocker then
    local detail = record.activate.enabled and snapshot.activate_active
      and {"bte-warp-drive.header-engaging-by-condition"}
      or last_reason(record, {"bte-warp-drive.header-ready-hint"})
    return "good", {"bte-warp-drive.header-ready"}, detail
  elseif blocker == "cooldown" then
    return "warning", {"bte-warp-drive.header-lockout", math.ceil(snapshot.cooldown_seconds)},
      last_reason(record)
  elseif blocker == "speed" then
    return "bad", {"bte-warp-drive.header-blocked-speed", string.format("%.1f", snapshot.speed)},
      last_reason(record)
  elseif blocker == "clearance" and snapshot.closest_endpoint then
    return "bad", {"bte-warp-drive.header-blocked-clearance",
      format_km(snapshot.endpoint_distance_km), location_label(snapshot.closest_endpoint)},
      last_reason(record)
  end
  return "bad", {"bte-warp-drive.header-blocked-" .. blocker}, last_reason(record)
end

local function render_header(view, record, snapshot)
  local tone, text, detail, progress, progress_caption = header_status(record, snapshot)
  view.bte_warp_drive_status_icon.sprite = STATUS_ICONS[tone]
  view.bte_warp_drive_status_text.caption = text
  view.bte_warp_drive_status_text.style = STATUS_STYLES[tone]
  view.bte_warp_drive_status_text.style.font = "default-large-bold"
  view.bte_warp_drive_status_detail.caption = detail
  view.bte_warp_drive_status_progress.visible = progress ~= nil
  if progress then
    view.bte_warp_drive_status_progress.value = progress
    view.bte_warp_drive_status_progress.caption = progress_caption
  end
  local route = view.bte_warp_drive_route
  if snapshot.location then
    route.caption = {"bte-warp-drive.location-parked", location_label(snapshot.location)}
  elseif snapshot.route_from then
    route.caption = {"bte-warp-drive.location-transit-distance", location_label(snapshot.route_from),
      location_label(snapshot.route_to), format_km(snapshot.remaining_km)}
  else
    route.caption = {"bte-warp-drive.location-unknown"}
  end
  local practical = snapshot.practical
  render_button(view[GUI_ENGAGE], practical and "engage" or "start-detector", snapshot.engage_blocker)
  render_button(view[GUI_DISENGAGE], practical and "disengage" or "stop-detector",
    snapshot.disengage_blocker)
  view.bte_warp_drive_tab_warp.caption = {"bte-warp-drive.tab-warp"}
  view.bte_warp_drive_tab_detector.caption = {"bte-warp-drive." .. (practical and "tab-boost" or "tab-detector")}
  view.bte_warp_drive_tab_signals.caption = {"bte-warp-drive.tab-signals"}
end

local function render_warp(view, record, snapshot)
  local practical = snapshot.practical
  local engaged = record.state == "warp" or record.state == "charging"
  view.bte_warp_drive_warp_locked.visible = not practical
  view.bte_warp_drive_requirements.visible = practical
  view.bte_warp_drive_field.visible = practical and engaged
  view.bte_warp_drive_field_idle.visible = practical and not engaged
  if not practical then
    return
  end
  requirement(view, "bte_warp_drive_requirement_travel",
    snapshot.travel_active and snapshot.destination and "pass" or "fail",
    snapshot.destination and location_label(snapshot.destination)
      or {"bte-warp-drive.requirement-travel-inactive"})
  requirement(view, "bte_warp_drive_requirement_clearance", snapshot.clearance and "pass" or "fail",
    snapshot.clearance and {"bte-warp-drive.requirement-clearance-clear"}
      or (snapshot.closest_endpoint and snapshot.endpoint_blocked
        and {"bte-warp-drive.requirement-clearance-blocked",
          format_km(snapshot.endpoint_distance_km), location_label(snapshot.closest_endpoint)}
        or {"bte-warp-drive.requirement-clearance-unavailable"}))
  requirement(view, "bte_warp_drive_requirement_cooldown", snapshot.cooldown_ready and "pass" or "fail",
    snapshot.cooldown_ready and {"bte-warp-drive.requirement-cooldown-ready"}
      or {"bte-warp-drive.requirement-cooldown-waiting", math.ceil(snapshot.cooldown_seconds)})
  local speed_state = snapshot.speed_ready and "pass"
    or (record.state == "warp" and record.speed_exit_at and "warning" or "fail")
  requirement(view, "bte_warp_drive_requirement_speed", speed_state, speed_state == "warning"
    and {"bte-warp-drive.requirement-speed-warning", string.format("%.1f", snapshot.speed),
      string.format("%.1f", math.max(0, record.speed_exit_at - game.tick) / TICKS_PER_SECOND)}
    or {"bte-warp-drive.requirement-speed-value", string.format("%.1f", snapshot.speed)})
  if not engaged then
    return
  end
  -- The header already shows the headline (charge percentage, energy still needed, or warp level,
  -- boost and speed); these rows add the figures behind it.
  local charging = record.state == "charging"
  local delivered = record.support_power or 0
  set_status(view, "bte_warp_drive_reserve", {"bte-warp-drive.charge-value",
    format_energy(snapshot.stored_charge), format_energy(snapshot.required_charge),
    math.floor(snapshot.charge_ratio * 100)})
  if charging then
    view.bte_warp_drive_reserve_detail_label.caption = {"bte-warp-drive.field-reserve-size-label"}
    set_status(view, "bte_warp_drive_reserve_detail", {"bte-warp-drive.field-reserve-size",
      format_km(snapshot.mass_kg / 1000)})
  else
    view.bte_warp_drive_reserve_detail_label.caption = {"bte-warp-drive.field-outage-label"}
    set_status(view, "bte_warp_drive_reserve_detail", {"bte-warp-drive.field-outage",
      string.format("%.1f", snapshot.outage_seconds)})
  end
  set_row_visible(view, "bte_warp_drive_charge_eta", charging)
  if charging then
    local missing = math.max(0, snapshot.required_charge - snapshot.stored_charge)
    set_status(view, "bte_warp_drive_charge_eta", delivered > 0
      and format_duration(missing / delivered) or {"bte-warp-drive.field-charge-eta-waiting"})
  end
  set_row_visible(view, "bte_warp_drive_warp_level", not charging)
  if not charging then
    set_status(view, "bte_warp_drive_warp_level", {"bte-warp-drive.field-warp-level",
      string.format("%.2f", record.warp_level or 1), string.format("%.2f", record.warp_target or 0),
      string.format("%.2f", snapshot.engine_level_limit)})
  end
  requirement(view, "bte_warp_drive_requirement_power",
    (charging or record.warp_ramp_state == "stabilizing") and "warning"
      or (snapshot.power_ready and "pass" or "fail"),
    charging and {"bte-warp-drive.field-power-charging", format_power(delivered),
      format_power(snapshot.demand_watts)}
      or {"bte-warp-drive.field-power", format_power(delivered), format_power(snapshot.demand_watts),
        format_power(snapshot.support_required)})
  local ramp_state = record.warp_ramp_state or "inactive"
  set_row_visible(view, "bte_warp_drive_requirement_acceleration", record.state == "warp")
  requirement(view, "bte_warp_drive_requirement_acceleration",
    ramp_state == "accelerating" and "pass" or (ramp_state == "reserve" and "fail" or "warning"),
    {"bte-warp-drive.ramp-" .. ramp_state})
end

local function detector_help(snapshot, research_snapshot)
  if snapshot.practical then
    return {"bte-warp-drive.boost-help"}
  end
  local best = research_snapshot.deepest_location
  local best_name = best and location_label(best) or {"bte-warp-drive.location-unknown"}
  return {"bte-warp-drive.detector-help-" .. (research_snapshot.branch or "unknown"),
    {"", "[font=default-bold]", best_name, "[/font]"},
    string.format("%.0f", research_snapshot.maximum_density)}
end

local function render_detector(view, record, snapshot, research_snapshot)
  local practical = snapshot.practical
  view.bte_warp_drive_boost_controls.visible = practical
  if practical then
    render_button(view[GUI_BOOST_START], "boost-start", snapshot.detector_start_blocker)
    render_button(view[GUI_BOOST_STOP], "boost-stop", snapshot.detector_stop_blocker)
  end
  local help = detector_help(snapshot, research_snapshot)
  view.bte_warp_drive_detector_heading.caption = {"", {"bte-warp-drive.detector-section"}, " [img=info]"}
  view.bte_warp_drive_detector_heading.tooltip = help
  local power = record.detector_power or 0
  local state
  if practical then
    state = not record.detector_on and "boost-status-stopped"
      or (snapshot.detector_paused and "boost-status-paused"
        or ((record.detector_power_ratio or 0) > 0.01 and "boost-status-active" or "boost-status-offline"))
  else
    state = record.detector_on and "state-" .. record.state or "boost-status-stopped"
  end
  set_status(view, "bte_warp_drive_detector_status", {"bte-warp-drive." .. state})
  set_status(view, "bte_warp_drive_detector_power", {"bte-warp-drive.power-value", format_power(power),
    format_power(DETECTOR_MAX_POWER_WATTS), math.floor(power / DETECTOR_MAX_POWER_WATTS * 100)})
  local fraction = math.min(1, power / DETECTOR_MAX_POWER_WATTS)
  view.bte_warp_drive_detector_bar.value = fraction
  view.bte_warp_drive_detector_bar.caption = {"bte-warp-drive.percent-value", math.floor(fraction * 100)}
  set_status(view, "bte_warp_drive_signal_multiplier", {"bte-warp-drive.boost-density-value",
    string.format("%.1f", research_snapshot.density), format_km(research_snapshot.maximum_density)})
  view.bte_warp_drive_signal_section.visible = not practical
  set_status(view, "bte_warp_drive_detector_speed", {"bte-warp-drive.detector-speed-value",
    string.format("%.2f", research_snapshot.detector_speed),
    string.format("%.2f", research_snapshot.detector_speed_factor)})
  set_status(view, "bte_warp_drive_detector_power_multiplier", {"bte-warp-drive.multiplier-value",
    string.format("%.2f", research_snapshot.power_ratio)})
  set_status(view, "bte_warp_drive_tachyon_rate", {"bte-warp-drive.tachyon-value",
    string.format("%.2f", research_snapshot.detector_signal)})

  view.bte_warp_drive_research_heading.caption = {"", {"bte-warp-drive."
    .. (practical and "boost-section" or "research-section")}, " [img=info]"}
  view.bte_warp_drive_research_heading.tooltip = help
  local research = research_snapshot.research
  local researching_practical = research_snapshot.researching_practical
  if practical then
    view.bte_warp_drive_research_status_label.caption = {"bte-warp-drive.boost-value-label"}
    local boost = research_snapshot.science_boost
    set_status(view, "bte_warp_drive_research_status", {"bte-warp-drive.boost-value",
      string.format("%.1f", boost * 100), string.format("%.2f", 1 + boost)})
    view.bte_warp_drive_research_progress_label.caption = {"bte-warp-drive.boost-research-label"}
    set_status(view, "bte_warp_drive_research_progress", research
      and {"", "[technology=" .. research.name .. "] ", research.localised_name}
      or {"bte-warp-drive.boost-research-none"})
  else
    view.bte_warp_drive_research_status_label.caption = {"bte-warp-drive.research-status"}
    set_status(view, "bte_warp_drive_research_status", researching_practical
      and {"bte-warp-drive.research-status-active"} or {"bte-warp-drive.research-status-inactive"})
    view.bte_warp_drive_research_progress_label.caption = {"bte-warp-drive.research-progress"}
    set_status(view, "bte_warp_drive_research_progress", {"bte-warp-drive.percent-value",
      string.format("%.6f", research_snapshot.progress * 100)})
  end
  set_row_visible(view, "bte_warp_drive_research_progress", practical or researching_practical)
  if practical then
    -- Every boost reaches all of the force's laboratories, so this row shows what all drives
    -- add together instead of where this one's observations go.
    local combined = research_snapshot.combined_science_boost
    view.bte_warp_drive_research_branch_label.caption = {"bte-warp-drive.boost-combined-label"}
    set_status(view, "bte_warp_drive_research_branch", {"bte-warp-drive.boost-value",
      string.format("%.1f", combined * 100), string.format("%.2f", 1 + combined)})
  else
    view.bte_warp_drive_research_branch_label.caption = {"bte-warp-drive.research-branch"}
    set_status(view, "bte_warp_drive_research_branch", {"bte-warp-drive.branch-"
      .. (research_snapshot.branch or "unknown")})
  end
  set_status(view, "bte_warp_drive_working_labs", bold_number(research_snapshot.lab_count))
  set_row_visible(view, "bte_warp_drive_average_lab_rate", not practical and researching_practical)
  if not practical and researching_practical then
    set_status(view, "bte_warp_drive_average_lab_rate", {"bte-warp-drive.research-rate-value",
      string.format("%.4f", research_snapshot.average_lab_rate)})
  end
  set_status(view, "bte_warp_drive_research_bonus", {"bte-warp-drive.research-rate-value",
    string.format("%.2f", practical and research_snapshot.science_boost_rate or research_snapshot.bonus_rate)})
  set_row_visible(view, "bte_warp_drive_research_estimate", not practical and researching_practical)
  if not practical and researching_practical then
    set_status(view, "bte_warp_drive_research_estimate", research_snapshot.total_rate > 0
      and {"bte-warp-drive.estimate-value",
        format_duration(research_snapshot.remaining_units / research_snapshot.total_rate),
        string.format("%.2f", research_snapshot.total_rate)}
      or {"bte-warp-drive.estimate-unavailable"})
  end
end

local function render_condition(view, key, condition, active, practical)
  local prefix = "bte_warp_drive_" .. key
  local visible = practical or not WARP_CONDITIONS[key]
  local locale = condition_locale(key, practical)
  view[prefix .. "_header"].visible = visible
  view[prefix .. "_editor"].visible = visible
  local checkbox = view[prefix .. "_enabled"]
  checkbox.state = condition.enabled
  checkbox.caption = {locale}
  checkbox.tooltip = {locale .. "-tooltip"}
  local state = view[prefix .. "_state"]
  local lit = condition.enabled and active
  state.sprite = lit and STATUS_ICONS.good or STATUS_ICONS.off
  state.tooltip = {"bte-warp-drive.condition-" .. (not condition.enabled and "disabled"
    or (lit and "true" or "false"))}
  local first = view[prefix .. "_first_signal"]
  local comparator = view[prefix .. "_comparator"]
  local second = view[prefix .. "_second_signal"]
  local constant = view[prefix .. "_constant"]
  first.elem_value = condition.first_signal
  comparator.selected_index = CIRCUIT_COMPARATOR_INDEX[condition.comparator] or 1
  second.elem_value = condition.second_signal
  constant.visible = condition.second_signal == nil
  for _, element in pairs({first, comparator, second, constant}) do
    element.enabled = condition.enabled
  end
end

local function render_circuit(view, record, snapshot)
  local practical = snapshot.practical
  render_condition(view, "activate", record.activate, snapshot.activate_active, practical)
  render_condition(view, "deactivate", record.deactivate, snapshot.deactivate_active, practical)
  render_condition(view, "detector_start", record.detector_start, snapshot.detector_start_active, practical)
  render_condition(view, "detector_stop", record.detector_stop, snapshot.detector_stop_active, practical)
  view.bte_warp_drive_warp_circuit_locked.visible = not practical
  for _, output in ipairs(OUTPUTS) do
    local enabled_name, signal_name, mode = output[1], output[2], output[4]
    local field = OUTPUT_SIGNAL_FIELDS[signal_name]
    local enabled = record[OUTPUT_TOGGLE_FIELDS[enabled_name]] == true
    view[enabled_name .. "_row"].visible = mode == "both" or practical
    view[enabled_name].state = enabled
    view[signal_name].elem_value = record[field[1]] or field[2]
    view[signal_name].enabled = enabled
  end
  update_circuit_network_row(view.bte_warp_drive_circuit_red_network, record, "red",
    defines.wire_connector_id.circuit_red)
  update_circuit_network_row(view.bte_warp_drive_circuit_green_network, record, "green",
    defines.wire_connector_id.circuit_green)
end

-- `fast` refreshes run every 10-tick drive update while charging or in warp. They skip the
-- detector tab, whose research figures scan every laboratory the force owns; the regular
-- once-a-second refresh keeps that tab current.
update_gui = function(player, record, fast)
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
  local research_snapshot = not fast and Research.snapshot(record)
  if not snapshot or not (fast or research_snapshot) then
    frame.destroy()
    return
  end
  render_header(view, record, snapshot)
  render_warp(view, record, snapshot)
  if not fast then
    render_detector(view, record, snapshot, research_snapshot)
  end
  render_circuit(view, record, snapshot)
end

--- Refreshes every open drive window. With `fast`, only windows of drives that are charging or
-- in warp are refreshed, without their research figures; see update_gui.
function Gui.refresh_open_windows(fast)
  for _, player in pairs(game.connected_players) do
    local frame = player.gui.screen[GUI_NAME]
    if frame then
      local record = Drive.get(frame.tags.platform_index)
      if not record then
        frame.destroy()
      elseif not fast or record.state == "charging" or record.state == "warp" then
        update_gui(player, record, fast)
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

local function refresh(player_index, record)
  if snapshot_callback then
    update_gui(game.get_player(player_index), record)
  end
end

-- The record field an activate or deactivate condition element edits, or nil for other elements.
local function condition_field(record, element, part)
  local field = CONDITION_ELEMENTS[element.name]
  if field and (not part or field.part == part) then
    return record[field.key], field.part
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
  if not element or not element.valid then
    return
  end
  local button = button_callbacks and button_callbacks[element.name]
  if button then
    local record = gui_record(element)
    if record then
      button(record)
      refresh(event.player_index, record)
    end
    return
  end
  if element.name ~= GUI_CLOSE then
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
  local condition = condition_field(record, element, "enabled")
  if output_field then
    record[output_field] = element.state
  elseif condition then
    condition.enabled = element.state
  else
    return
  end
  refresh(event.player_index, record)
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
  local condition, part = condition_field(record, element)
  if output then
    record[output[1]] = element.elem_value or output[2]
    element.elem_value = record[output[1]]
  elseif condition and (part == "first_signal" or part == "second_signal") then
    condition[part] = element.elem_value
  else
    return
  end
  refresh(event.player_index, record)
end

function handlers.on_gui_selection_state_changed(event)
  local element = event.element
  if not element or not element.valid then
    return
  end
  local record = gui_record(element)
  local condition = record and condition_field(record, element, "comparator")
  if condition then
    condition.comparator = CIRCUIT_COMPARATORS[element.selected_index] or ">"
    refresh(event.player_index, record)
  end
end

function handlers.on_gui_text_changed(event)
  local element = event.element
  if not element or not element.valid then
    return
  end
  local record = gui_record(element)
  local condition = record and condition_field(record, element, "constant")
  local value = tonumber(element.text)
  if condition and value then
    condition.constant = math.max(-2147483648, math.min(2147483647, math.floor(value)))
  end
end

function handlers.on_gui_confirmed(event)
  local element = event.element
  if not element or not element.valid then
    return
  end
  local record = gui_record(element)
  local condition = record and condition_field(record, element, "constant")
  if not condition then
    return
  end
  local value = tonumber(element.text)
  condition.constant = value and math.max(-2147483648,
    math.min(2147483647, math.floor(value))) or (condition.constant or 0)
  element.text = tostring(condition.constant)
  refresh(event.player_index, record)
end

function handlers.on_gui_selected_tab_changed(event)
  local element = event.element
  if not element or not element.valid or element.name ~= GUI_TABS then
    return
  end
  storage.gui_tabs = storage.gui_tabs or {}
  storage.gui_tabs[event.player_index] = TABS[element.selected_tab_index]
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
-- Exposed so the runtime tests, which run without a player to open the window, can validate it.
Gui.TITLE_SPRITE = TITLE_SPRITE

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
  script.on_event(defines.events.on_gui_selected_tab_changed, handlers.on_gui_selected_tab_changed)
  script.on_event(defines.events.on_gui_confirmed, handlers.on_gui_confirmed)
  script.on_event(defines.events.on_player_display_resolution_changed,
    handlers.on_display_changed)
  script.on_event(defines.events.on_player_display_scale_changed,
    handlers.on_display_changed)
  script.on_event(defines.events.on_gui_closed, handlers.on_gui_closed)
end

return Gui
