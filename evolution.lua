local evolution = {}

evolution.factors = {"time", "pollution", "trees", "units", "spawners", "worms", "expansion"}

local COMBAT_EFFECTS = {
  ["ammo-damage"] = true, ["gun-speed"] = true, ["turret-attack"] = true,
  ["artillery-range"] = true, ["character-health-bonus"] = true,
  ["maximum-following-robots-count"] = true, ["follower-robot-lifetime"] = true
}

local function combat_item(item)
  if not item then return false end
  if item.type == "ammo" or item.type == "gun" or item.type == "armor" then return true end

  local action = item.type == "capsule" and item.capsule_action
  if action and (action.type == "throw" or action.type == "artillery-remote") then return true end

  local entity = item.place_result
  if entity and (entity.attack_parameters or entity.type == "land-mine"
    or (entity.guns and next(entity.guns))) then return true end

  local equipment = item.place_as_equipment_result
  return equipment and (equipment.type == "active-defense-equipment"
    or equipment.type == "energy-shield-equipment") or false
end

function evolution.is_combat_technology(technology, recipes, items)
  for _, effect in pairs(technology.effects or {}) do
    if COMBAT_EFFECTS[effect.type] then return true end
    if effect.type == "give-item" and combat_item(items[effect.item]) then return true end
    if effect.type == "unlock-recipe" then
      local recipe = recipes[effect.recipe]
      if recipe then
        for _, product in pairs(recipe.products or {}) do
          if product.type == "item" and combat_item(items[product.name]) then return true end
        end
      end
    end
  end
  return false
end

function evolution.technology_cap(technologies, recipes, items, weights)
  local researched, total = 0, 0
  for _, technology in pairs(technologies) do
    local prototype = technology.prototype
    if technology.enabled and not prototype.hidden and prototype.max_level ~= 4294967295 then
      local weight = weights[technology.name]
      if not weight then
        weight = evolution.is_combat_technology(prototype, recipes, items) and 3 or 1
        weights[technology.name] = weight
      end
      total = total + weight
      if technology.researched then researched = researched + weight end
    end
  end
  if total == 0 then return 1 end
  local progress = researched / total
  return (progress * (2 - progress)) ^ 2
end

function evolution.from_pressure(pressure)
  if pressure <= 0 then return 0 end
  return math.min(pressure / (1 + pressure), 0.999999)
end

function evolution.change(baseline, current)
  local pressure_change = 0
  for _, factor in ipairs(evolution.factors) do
    pressure_change = pressure_change + current.factors[factor] - baseline.factors[factor]
  end

  local uncapped_change = current.uncapped - baseline.uncapped
  local scale
  if pressure_change ~= 0 then
    scale = uncapped_change / pressure_change
  elseif baseline.pressure > 0 and baseline.pressure < 999999 then
    scale = 1 / (1 + baseline.pressure)^2
  else
    scale = 0
  end

  local contributions = {}
  for _, factor in ipairs(evolution.factors) do
    contributions[factor] = (current.factors[factor] - baseline.factors[factor]) * scale
  end
  contributions.cap = (current.value - current.uncapped) - (baseline.value - baseline.uncapped)
  return current.value - baseline.value, contributions
end

return evolution
