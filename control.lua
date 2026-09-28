local evolution = require("evolution")

local QUALIFYING_TYPES = {
  ["assembling-machine"] = true, ["furnace"] = true, ["mining-drill"] = true,
  ["lab"] = true, ["beacon"] = true, ["roboport"] = true, ["reactor"] = true,
  ["boiler"] = true, ["generator"] = true, ["burner-generator"] = true,
  ["solar-panel"] = true, ["accumulator"] = true, ["storage-tank"] = true,
  ["pump"] = true, ["offshore-pump"] = true, ["train-stop"] = true,
  ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true,
  ["artillery-turret"] = true, ["radar"] = true, ["rocket-silo"] = true,
  ["agricultural-tower"] = true
}

local QUALIFYING_TYPE_LIST = {}
for entity_type in pairs(QUALIFYING_TYPES) do
  table.insert(QUALIFYING_TYPE_LIST, entity_type)
end

local function get_state(surface_index)
  storage.cde = storage.cde or {surfaces = {}}
  local state = storage.cde.surfaces[surface_index]
  if not state then
    state = {unit_kills=0, spawner_kills=0, worm_kills=0, expansion_chunks=0, occupied_chunks={}, tree_absorbed=0, last_tree_absorption=nil}
    storage.cde.surfaces[surface_index] = state
  end
  state.occupied_chunks = state.occupied_chunks or {}
  state.tree_absorbed = state.tree_absorbed or 0
  return state
end

local function chunk_key(position)
  return math.floor(position.x / 32) .. ":" .. math.floor(position.y / 32)
end

local function player_kill(force)
  return force and force.valid and force.name == "player"
end

local function enemy_force()
  return game.forces["enemy"]
end

local function pct(name)
  return settings.global[name].value / 100
end

local combat_technology_weights = {}
local function technology_cap()
  if not settings.global["cde-tech-cap-enabled"].value then return 1 end
  return evolution.technology_cap(game.forces.player.technologies,
    prototypes.recipe, prototypes.item, combat_technology_weights)
end


local function current_tree_absorption(surface)
  local stats = game.get_pollution_statistics(surface.index)
  if not stats or not stats.valid then return 0 end
  local counts = stats.output_counts or {}
  return (counts["tree-proxy"] or 0) + (counts["tree-dying-proxy"] or 0)
end

local function baseline_tree_absorption(surface)
  if not surface or not surface.valid or surface.platform then return end
  local state = get_state(surface.index)
  state.last_tree_absorption = current_tree_absorption(surface)
end

local function sample_tree_absorption(surface)
  if not surface or not surface.valid or surface.platform then return end
  local state = get_state(surface.index)
  local current = current_tree_absorption(surface)

  if state.last_tree_absorption == nil then
    state.last_tree_absorption = current
    return
  end

  local delta
  if current >= state.last_tree_absorption then
    delta = current - state.last_tree_absorption
  else
    -- Pollution statistics can be reset. Treat the new counter as the amount
    -- accumulated since that reset instead of creating a negative delta.
    delta = current
  end

  if delta > 0 then
    state.tree_absorbed = state.tree_absorbed + delta
  end
  state.last_tree_absorption = current
end

local function recalc(surface)
  if not surface or not surface.valid or surface.platform then return end
  local enemy = enemy_force()
  if not enemy then return end

  local state = get_state(surface.index)
  local ok_t, time_raw = pcall(enemy.get_evolution_factor_by_time, surface)
  local ok_p, pollution_raw = pcall(enemy.get_evolution_factor_by_pollution, surface)
  if not ok_t or not ok_p then return end

  local pollution_scale = pct("cde-pollution-percent")

  -- 100% tree credit means one pollution unit absorbed by trees cancels
  -- exactly the effective evolution pressure of one pollution unit produced
  -- under the current CDE pollution multiplier. Map settings are read, not changed.
  local vanilla_pollution_factor = game.map_settings.enemy_evolution.pollution_factor or 0
  local factors = {
    time = (time_raw or 0) * pct("cde-time-percent"),
    pollution = (pollution_raw or 0) * pollution_scale,
    trees = -state.tree_absorbed * vanilla_pollution_factor * pollution_scale * pct("cde-tree-absorption-percent"),
    units = state.unit_kills * (settings.global["cde-unit-kills-per-1000"].value / 100000),
    spawners = -state.spawner_kills * (settings.global["cde-spawner-reduction"].value / 100),
    worms = -state.worm_kills * (settings.global["cde-worm-reduction"].value / 100),
    expansion = settings.global["cde-expansion-enabled"].value
      and state.expansion_chunks * (settings.global["cde-expansion-per-chunk"].value / 100) or 0
  }
  local pressure = 0
  for _, factor in ipairs(evolution.factors) do pressure = pressure + factors[factor] end
  local uncapped = evolution.from_pressure(pressure)
  local cap = technology_cap()
  local value = math.min(uncapped, cap)
  enemy.set_evolution_factor(value, surface)
  state.snapshot = nil
  for _, player in pairs(game.connected_players) do
    if player.surface.index == surface.index and player.mod_settings["cde-session-report-mode"].value ~= "off" then
      state.snapshot = {factors = factors, pressure = pressure, uncapped = uncapped, cap = cap, value = value}
      break
    end
  end
