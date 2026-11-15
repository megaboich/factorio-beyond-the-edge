-- Sending a traveller through a gate: a character on foot, a car, tank, or spidertron with whoever
-- rides it (or nobody, or driven remotely), or a biter, spitter, or pentapod. Entering an open portal
-- takes the traveller out of the
-- world for TRANSIT_TICKS: it waits on a hidden limbo surface while the veil ripples from where it
-- went in (the bte-stargate-passage animation), and its player watches the gate in a cutscene, which
-- holds the camera still and ignores movement keys. Then the camera cuts to the partner gate (or back
-- to the sending gate if the partner is gone), where the same ripples play backwards over ARRIVAL_TICKS
-- (bte-stargate-arrival), converging on the point the character steps out of at their end. It then
-- runs EXIT_DISTANCE tiles out of the
-- ring, walked by script each tick while a second cutscene follows it, so the keys still do nothing.
-- A gate with no partner sends the traveller to a random destination instead (scripts/destinations.lua),
-- picked as it steps in; there is no gate there, so the reversed ripples play in mid-air and there is no run out.
-- Skipping a cutscene (its usual key) cuts the wait or the run short; the trip still completes.
-- Only players riding their own character, on foot or in the vehicle, get the cutscenes. Vehicles keep
-- their crew, cargo, fuel, and equipment through a cross-surface teleport (measured headless). Units
-- cannot be teleported across surfaces, so they travel as clones (a new entity each time they change
-- surface). Vehicles and units are inactive in limbo, so a parked car does not drive off and a biter
-- does not attack a character waiting there. After the trip a car or tank drives, a spidertron walks
-- (autopilot), and a unit is commanded EXIT_DISTANCE tiles south.
local Destinations = require("scripts.destinations")
local Gate = require("scripts.gate")

local Transfer = {}

