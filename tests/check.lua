local evolution = require("evolution")

local function snapshot(factors, cap)
  local pressure = 0
  for _, factor in ipairs(evolution.factors) do pressure = pressure + (factors[factor] or 0) end
  for _, factor in ipairs(evolution.factors) do factors[factor] = factors[factor] or 0 end
  local uncapped = evolution.from_pressure(pressure)
  cap = cap or 1
  return {factors = factors, pressure = pressure, uncapped = uncapped,
    cap = cap, value = math.min(uncapped, cap)}
end

local before = snapshot{time = 0.2, pollution = 0.3}
local after = snapshot{time = 0.25, pollution = 0.35, trees = -0.02, units = 0.01}
local change, parts = evolution.change(before, after)
local total = 0
for _, factor in ipairs(evolution.factors) do total = total + parts[factor] end
assert(math.abs(total - change) < 1e-12)
assert(parts.trees < 0 and parts.units > 0)

local offset = snapshot{time = 0.3, pollution = 0.2}
local zero_change, offset_parts = evolution.change(before, offset)
assert(math.abs(zero_change) < 1e-12)
assert(offset_parts.time > 0 and offset_parts.pollution < 0)
assert(evolution.from_pressure(-1) == 0)

local capped_before = snapshot({time = 0.5}, 0.1)
local capped_after = snapshot({time = 0.6}, 0.1)
local capped_change, capped_parts = evolution.change(capped_before, capped_after)
assert(capped_change == 0 and capped_parts.time > 0 and capped_parts.cap < 0)
assert(math.abs(capped_parts.time + capped_parts.cap) < 1e-12)

local raised_cap = snapshot({time = 0.5}, 0.2)
local research_change, research_parts = evolution.change(capped_before, raised_cap)
assert(math.abs(research_change - 0.1) < 1e-12)
assert(math.abs(research_parts.cap - research_change) < 1e-12)

local items = {
  ["modded-turret"] = {type="item", place_result={attack_parameters={}}},
  ["modded-ammo"] = {type="ammo"},
  ["utility-capsule"] = {type="capsule", capsule_action={type="use-on-self"}}
}
local recipes = {
  ["modded-defense"] = {products={{type="item", name="modded-turret"}}},
  ["modded-ammunition"] = {products={{type="item", name="modded-ammo"}}},
  ["utility"] = {products={{type="item", name="utility-capsule"}}}
}
assert(evolution.is_combat_technology({effects={{type="ammo-damage"}}}, recipes, items))
assert(evolution.is_combat_technology({effects={{type="unlock-recipe", recipe="modded-defense"}}}, recipes, items))
assert(evolution.is_combat_technology({effects={{type="unlock-recipe", recipe="modded-ammunition"}}}, recipes, items))
assert(not evolution.is_combat_technology({effects={{type="unlock-recipe", recipe="utility"}}}, recipes, items))

local technologies = {
  {name="ordinary-1", enabled=true, researched=true, prototype={max_level=0, effects={}}},
  {name="ordinary-2", enabled=true, researched=false, prototype={max_level=0, effects={}}},
  {name="modded-defense-tech", enabled=true, researched=true,
    prototype={max_level=0, effects={{type="unlock-recipe", recipe="modded-defense"}}}},
  {name="hidden-combat", enabled=true, researched=false,
    prototype={hidden=true, max_level=0, effects={{type="ammo-damage"}}}},
  {name="infinite-combat", enabled=true, researched=false,
    prototype={max_level=4294967295, effects={{type="ammo-damage"}}}},
  {name="disabled-combat", enabled=false, researched=false,
    prototype={max_level=0, effects={{type="ammo-damage"}}}}
}
assert(math.abs(evolution.technology_cap(technologies, recipes, items, {}) - 0.9216) < 1e-12)
technologies[1].researched = false
technologies[3].researched = false
assert(evolution.technology_cap(technologies, recipes, items, {}) == 0)
technologies[1].researched = true
technologies[2].researched = true
technologies[3].researched = true
assert(evolution.technology_cap(technologies, recipes, items, {}) == 1)
assert(evolution.technology_cap({}, recipes, items, {}) == 1)

return true