end

local function recalc_all()
  for _, surface in pairs(game.surfaces) do recalc(surface) end
end

local function reset_session(player)
  storage.cde.sessions = storage.cde.sessions or {}
  if player.surface.platform or player.mod_settings["cde-session-report-mode"].value == "off" then
    storage.cde.sessions[player.index] = nil
    if not player.surface.platform then recalc(player.surface) end
    return
  end
  recalc(player.surface)
  local snapshot = get_state(player.surface.index).snapshot
  if not snapshot then return end
  storage.cde.sessions[player.index] = {
    surface_index = player.surface.index,
    baseline = snapshot,
    last_report_tick = game.tick
  }
end

local function report_values(player, mode)
  if player.surface.platform or player.mod_settings["cde-session-report-mode"].value ~= mode then return end
  local session = storage.cde.sessions[player.index]
  if not session or session.surface_index ~= player.surface.index then
    reset_session(player)
    session = storage.cde.sessions[player.index]
  end
  if not session then return end
  local snapshot = get_state(player.surface.index).snapshot
  if not snapshot then return end

  local change, parts = evolution.change(session.baseline, snapshot)
  local point_format = mode == "stats-gui" and "%+.1f" or "%+.4f"
  local value_format = mode == "stats-gui" and "%.1f" or "%.4f"
  local cap_format = mode == "stats-gui" and "%.1f" or "%.2f"
  local function points(value) return string.format(point_format, value * 100) end
  return {
    string.format(value_format, snapshot.value * 100), points(change),
    points(parts.time), points(parts.pollution), points(parts.trees),
    points(parts.units), points(parts.spawners), points(parts.worms),
    points(parts.expansion), points(parts.cap),
    string.format(cap_format, snapshot.cap * 100)
  }
end

local function stats_gui_sensor(player)
  local values = report_values(player, "stats-gui")
  if not values then return end
  local caption = {"cde-report.stats", table.unpack(values, 1, 9)}
  if settings.global["cde-tech-cap-enabled"].value then
    caption[1] = "cde-report.stats-capped"
    caption[11] = values[11]
  end
  return {"", caption}
end

remote.add_interface("ConflictDrivenEvolution", {session_evolution = stats_gui_sensor})

local stats_gui_available = false
local function register_stats_gui()
  if not stats_gui_available and script.active_mods["StatsGui"]
    and remote.call("StatsGui", "version") == 1 then
    remote.call("StatsGui", "add_sensor", "ConflictDrivenEvolution", "session_evolution")
    stats_gui_available = true
  end
end

local function chat_report(values)
  return {"", {"cde-report.header", values[1], values[2]},
    "\n", {"cde-report.time", values[3]},
    "\n", {"cde-report.pollution", values[4]},
    "\n", {"cde-report.trees", values[5]},
    "\n", {"cde-report.units", values[6]},
    "\n", {"cde-report.spawners", values[7]},
    "\n", {"cde-report.worms", values[8]},
    "\n", {"cde-report.expansion", values[9]},
    "\n", {"cde-report.cap", values[10], values[11]}}
end

local function initialize_existing_chunks()
  for _, surface in pairs(game.surfaces) do
    if not surface.platform then
      local state = get_state(surface.index)
      local entities = surface.find_entities_filtered{force="player", type=QUALIFYING_TYPE_LIST}
      for _, entity in pairs(entities) do
        if entity.valid then state.occupied_chunks[chunk_key(entity.position)] = true end
      end
    end
  end
end

local function initialize()
  storage.cde = storage.cde or {surfaces = {}}
  storage.cde.sessions = {}
  initialize_existing_chunks()
  for _, surface in pairs(game.surfaces) do
    baseline_tree_absorption(surface)
  end
  recalc_all()
  for _, player in pairs(game.connected_players) do reset_session(player) end
