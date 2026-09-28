# Conflict Driven Evolution

Designed for Factorio 2.0.77 + Space Age and compatible with Rampant Fixed.

The mod deliberately does NOT modify game.map_settings.enemy_evolution.
It uses Factorio's native accumulated time and pollution contributions, scales them,
and replaces the practical evolution result with a conflict/expansion-driven model.

Defaults:
- Time: 3% of vanilla
- Pollution: 50% of vanilla
- Tree absorption credit: 100% of the effective pollution contribution
- +0.5 percentage points of raw evolution pressure per 1000 enemy units killed
- -0.10 percentage points per destroyed spawner
- -0.01 percentage points per destroyed enemy worm/turret
- +0.05 percentage points per newly occupied chunk
- Technology cap: off
- Session evolution report: off for each player

Tree absorption:
- Reads Factorio pollution statistics for `tree-proxy` (passive tree absorption) and
  `tree-dying-proxy` (extra pollution removed when pollution damages trees).
- At the default 100% credit, one pollution unit absorbed by trees cancels the same
  evolution pressure that one produced pollution unit adds after the configured
  `Pollution evolution` multiplier is applied.
- Existing historical tree absorption is NOT credited when this version is first
  installed/upgraded; the mod takes the current counters as a baseline and counts
  future absorption from that point.

A chunk counts as newly occupied only when a meaningful player structure first appears there
(e.g. production, mining, power, roboport, train stop, radar or defensive turret). Belts, pipes,
walls, rails and inserters do not count by themselves.

## Session evolution report

Enable **Show evolution change since joining** in per-player mod settings to see the
current evolution and how much each factor has changed it since you joined.
With Stats GUI installed, the breakdown appears there. Otherwise, the mod prints it
in chat every 10 game minutes. The report covers the current surface; moving to a
different planet starts a new baseline. The contributions are expressed in
percentage points and add up to the reported change in evolution.

## Technology cap

Enable **Limit evolution by researched technologies** in global mod settings to
cap evolution at `researched / total` for the player force's available finite
technologies. Hidden, disabled, and infinite technologies are excluded. With no
eligible technologies, this cap does not apply. Research completion or reversal
updates the cap immediately. The session report shows the current cap and its
effect on the change in evolution.

Do not use another evolution-overhaul mod at the same time.
