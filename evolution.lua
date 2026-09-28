local evolution = {}

evolution.factors = {"time", "pollution", "trees", "units", "spawners", "worms", "expansion"}

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
