data:extend({
  {type="double-setting", name="cde-time-percent", setting_type="runtime-global", minimum_value=0, maximum_value=500, default_value=3, order="a-a"},
  {type="double-setting", name="cde-pollution-percent", setting_type="runtime-global", minimum_value=0, maximum_value=500, default_value=50, order="a-b"},
  {type="double-setting", name="cde-tree-absorption-percent", setting_type="runtime-global", minimum_value=0, maximum_value=500, default_value=100, order="a-c"},
  {type="double-setting", name="cde-unit-kills-per-1000", setting_type="runtime-global", minimum_value=0, maximum_value=100, default_value=0.5, order="b-a"},
  {type="double-setting", name="cde-spawner-reduction", setting_type="runtime-global", minimum_value=0, maximum_value=10, default_value=0.10, order="b-b"},
  {type="double-setting", name="cde-worm-reduction", setting_type="runtime-global", minimum_value=0, maximum_value=10, default_value=0.01, order="b-c"},
  {type="bool-setting", name="cde-expansion-enabled", setting_type="runtime-global", default_value=true, order="c-a"},
  {type="double-setting", name="cde-expansion-per-chunk", setting_type="runtime-global", minimum_value=0, maximum_value=10, default_value=0.05, order="c-b"},
  {type="bool-setting", name="cde-tech-cap-enabled", setting_type="runtime-global", default_value=false, order="d-a"},
  {type="bool-setting", name="cde-show-session-evolution", setting_type="runtime-per-user", default_value=false, order="e-a"}
})