end

local function migrate_report_setting()
  for _, player in pairs(game.players) do
    if player.mod_settings["cde-show-session-evolution"].value then
      player.mod_settings["cde-session-report-mode"] = {
        value = script.active_mods["StatsGui"] and "stats-gui" or "chat"
      }
      player.mod_settings["cde-show-session-evolution"] = {value = false}
    end
  end
end

script.on_init(function()
  initialize()
  register_stats_gui()
end)
script.on_load(register_stats_gui)
script.on_configuration_changed(function()
  migrate_report_setting()
  initialize()
  if not stats_gui_available then register_stats_gui() end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "cde-session-report-mode" then
    local player = game.get_player(event.player_index)
    if player then reset_session(player) end
  elseif string.sub(event.setting, 1, 4) == "cde-" then
    recalc_all()
  end
end)

script.on_nth_tick(60, recalc_all)

script.on_event({defines.events.on_research_finished, defines.events.on_research_reversed}, function(event)
  if event.research.force.name == "player" and settings.global["cde-tech-cap-enabled"].value then
    recalc_all()
  end
end)

script.on_nth_tick(600, function()
  for _, surface in pairs(game.surfaces) do
    sample_tree_absorption(surface)
    recalc(surface)
  end
  for _, player in pairs(game.connected_players) do
    if player.mod_settings["cde-session-report-mode"].value == "chat" then
      local session = storage.cde.sessions and storage.cde.sessions[player.index]
      if session and game.tick - session.last_report_tick >= 36000 then
        local values = report_values(player, "chat")
        if values then
          player.print(chat_report(values))
          session.last_report_tick = game.tick
        end
      end
    end
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  if player then reset_session(player) end
end)

script.on_event(defines.events.on_player_changed_surface, function(event)
  local player = game.get_player(event.player_index)
  if player then reset_session(player) end
end)

script.on_event(defines.events.on_player_left_game, function(event)
  if storage.cde and storage.cde.sessions then storage.cde.sessions[event.player_index] = nil end
end)

script.on_event(defines.events.on_player_removed, function(event)
  if storage.cde and storage.cde.sessions then storage.cde.sessions[event.player_index] = nil end
end)

script.on_event(defines.events.on_entity_died, function(event)
  local e = event.entity
  if not e or not e.valid or not e.force or e.force.name ~= "enemy" or not player_kill(event.force) then return end
  local state = get_state(e.surface.index)
  if e.type == "unit" then
    state.unit_kills = state.unit_kills + 1
  elseif e.type == "unit-spawner" then
    state.spawner_kills = state.spawner_kills + 1
  elseif e.type == "turret" then
    state.worm_kills = state.worm_kills + 1
  else
    return
  end
  recalc(e.surface)
end)

if defines.events.on_segmented_unit_died then
  script.on_event(defines.events.on_segmented_unit_died, function(event)
    local unit = event.segmented_unit
    if not unit or not unit.valid or not unit.force or unit.force.name ~= "enemy" or not player_kill(event.force) then return end
    local state = get_state(unit.surface.index)
    state.unit_kills = state.unit_kills + 1
    recalc(unit.surface)
  end)
end

local function on_built(entity)
  if not entity or not entity.valid or not entity.force or entity.force.name ~= "player" then return end
  if not QUALIFYING_TYPES[entity.type] or entity.surface.platform then return end
  local state = get_state(entity.surface.index)
  local key = chunk_key(entity.position)
  if state.occupied_chunks[key] then return end
  state.occupied_chunks[key] = true
  state.expansion_chunks = state.expansion_chunks + 1
  recalc(entity.surface)
end

script.on_event(defines.events.on_built_entity, function(event) on_built(event.entity) end)
script.on_event(defines.events.on_robot_built_entity, function(event) on_built(event.entity) end)
script.on_event(defines.events.script_raised_built, function(event) on_built(event.entity) end)
script.on_event(defines.events.script_raised_revive, function(event) on_built(event.entity) end)

script.on_event(defines.events.on_surface_created, function(event)
  local surface = game.surfaces[event.surface_index]
  if surface then
    get_state(surface.index)
    baseline_tree_absorption(surface)
    recalc(surface)
  end
end)

script.on_event(defines.events.on_surface_deleted, function(event)
  if storage.cde and storage.cde.surfaces then storage.cde.surfaces[event.surface_index] = nil end
end)
