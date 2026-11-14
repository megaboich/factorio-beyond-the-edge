-- Sending a character through a gate. Stepping into an open portal takes the character out of the
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
local Destinations = require("scripts.destinations")
local Gate = require("scripts.gate")

local Transfer = {}

local LIMBO = "bte-stargate-limbo"
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
-- Gives up the run out after this long, should something block it.
local EXIT_TICKS = 150
-- Cutscenes wait this much longer than the script needs, so they never end on their own first.
local SLACK = 300
-- The camera centres on the veil's middle while the traveller is away.
local VIEW_Y = 0.7
local CYAN = {0.35, 0.85, 1}

function Transfer.init_storage()
  storage.transfers = storage.transfers or {}
  storage.exits = storage.exits or {}
end

-- A small hidden lab-tile surface that holds characters in transit.
local function limbo()
  local surface = game.get_surface(LIMBO)
  if not surface then
    surface = game.create_surface(LIMBO, {width = 32, height = 32})
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.request_to_generate_chunks({0, 0}, 0)
    surface.force_generate_chunk_requests()
  end
  for _, force in pairs(game.forces) do
    force.set_surface_hidden(surface, true)
  end
  return surface
end

-- Only a player walking its own character is given the cutscenes; anyone else (in remote view, say)
-- just travels.
local function watching(character)
  local player = character.player
  if player and player.controller_type == defines.controllers.character then
    return player
  end
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
    -- brought to the player first (callers move it on within the same tick).
    if character.surface ~= player.surface then
      character.teleport(player.position, player.surface)
    end
    player.set_controller({type = defines.controllers.character, character = character})
  end
end

-- Plays `animation` once over `ticks`, starting on its first frame whatever the tick, drawn as over a
-- gate whose position (origin) is `origin`.
local function play(animation, surface, origin, ticks)
  local speed = PASSAGE_FRAMES / ticks
  return rendering.draw_animation({
    animation = animation, target = origin, surface = surface,
    render_layer = "higher-object-above", animation_speed = speed,
    animation_offset = (PASSAGE_FRAMES - (game.tick * speed) % PASSAGE_FRAMES) % PASSAGE_FRAMES,
    time_to_live = ticks
  })
end

function Transfer.start(character, record)
  Transfer.init_storage()
  local id = character.unit_number
  if storage.transfers[id] then
    return
  end
  local partner = Gate.partner(record)
  local random
  if not partner then
    local surface, position = Destinations.pick(record.entity.force)
    if not surface then
      return
    end
    random = {surface = surface.index, position = position}
  end
  local surface, gate = record.entity.surface, record.entity.position
  local passage = play("bte-stargate-passage", record.entity.surface, record.entity.position, TRANSIT_TICKS)
  surface.play_sound({path = "bte-stargate-depart", position = {gate.x + 1, gate.y + 1}})
  local player = watching(character)
  storage.transfers[id] = {
    character = character, player = player and player.index, from = record.entity.unit_number,
    to = partner and partner.entity.unit_number, random = random, start = game.tick, passage = passage,
    origin = {surface = surface.index, position = character.position}
  }
  if player then
    cutscene(player, {position = {gate.x + 1, gate.y + 1 + VIEW_Y}, transition_time = 20,
      time_to_wait = TRANSIT_TICKS + SLACK}, character.position)
  end
  character.teleport({0, 0}, limbo())
end

-- Where the traveller comes out: its random destination, or the partner, or the sending gate if the
-- partner is gone, or failing both where it went in. The third result is the arrival gate, if any.
local function landing(transfer)
  local random = transfer.random and game.get_surface(transfer.random.surface)
  if random then
    return random, transfer.random.position, nil
  end
  local target = Gate.get(transfer.to) or Gate.get(transfer.from)
  if target then
    local surface, position = Gate.arrival(target)
    return surface, position, target.entity
  end
  return game.get_surface(transfer.origin.surface), transfer.origin.position, nil
end

