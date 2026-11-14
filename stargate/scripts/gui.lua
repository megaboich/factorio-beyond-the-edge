-- The gate's window, which replaces the assembling machine's own GUI: status, name, partner, the
-- on/off switch, station mode, and the circuit enable condition (the engine's own, edited through the
-- control behaviour). One window per player; storage.open_gui[player_index] is the gate it shows.
-- A gate in station mode opens its station's train stop window instead, with this window attached to
-- its right as a relative GUI.
local Gate = require("scripts.gate")
local Railway = require("scripts.railway")

local Gui = {}

local GATE = "bte-stargate"
local WINDOW = "bte_stargate_window"
local COMPARATORS = {">", "<", "=", "≥", "≤", "≠"}
local STATION = "bte-stargate-station"
-- The station-mode choices, in the drop-down's order; nil is off.
local MODES = {false, "single", "right", "left"}

-- The window, wherever it is shown: on its own, or beside the station's train stop window.
local function window_of(player)
  return player.gui.screen[WINDOW] or player.gui.relative[WINDOW]
end

function Gui.init_storage()
  storage.open_gui = storage.open_gui or {}
end

local function status(record)
  if not record.enabled then
    return {"bte-stargate-gui.status-off"}, "utility/status_not_working"
  end
  if Gate.is_open(record) then
    if Gate.short_of_power(record) then
      return {"bte-stargate-gui.status-draining"}, "utility/status_yellow"
    end
    local partner = Gate.partner(record)
    if record.railway and not (partner and partner.railway) then
      return {"bte-stargate-gui.status-open-no-trains"}, "utility/status_yellow"
    end
    return {partner and "bte-stargate-gui.status-open" or "bte-stargate-gui.status-open-random"}, "utility/status_working"
  end
  if record.open and not Gate.is_open(record) then
    return {"bte-stargate-gui.status-nowhere"}, "utility/status_not_working"
  end
  if not Gate.circuit_allows(record) then
    return {"bte-stargate-gui.status-circuit"}, "utility/status_not_working"
  end
  return {"bte-stargate-gui.status-charging"}, "utility/status_yellow"
end

local function find(element, name)
  if element.name == name then
    return element
  end
  for _, child in pairs(element.children) do
    local found = find(child, name)
    if found then
      return found
    end
  end
end