local LIMBO = "bte-stargate-limbo"
-- Limbo's size, and the spacing of the spots vehicles and units are parked on there (characters all
-- wait at its centre), so parked vehicles do not overlap.
local LIMBO_SIZE = 512
local SLOT_SPACING = 10
local SLOTS_PER_ROW = 20
-- The passage animation's length: 32 frames over two 64-tick veil loops (models/stargate.js).
local TRANSIT_TICKS = 128
local PASSAGE_FRAMES = 32
-- The reversed ripples play at twice the speed (prototypes/entities.lua, bte-stargate-arrival).
local ARRIVAL_TICKS = 64
-- Where the ripples converge, relative to the gate origin they are drawn for: the veil's centre is
-- 0.67 tiles south of it and one east (the sprite shift), and the point (models/stargate.js,
-- drawPassage) 1.69 tiles below that. Standing a traveller's feet one tile further down puts the point
-- on its body.
local ORIGIN_TO_BODY = {x = 1, y = 3.36}
-- Ticks after the camera reaches the arrival gate before its sound plays (see arrive()).
local SOUND_DELAY = 3
local EXIT_DISTANCE = 5
-- A car or tank leaving the ring is driven at this many tiles a tick (a running character's speed).
local DRIVE_SPEED = 0.15
-- Gives up the run out after this long, should something block it.
local EXIT_TICKS = 150
-- How long an arrival is not sent back through the gate it came out of (Transfer.can_enter).
local ARRIVED_TICKS = 300
-- Cutscenes wait this much longer than the script needs, so they never end on their own first.
local SLACK = 300
-- The camera centres on the veil's middle while the traveller is away.
local VIEW_Y = 0.7
local CYAN = {0.35, 0.85, 1}
local SOUTH = 0.5

local UNITS = {unit = true, ["spider-unit"] = true}
local VEHICLES = {car = true, ["spider-vehicle"] = true}

function Transfer.init_storage()
  storage.transfers = storage.transfers or {}
  storage.exits = storage.exits or {}
  storage.next_transfer = storage.next_transfer or 1
end

-- A hidden lab-tile surface that holds travellers in transit.
local function limbo()
  local surface = game.get_surface(LIMBO)
  if not surface then
    surface = game.create_surface(LIMBO, {width = LIMBO_SIZE, height = LIMBO_SIZE})
    surface.generate_with_lab_tiles = true
    surface.always_day = true
  elseif surface.map_gen_settings.width < LIMBO_SIZE then
    -- Saves from before vehicles travelled have a 32-tile limbo.
    local settings = surface.map_gen_settings
    settings.width, settings.height = LIMBO_SIZE, LIMBO_SIZE
    surface.map_gen_settings = settings
  end
  if not surface.is_chunk_generated({3, 3}) then
    surface.request_to_generate_chunks({0, 0}, 4)
    surface.force_generate_chunk_requests()
  end
  for _, force in pairs(game.forces) do
    force.set_surface_hidden(surface, true)
  end
  return surface
end

-- Where transfer `id` waits in limbo: characters at the centre, others each on their own spot.
local function parking(id, entity)
  if entity.type == "character" then
    return {0, 0}
  end
  local slot = id % (SLOTS_PER_ROW * SLOTS_PER_ROW)
  local half = SLOTS_PER_ROW * SLOT_SPACING / 2
  return {(slot % SLOTS_PER_ROW) * SLOT_SPACING - half + 5, math.floor(slot / SLOTS_PER_ROW) * SLOT_SPACING - half + 5}
end

-- Moves `entity` to `position` on `surface` and returns it, or the clone that replaced it: units
-- cannot be teleported across surfaces ("only players, characters, cars, and spidertrons"), and
-- may refuse a crowded spot on their own surface, so they are cloned there and the original removed.
local function move(entity, position, surface)
  if not UNITS[entity.type] then
    entity.teleport(position, surface)
    return entity
  end
  if entity.surface == surface and entity.teleport(position) then
    return entity
  end
  local clone = entity.clone({position = position, surface = surface, create_build_effect_smoke = false})
  if not clone then
    return entity
  end
  entity.destroy()
  return clone
end

-- The characters riding along: the traveller itself, or a vehicle's driver and passenger. A remote
-- driver is a player, not a character, and stays in remote view.
local function crew(entity)
  if entity.type == "character" then
    return {entity}
  end
  local list = {}
  if VEHICLES[entity.type] then
    for _, rider in pairs({entity.get_driver(), entity.get_passenger()}) do
      if rider.object_name == "LuaEntity" and rider.type == "character" then
        list[#list + 1] = rider
      end
    end
  end
  return list
end

-- The players to give cutscenes: each controlling one of the riding characters.
local function watching(entity)
  local list = {}
  for _, character in pairs(crew(entity)) do
    local player = character.player
    if player and player.controller_type == defines.controllers.character then
      list[#list + 1] = {player = player.index, character = character}
    end
  end
  return list
end

local function cutscene(player, waypoint, from)
  waypoint.transition_time = waypoint.transition_time or 1
  player.set_controller({type = defines.controllers.cutscene, waypoints = {waypoint}, start_position = from,
    final_transition_time = 0})
end

-- Ends the player's cutscene and makes sure it controls `character` again. A cutscene started from
-- another cutscene has no character to return to, which left the player a bodiless camera, so the
-- character is handed back explicitly rather than trusted to the cutscene.
local function leave_cutscene(player, character)
  if not (player and player.valid) then
    return
  end
  if player.controller_type == defines.controllers.cutscene then
    -- exit_cutscene raises on_cutscene_cancelled at once; the handler must not take our own exit for
    -- the player skipping the cutscene (it would finish the trip mid-way through arrive()).
    storage.leaving_cutscene = player.index
    player.exit_cutscene()
    storage.leaving_cutscene = nil
  end
  if character and character.valid and player.character ~= character then
    -- set_controller needs the character on the player's surface; a character still in limbo is
    -- brought to the player first (callers move it on within the same tick). One in a vehicle comes
    -- with its vehicle, since teleporting it alone would take it out of its seat.
    if character.surface ~= player.surface then
      (character.vehicle or character).teleport(player.position, player.surface)
    end
    player.set_controller({type = defines.controllers.character, character = character})
  end
end

local function leave_all(watchers)
  for _, watcher in pairs(watchers) do
    leave_cutscene(game.get_player(watcher.player), watcher.character)
  end
end

-- Watchers whose player is still in a cutscene.
local function in_cutscene(watchers)
  local list = {}
  for _, watcher in pairs(watchers) do
    local player = game.get_player(watcher.player)
    if player and player.valid and watcher.character.valid and player.controller_type == defines.controllers.cutscene then
      list[#list + 1] = {player = player, character = watcher.character}
    end
  end
  return list
end

-- Plays `animation` once over `ticks`, starting on its first frame whatever the tick, drawn as over a
-- gate whose position (origin) is `origin`.
local function play(animation, surface, origin, ticks)
  local speed = PASSAGE_FRAMES / ticks
  -- A bright cyan flash of light on the surroundings, centred on the veil's middle on screen (the
  -- gate's centre is origin + (1, 1), the ring 2 tiles south, its centre about 1.6 tiles up).
  local position = origin.x and origin or {x = origin[1], y = origin[2]}
  rendering.draw_light({sprite = "utility/light_medium", scale = 5, intensity = 1, color = {0.3, 0.85, 1},
    surface = surface, target = {position.x + 1, position.y + 1.4}, time_to_live = math.min(ticks, 60)})
  return rendering.draw_animation({
    animation = animation, target = origin, surface = surface,
    render_layer = "higher-object-above", animation_speed = speed,
    animation_offset = (PASSAGE_FRAMES - (game.tick * speed) % PASSAGE_FRAMES) % PASSAGE_FRAMES,
    time_to_live = ticks
  })
end

-- A player driving a tank or spidertron remotely is put out of it as it enters: otherwise the remote
-- camera and controls followed the vehicle into dark limbo. Its view stays where it was, but movement
-- keys still held from driving then pan it. Nothing tried kept them from it without a visible cost:
-- remote view accepts no cutscene, pinning the view back each tick looked jumpy, and seating the
-- player in a hidden frozen vehicle shows the game's enter and leave vehicle messages.
local function release_remote(entity)
  local driver = entity.get_driver()
  if not (driver and driver.object_name == "LuaPlayer") then
    return
  end
  local position, surface = driver.position, driver.surface
  entity.set_driver(nil)
  if driver.valid and driver.controller_type == defines.controllers.remote then
    driver.set_controller({type = defines.controllers.remote, position = position, surface = surface})
  end
end

-- Whether `entity` may exist on `surface`: teleport ignores surface conditions, so a car would
-- otherwise reach a space platform.
local function allowed(entity, surface)
  for _, condition in pairs(entity.prototype.surface_conditions or {}) do
    local value = surface.get_property(condition.property)
    if (condition.min and value < condition.min) or (condition.max and value > condition.max) then
      return false
    end
  end
  return true
end

-- Whether `entity` may be sent: not while it is still leaving the gate it arrived at.
function Transfer.can_enter(entity)
  local arrived = storage.arrived
  local until_tick = arrived and entity.unit_number and arrived[entity.unit_number]
  if not until_tick then
    return true
  end
  if game.tick < until_tick then
    return false
  end
  arrived[entity.unit_number] = nil
  return true
end

function Transfer.start(entity, record)
  Transfer.init_storage()
  if not Transfer.can_enter(entity) then
    return
  end
  local partner = Gate.partner(record)
  local random
  if partner then
    if not allowed(entity, partner.entity.surface) then
      return
    end
  else
    local surface, position = Destinations.pick(record.entity.force)
    if not (surface and allowed(entity, surface)) then
      return
    end
    random = {surface = surface.index, position = position}
  end
  local id = storage.next_transfer
  storage.next_transfer = id + 1
  local surface, gate = record.entity.surface, record.entity.position
  local passage = play("bte-stargate-passage", surface, gate, TRANSIT_TICKS)
  surface.play_sound({path = "bte-stargate-depart", position = {gate.x + 1, gate.y + 1}})
  local watchers = watching(entity)
  for _, watcher in pairs(watchers) do
    cutscene(game.get_player(watcher.player), {position = {gate.x + 1, gate.y + 1 + VIEW_Y}, transition_time = 20,
      time_to_wait = TRANSIT_TICKS + SLACK}, entity.position)
  end
  if entity.type == "spider-vehicle" then
    -- Its waypoints are positions on the surface it leaves.
    entity.autopilot_destination = nil
    entity.follow_target = nil
  end
  if VEHICLES[entity.type] then
    release_remote(entity)
  end
  local origin = {surface = surface.index, position = entity.position}
  entity = move(entity, parking(id, entity), limbo())
  if entity.type ~= "character" then
    entity.disabled_by_script = true
  end
  storage.transfers[id] = {
    entity = entity, watchers = watchers, from = record.entity.unit_number,
    to = partner and partner.entity.unit_number, random = random, start = game.tick, passage = passage,
    origin = origin
  }
end

-- Where the traveller comes out: its random destination, or the partner, or the sending gate if the
-- partner is gone, or failing both where it went in. The third result is the arrival gate, if any.
local function landing(transfer)
  local name = transfer.entity.valid and transfer.entity.name or "character"
  local random = transfer.random and game.get_surface(transfer.random.surface)
  if random then
    local position = transfer.random.position
    return random, random.find_non_colliding_position(name, position, 16, 0.5) or position, nil
  end
  local target = Gate.get(transfer.to) or Gate.get(transfer.from)
  if target then
    local surface, position = Gate.arrival(target, name)
    return surface, position, target.entity
  end
  return game.get_surface(transfer.origin.surface), transfer.origin.position, nil
end

-- Leaving is over: the camera moves to the arrival gate while the reversed ripples play on it.
local function arrive(id, transfer)
  if transfer.passage.valid then
    transfer.passage.destroy()
  end
  transfer.arriving = game.tick
  local surface, position, gate = landing(transfer)
  if gate then
    transfer.passage = play("bte-stargate-arrival", surface, gate.position, ARRIVAL_TICKS)
  else
    -- No gate: the ripples converge in mid-air on the spot where the traveller appears.
    transfer.passage = play("bte-stargate-arrival", surface, {position.x - ORIGIN_TO_BODY.x, position.y - ORIGIN_TO_BODY.y}, ARRIVAL_TICKS)
  end
  local watchers = in_cutscene(transfer.watchers)
  if transfer.entity.valid and #watchers > 0 then
    -- A cutscene shows the surface its player is on, so in one tick (no frame is drawn in between) the
    -- players take their characters back, the traveller moves to the arrival surface with them, the
    -- cutscenes start there, and the traveller returns to limbo. Only characters and vehicles have
    -- watchers, so the traveller is never replaced by a clone here.
    for _, watcher in pairs(watchers) do
      leave_cutscene(watcher.player, watcher.character)
    end
    transfer.entity.teleport(position, surface)
    local view = gate and {gate.position.x + 1, gate.position.y + 1 + VIEW_Y} or position
    for _, watcher in pairs(watchers) do
      cutscene(watcher.player, {position = view, transition_time = 1, time_to_wait = ARRIVAL_TICKS + SLACK}, view)
    end
    transfer.entity.teleport(parking(id, transfer.entity), limbo())
  end
  -- The arrival sound waits a few ticks (update()): a player only hears sounds on the surface it is
  -- on, and one played in the tick its camera changed surface was not heard.
  transfer.sound = {surface = surface.index, position = gate and {gate.position.x + 1, gate.position.y + 1} or position}
end

-- Plays the arrival sound at the arrival point to everyone on its surface, and straight to the travellers.
local function sound_arrival(transfer)
  local sound = transfer.sound
  transfer.sound = nil
  local surface = game.get_surface(sound.surface)
  if not surface then
    return
  end
  local travelling = {}
  for _, watcher in pairs(transfer.watchers) do
    travelling[watcher.player] = true
  end
  for _, player in pairs(game.connected_players) do
    if travelling[player.index] then
      -- The traveller hears it at full volume wherever its camera is.
      player.play_sound({path = "bte-stargate-arrive"})
    elseif player.surface == surface then
      player.play_sound({path = "bte-stargate-arrive", position = sound.position})
    end
  end
end

-- Sends the traveller EXIT_DISTANCE tiles south. Characters and cars are moved by update() each tick
-- (the returned exit); a spidertron and a unit are given a destination once.
local function run_out(entity)
  local target = {x = entity.position.x, y = entity.position.y + EXIT_DISTANCE}
  if entity.type == "spider-vehicle" then
    entity.autopilot_destination = target
    return nil
  elseif UNITS[entity.type] then
    entity.commandable.set_command({type = defines.command.go_to_location, destination = target, radius = 1,
      distraction = defines.distraction.by_enemy})
    return nil
  elseif entity.type == "car" then
    entity.orientation = SOUTH
  end
  return {entity = entity, until_y = target.y, until_tick = game.tick + EXIT_TICKS}
end

local function finish(id, transfer)
  if transfer.passage and transfer.passage.valid then
    transfer.passage.destroy()
  end
  storage.transfers[id] = nil
  local watchers = in_cutscene(transfer.watchers)
  local entity = transfer.entity
  if not entity.valid then
    leave_all(transfer.watchers)
    return
  end
  local surface, position, gate = landing(transfer)
  entity = move(entity, position, surface)
  if entity.type ~= "character" then
    entity.disabled_by_script = false
  end
  rendering.draw_light({sprite = "utility/light_medium", target = entity, surface = surface,
    scale = 2, intensity = 1, color = CYAN, time_to_live = 40})
  if not gate then
    -- Nowhere to run out of.
    leave_all(transfer.watchers)
    return
  end
  -- A spidertron's body can come down inside the partner's portal while its legs settle, which sent
  -- it straight back through an open partner; whatever arrives is left alone until it has run out.
  storage.arrived = storage.arrived or {}
  for unit_number, until_tick in pairs(storage.arrived) do
    if until_tick <= game.tick then
      storage.arrived[unit_number] = nil
    end
  end
  if entity.unit_number then
    storage.arrived[entity.unit_number] = game.tick + ARRIVED_TICKS
  end
  local exit = run_out(entity)
  if #watchers > 0 then
    -- Back to the characters, now at the far gate, then straight into cutscenes that follow the traveller.
    exit = exit or {entity = entity, until_y = entity.position.y + EXIT_DISTANCE, until_tick = game.tick + EXIT_TICKS}
    exit.watchers = {}
    for _, watcher in pairs(watchers) do
      leave_cutscene(watcher.player, watcher.character)
      cutscene(watcher.player, {target = entity, transition_time = 1, time_to_wait = EXIT_TICKS + SLACK}, entity.position)
      exit.watchers[#exit.watchers + 1] = {player = watcher.player.index, character = watcher.character}
    end
  end
  if exit then
    storage.exits[id] = exit
  end
end

local function stop(id, exit)
  storage.exits[id] = nil
  if exit.entity.valid and exit.entity.type == "character" then
    exit.entity.walking_state = {walking = false, direction = defines.direction.south}
  end
  leave_all(exit.watchers or {})
end

function Transfer.update()
  local tick = game.tick
  for id, transfer in pairs(storage.transfers) do
    if transfer.arriving then
      if transfer.sound and tick - transfer.arriving >= SOUND_DELAY then
        sound_arrival(transfer)
      end
      if tick - transfer.arriving >= ARRIVAL_TICKS then
        finish(id, transfer)
      end
    elseif tick - transfer.start >= TRANSIT_TICKS then
      arrive(id, transfer)
    end
  end
  for id, exit in pairs(storage.exits) do
    local entity = exit.entity
    if not entity.valid or entity.position.y >= exit.until_y or tick >= exit.until_tick then
      stop(id, exit)
    elseif entity.type == "character" then
      entity.walking_state = {walking = true, direction = defines.direction.south}
    elseif entity.type == "car" then
      entity.speed = DRIVE_SPEED
    end
  end
end

local function watched_by(watchers, index)
  for _, watcher in pairs(watchers or {}) do
    if watcher.player == index then
      return watcher
    end
  end
end

-- A player whose cutscene is skipped (or ends by itself) arrives at once, with whatever it travels
-- with, or takes back control of the run.
function Transfer.on_cutscene_cancelled(event)
  if storage.leaving_cutscene == event.player_index then
    return
  end
  local player = game.get_player(event.player_index)
  for id, transfer in pairs(storage.transfers or {}) do
    local watcher = watched_by(transfer.watchers, event.player_index)
    if watcher then
      -- Out of the list first, so finish() leaves this player be; anyone else riding along carries on.
      for index, other in pairs(transfer.watchers) do
        if other == watcher then
          table.remove(transfer.watchers, index)
          break
        end
      end
      finish(id, transfer)
      if player and watcher.character.valid and player.controller_type ~= defines.controllers.character then
        player.set_controller({type = defines.controllers.character, character = watcher.character})
      end
      return
    end
  end
  for id, exit in pairs(storage.exits or {}) do
    if watched_by(exit.watchers, event.player_index) then
      stop(id, exit)
      return
    end
  end
  -- A character left in limbo with no trip to finish (it should not happen) is put back at its
  -- force's spawn rather than stranded.
  local character = player and player.character
  if character and character.surface.name == LIMBO then
    local surface = game.surfaces.nauvis
    local spawn = player.force.get_spawn_position(surface)
    local body = character.vehicle or character
    body.teleport(surface.find_non_colliding_position(body.name, spawn, 20, 0.5) or spawn, surface)
  end
end

return Transfer