-- Leaving is over: the camera moves to the arrival gate while the reversed ripples play on it.
local function arrive(transfer)
  if transfer.passage.valid then
    transfer.passage.destroy()
  end
  transfer.arriving = game.tick
  local character = transfer.character
  local surface, position, gate = landing(transfer)
  if gate then
    transfer.passage = play("bte-stargate-arrival", surface, gate.position, ARRIVAL_TICKS)
  else
    -- No gate: the ripples converge in mid-air on the spot where the traveller appears.
    transfer.passage = play("bte-stargate-arrival", surface, {position.x - ORIGIN_TO_BODY.x, position.y - ORIGIN_TO_BODY.y}, ARRIVAL_TICKS)
  end
  local player = transfer.player and game.get_player(transfer.player)
  if player and player.valid and character.valid and player.controller_type == defines.controllers.cutscene then
    -- A cutscene shows the surface its player is on, so in one tick (no frame is drawn in between) the
    -- player takes the character back, both move to the arrival surface, the cutscene starts there, and
    -- the character returns to limbo.
    leave_cutscene(player, character)
    character.teleport(position, surface)
    local view = gate and {gate.position.x + 1, gate.position.y + 1 + VIEW_Y} or position
    cutscene(player, {position = view, transition_time = 1, time_to_wait = ARRIVAL_TICKS + SLACK}, view)
    character.teleport({0, 0}, limbo())
  end
  -- The arrival sound waits a few ticks (update()): a player only hears sounds on the surface it is
  -- on, and one played in the tick its camera changed surface was not heard.
  transfer.sound = {surface = surface.index, position = gate and {gate.position.x + 1, gate.position.y + 1} or position}
end

-- Plays the arrival sound at the arrival point to everyone on its surface, and straight to the traveller.
local function sound_arrival(transfer)
  local sound = transfer.sound
  transfer.sound = nil
  local surface = game.get_surface(sound.surface)
  if not surface then
    return
  end
  local position = sound.position
  for _, player in pairs(game.connected_players) do
    if player.index == transfer.player then
      -- The traveller hears it at full volume wherever its camera is.
      player.play_sound({path = "bte-stargate-arrive"})
    elseif player.surface == surface then
      player.play_sound({path = "bte-stargate-arrive", position = position})
    end
  end
end

local function finish(id, transfer)
  if transfer.passage and transfer.passage.valid then
    transfer.passage.destroy()
  end
  storage.transfers[id] = nil
  local player = transfer.player and game.get_player(transfer.player)
  local character = transfer.character
  if not character.valid then
    leave_cutscene(player)
    return
  end
  local surface, position, gate = landing(transfer)
  character.teleport(position, surface)
  rendering.draw_light({sprite = "utility/light_medium", target = character, surface = surface,
    scale = 2, intensity = 1, color = CYAN, time_to_live = 40})
  if not gate then
    -- Nowhere to run out of.
    leave_cutscene(player, character)
    return
  end
  local exit = {character = character, until_y = character.position.y + EXIT_DISTANCE, until_tick = game.tick + EXIT_TICKS}
  if player and player.valid and player.controller_type == defines.controllers.cutscene then
    -- Back to the character, now at the far gate, then straight into a cutscene that follows it.
    leave_cutscene(player, character)
    cutscene(player, {target = character, transition_time = 1, time_to_wait = EXIT_TICKS + SLACK}, character.position)
    exit.player = player.index
  end
  storage.exits[id] = exit
end

local function stop(id, exit)
  storage.exits[id] = nil
  if exit.character.valid then
    exit.character.walking_state = {walking = false, direction = defines.direction.south}
  end
  leave_cutscene(exit.player and game.get_player(exit.player), exit.character)
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
      arrive(transfer)
    end
  end
  for id, exit in pairs(storage.exits) do
    local character = exit.character
    if not character.valid or character.position.y >= exit.until_y or tick >= exit.until_tick then
      stop(id, exit)
    else
      character.walking_state = {walking = true, direction = defines.direction.south}
    end
  end
end

-- A player whose cutscene is skipped (or ends by itself) arrives at once, or takes back control of the run.
function Transfer.on_cutscene_cancelled(event)
  if storage.leaving_cutscene == event.player_index then
    return
  end
  for id, transfer in pairs(storage.transfers or {}) do
    if transfer.player == event.player_index then
      transfer.player = nil
      finish(id, transfer)
      local player = game.get_player(event.player_index)
      if player and transfer.character.valid and player.controller_type ~= defines.controllers.character then
        player.set_controller({type = defines.controllers.character, character = transfer.character})
      end
      return
    end
  end
  for id, exit in pairs(storage.exits or {}) do
    if exit.player == event.player_index then
      stop(id, exit)
      return
    end
  end
  -- A character left in limbo with no trip to finish (it should not happen) is put back at its
  -- force's spawn rather than stranded.
  local player = game.get_player(event.player_index)
  local character = player and player.character
  if character and character.surface.name == LIMBO then
    local surface = game.surfaces.nauvis
    local spawn = player.force.get_spawn_position(surface)
    character.teleport(surface.find_non_colliding_position("character", spawn, 20, 0.5) or spawn, surface)
  end
end

return Transfer