-- Fills the partner selector: "none" and every other gate of the force, by name.
local function fill_partners(dropdown, record)
  local items, ids, selected = {{"bte-stargate-gui.no-partner"}}, {0}, 1
  for _, other in pairs(Gate.candidates(record)) do
    items[#items + 1] = other.name
    ids[#ids + 1] = other.entity.unit_number
    if other.entity.unit_number == record.partner then
      selected = #ids
    end
  end
  dropdown.items = items
  dropdown.selected_index = selected
  dropdown.tags = {ids = ids}
end

-- Updates the status line. The partner list is filled when the window opens and after a pick, not
-- here, since refilling a drop-down closes it under the player's cursor.
local function refresh(player, record)
  local window = window_of(player)
  if not window then
    return
  end
  -- The name may change in the station's own window.
  local name = find(window, "bte_stargate_name")
  if name.text ~= record.name then
    name.text = record.name
  end
  local caption, sprite = status(record)
  find(window, "bte_stargate_status").caption = caption
  find(window, "bte_stargate_status_light").sprite = sprite
  local charge = Gate.charge(record)
  local bar = find(window, "bte_stargate_charge")
  bar.value = charge
  bar.caption = {"bte-stargate-gui.charge", math.floor(charge * 100 + 0.5)}
end

local function close(player)
  for _, root in pairs({player.gui.screen, player.gui.relative}) do
    if root[WINDOW] then
      root[WINDOW].destroy()
    end
  end
  storage.open_gui[player.index] = nil
end

-- Builds the window; `beside` attaches it to the right of the gate's train stop window.
local function open(player, record, beside)
  close(player)
  local entity = record.entity
  local window
  if beside then
    window = player.gui.relative.add({type = "frame", name = WINDOW, direction = "vertical", anchor = {
      gui = defines.relative_gui_type.train_stop_gui, position = defines.relative_gui_position.right, name = STATION
    }})
  else
    window = player.gui.screen.add({type = "frame", name = WINDOW, direction = "vertical"})
  end
  local titlebar = window.add({type = "flow", direction = "horizontal"})
  if not beside then
    titlebar.drag_target = window
  end
  titlebar.add({type = "label", caption = {"entity-name.bte-stargate"}, style = "frame_title", ignored_by_interaction = true})
  local filler = titlebar.add({type = "empty-widget", style = beside and "empty_widget" or "draggable_space_header",
    ignored_by_interaction = true})
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  titlebar.add({type = "sprite-button", name = "bte_stargate_close", style = "frame_action_button",
    sprite = "utility/close", tooltip = {"gui.close-instruction"}})

  local inner = window.add({type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"})
  local status_row = inner.add({type = "flow", direction = "horizontal"})
  status_row.style.vertical_align = "center"
  status_row.add({type = "sprite", name = "bte_stargate_status_light"})
  status_row.add({type = "label", name = "bte_stargate_status"})
  local bar = inner.add({type = "progressbar", name = "bte_stargate_charge", tooltip = {"bte-stargate-gui.charge-tooltip"}})
  bar.style.horizontally_stretchable = true
  bar.style.bottom_margin = 4
  local preview = inner.add({type = "frame", style = "deep_frame_in_shallow_frame"})
  local camera = preview.add({type = "camera", position = {entity.position.x + 1, entity.position.y + 1},
    surface_index = entity.surface.index, zoom = 0.35})
  camera.style.width = 360
  camera.style.height = 220

  local grid = inner.add({type = "table", column_count = 2})
  grid.style.vertical_spacing = 8
  grid.style.top_margin = 8
  grid.add({type = "label", caption = {"bte-stargate-gui.name"}})
  local name = grid.add({type = "textfield", name = "bte_stargate_name", text = record.name})
  name.style.width = 220
  grid.add({type = "label", caption = {"bte-stargate-gui.partner"}, tooltip = {"bte-stargate-gui.partner-tooltip"}})
  local partner = grid.add({type = "drop-down", name = "bte_stargate_partner"})
  partner.style.width = 220
  grid.add({type = "label", caption = {"bte-stargate-gui.enabled"}})
  grid.add({type = "checkbox", name = "bte_stargate_enabled", state = record.enabled})
  grid.add({type = "label", caption = {"bte-stargate-gui.keep-charged"}, tooltip = {"bte-stargate-gui.keep-charged-tooltip"}})
  grid.add({type = "checkbox", name = "bte_stargate_keep_charged", state = record.keep_charged == true,
    tooltip = {"bte-stargate-gui.keep-charged-tooltip"}})
  grid.add({type = "label", caption = {"bte-stargate-gui.station"}, tooltip = {"bte-stargate-gui.station-tooltip"}})
  local mode = 1
  for index, value in ipairs(MODES) do
    if value == (record.railway or false) then
      mode = index
    end
  end
  local modes = grid.add({type = "drop-down", name = "bte_stargate_station", selected_index = mode,
    tooltip = {"bte-stargate-gui.station-tooltip"}, items = {
      {"bte-stargate-gui.station-off"}, {"bte-stargate-gui.station-single"},
      {"bte-stargate-gui.station-right"}, {"bte-stargate-gui.station-left"}
    }})
  modes.style.width = 220

  local behavior = entity.get_or_create_control_behavior()
  local condition = behavior.circuit_condition or {}
  inner.add({type = "line"}).style.top_margin = 8
  inner.add({type = "checkbox", name = "bte_stargate_circuit", state = behavior.circuit_enable_disable,
    caption = {"bte-stargate-gui.circuit"}, tooltip = {"bte-stargate-gui.circuit-tooltip"}})
  local row = inner.add({type = "flow", name = "bte_stargate_condition", direction = "horizontal"})
  row.style.vertical_align = "center"
  row.add({type = "choose-elem-button", name = "bte_stargate_signal", elem_type = "signal",
    signal = condition.first_signal})
  local comparator = 1
  for index, value in ipairs(COMPARATORS) do
    if value == condition.comparator then
      comparator = index
    end
  end
  local comparators = row.add({type = "drop-down", name = "bte_stargate_comparator", items = COMPARATORS,
    selected_index = comparator, style = "circuit_condition_comparator_dropdown"})
  comparators.style.width = 64
  local constant = row.add({type = "textfield", name = "bte_stargate_constant", text = tostring(condition.constant or 0),
    numeric = true, allow_negative = true})
  constant.style.width = 80
  row.visible = behavior.circuit_enable_disable

  fill_partners(partner, record)
  storage.open_gui[player.index] = entity.unit_number
  if not beside then
    window.force_auto_center()
    player.opened = window
  end
  refresh(player, record)
end

-- Shows the gate: its station's train stop window with this one beside it, or this one alone.
local function show(player, record)
  local station = Railway.station(record)
  if station then
    close(player)
    player.opened = station
    open(player, record, true)
  else
    open(player, record, false)
  end
end

local function shown(player_index)
  local id = storage.open_gui[player_index]
  return id and Gate.get(id)
end

-- Writes the circuit condition from the window's signal, comparator, and constant.
local function write_condition(window, record)
  local behavior = record.entity.get_or_create_control_behavior()
  behavior.circuit_condition = {
    first_signal = find(window, "bte_stargate_signal").elem_value,
    comparator = COMPARATORS[find(window, "bte_stargate_comparator").selected_index] or "<",
    constant = tonumber(find(window, "bte_stargate_constant").text) or 0
  }
end

local function owned(element)
  return element and element.valid and element.get_mod() == "bte-stargate"
end

function Gui.on_opened(event)
  local entity = event.entity
  if not (entity and entity.valid and (entity.name == GATE or entity.name == STATION)) then
    return
  end
  local player = game.get_player(event.player_index)
  if entity.name == STATION then
    -- Opened through the gate (show()), or by a mod or the game directly.
    local record = Railway.gate_of(entity)
    if record and storage.open_gui[player.index] ~= record.entity.unit_number then
      open(player, record, true)
    end
    return
  end
  local record = Gate.get(entity.unit_number)
  if record then
    show(player, record)
  else
    player.opened = nil
  end
end

function Gui.on_closed(event)
  local player = game.get_player(event.player_index)
  if event.element and event.element.valid and event.element.name == WINDOW then
    close(player)
  elseif event.entity and event.entity.valid and event.entity.name == STATION and player.gui.relative[WINDOW] then
    close(player)
  end
end

function Gui.on_click(event)
  if owned(event.element) and event.element.name == "bte_stargate_close" then
    local player = game.get_player(event.player_index)
    close(player)
    player.opened = nil
  end
end

function Gui.on_text_changed(event)
  local element = event.element
  local record = owned(element) and shown(event.player_index)
  if not record then
    return
  end
  if element.name == "bte_stargate_name" then
    Gate.set_name(record, element.text)
  elseif element.name == "bte_stargate_constant" then
    write_condition(window_of(game.get_player(event.player_index)), record)
  end
end

function Gui.on_selection_changed(event)
  local element = event.element
  local record = owned(element) and shown(event.player_index)
  if not record then
    return
  end
  local player = game.get_player(event.player_index)
  if element.name == "bte_stargate_partner" then
    local id = element.tags.ids[element.selected_index]
    Gate.pair(record, id ~= 0 and Gate.get(id) or nil)
    fill_partners(element, record)
    refresh(player, record)
  elseif element.name == "bte_stargate_station" then
    local ok, reason = Railway.set_mode(record, MODES[element.selected_index] or nil)
    if ok then
      show(player, record)
    else
      player.create_local_flying_text({text = reason, create_at_cursor = true})
      player.play_sound({path = "utility/cannot_build"})
      for index, value in ipairs(MODES) do
        if value == (record.railway or false) then
          element.selected_index = index
        end
      end
    end
  elseif element.name == "bte_stargate_comparator" then
    write_condition(window_of(player), record)
  end
end

function Gui.on_elem_changed(event)
  local element = event.element
  local record = owned(element) and shown(event.player_index)
  if record and element.name == "bte_stargate_signal" then
    write_condition(window_of(game.get_player(event.player_index)), record)
  end
end

function Gui.on_checked(event)
  local element = event.element
  local record = owned(element) and shown(event.player_index)
  if not record then
    return
  end
  local player = game.get_player(event.player_index)
  if element.name == "bte_stargate_enabled" then
    Gate.set_enabled(record, element.state)
  elseif element.name == "bte_stargate_keep_charged" then
    Gate.set_keep_charged(record, element.state)
  elseif element.name == "bte_stargate_circuit" then
    record.entity.get_or_create_control_behavior().circuit_enable_disable = element.state
    find(window_of(player), "bte_stargate_condition").visible = element.state
  end
  refresh(player, record)
end

-- Keeps open windows' status current, and closes those whose gate is gone.
function Gui.update()
  for index in pairs(storage.open_gui) do
    local player = game.get_player(index)
    local record = shown(index)
    if not (player and record) then
      if player then
        close(player)
      else
        storage.open_gui[index] = nil
      end
    else
      refresh(player, record)
    end
  end
end

return Gui
