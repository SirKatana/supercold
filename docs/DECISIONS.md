# Decisions

One line per call made in auto mode, with why.

- M0: added physics layer 7 `flying_items`. Bullets must be blocked by thrown items but not by resting pickups, and a separate layer is the cheapest way to tell them apart.
- M0: accent colour `#7fe8ff` (cold cyan) for the elevator and interact highlights. White, pink and black alone gave no way to mark "go here".
- M0: `godot4 --headless --import` always prints `ERROR: Parameter "singleton" is null ... is_cmdline_mode`. It is engine noise from the editor bootstrap, exit code is 0, ignore it.
- M0: verified autoloads and the `Logger` API work under `-s`. The test runner installs a Logger and fails any test during which the engine logs an error.
- M1: frames are captured by the game itself (`godot4 --path . -- --shot=<png> --shot-after=<s> --level=<name>`), not by the desktop screenshot tool in the game-development skill. It needs no window focus and sends no keystrokes to the user's desktop.
- M1: level parser and the wall/floor/prop part of the builder were pulled forward from M4, because the M1 test room is already an ASCII level.
- M1: added legend characters `B` (boss spawn), `l` (stapler) and space (void, no floor). The plan's legend had no way to place the Director or the stapler.
- M1: time only advances from real horizontal velocity, so pushing into a wall does not move the clock.
- M1: `tests/run.sh` wraps the test command so the exit code is Godot's and not a pipe's. An M1 commit went in with one failing test because `| tail` hid the code. Always gate commits on `tests/run.sh`.
- M1: tests run with `--fixed-fps 60`, which removes real-time waiting and makes timing deterministic.
- M2: pickups are `Area3D` with a sphere shape, not bodies. They never need to block movement, and a bullet ray can still hit them through `collide_with_areas`.
- M2: placed pickups sit on a 0.9 m pedestal. A black pistol lying on a grey floor was hard to spot and hard to aim at.
- M2: a thrown item is `dangerous` only until its first impact, and a weapon knocked out of a hand is never dangerous. Otherwise bounces would stun twice and dropped guns would hurt people.
- M2: enemies fire without spending ammo (`fire(..., spend=false)`), their dropped pistol carries `enemy_drop_ammo` rounds.
- M2: with no level loaded, `Game.entities_root()` falls back to the caller's parent, not the tree root. Thrown items leaked between unit tests otherwise.
- M3: navmesh baking pulled forward from M4, dudes cannot move without it.
- M3: glass sits on layers 1 and 6. Layer 1 makes it carve the navmesh so dudes never path into a pane; `Sight` skips anything in group `see_through` so it still does not block vision.
- M3: unaware dudes only notice the player inside a forward cone or within 5 m, and gunfire alerts everyone within `dude_hearing`. Without this every dude on a floor woke up at once.
- M3: dudes do not collide with the player or each other (mask is world and breakables only). CharacterBody pushing caused jitter, and rushers stop at punch range anyway.
- M3: `Game.god_mode` (`-- --god=1`) exists for tests, the smoke bot and frame captures.
- M4: no `filter_baking_aabb` on the navmesh. Clipping the bake volume below wall height made every wall a low walkable platform and paths ran straight through them. Wall and prop tops are unreachable islands instead.
- M4: `LevelValidator.wait_until_synced()` polls until the nav map owns this level's region. A fixed frame count was not reliable after a level swap.
- M4: doors slide open for dudes via an `Area3D` sensor, and are not part of the navmesh (layer 6 only), so paths run through doorways.
- M4: every door cell gets a lintel on layer 1 above the 2.6 m panel so the opening reads as a doorway.
- M4: breaking a door gives an action burst, same as a punch, so the panels visibly fly.
