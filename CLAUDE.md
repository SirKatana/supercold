<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (60-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk go test             # Go test failures only (90%)
rtk jest                # Jest failures only (99.5%)
rtk vitest              # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk pytest              # Python test failures only (90%)
rtk rake test           # Ruby test failures only (90%)
rtk rspec               # RSpec test failures only (60%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
rtk uv run <cmd>        # Compact uv project command output
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%). Format flags (-c, -l, -L, -o, -Z) run raw.
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->

# SuperCold

Build plan for auto mode. Execute milestones in section 10 in order. The RTK block above applies to every shell command.

Status: the first unticked box in section 10 is the current milestone. If `project.godot` does not exist, nothing is built yet and work starts at M0.

## 1. Project

SuperCold. Godot 4.7.2, GDScript with static typing, Forward+ renderer, desktop Linux first.
Binary is `godot4` (there is no `godot` on PATH).
No external assets, addons, or downloads. Meshes from primitives, SFX synthesized in code.
Godot MCP calls take `projectPath` = `/home/yousif/Projects/Supercold`.

## 2. Core rule: time

Do **not** use `Engine.time_scale`. It makes physics ticks sparse in real time and the player choppy.
Use an autoload `TimeManager` exposing `world_scale: float` and `world_delta(delta) -> float`.

- Player runs on real delta, always full speed and 60 Hz responsive.
- Everything else (bullets, enemies, thrown items, shards, doors, timers, cooldowns) multiplies by `world_scale`.
- Nodes in group `time_scaled` get `speed_scale` / `pitch_scale` pushed each frame
  (AnimationPlayer, GPUParticles3D, AudioStreamPlayer3D).
- All world motion is kinematic and script-driven. No RigidBody3D anywhere.

Scale formula, evaluated every frame:

```
move   = clamp(horizontal_speed / WALK_SPEED, 0, 1)          # moving  -> 1.0
look   = clamp(mouse_deg_per_sec / 360, 0, 1) * LOOK_WEIGHT  # looking -> up to 0.30
burst  = strength of the action while its timer runs       # shot 0.22, throw 0.30, punch 0.55
target = max(MIN_SCALE, move, look, burst)
world_scale moves toward target: rise rate 12/s, fall rate 5/s
```

| Tunable | Value | Note |
|---|---|---|
| `MIN_SCALE` | 0.06 | Never 0. Bullet at 12 m/s crawls at 0.7 m/s, dodgeable |
| `LOOK_WEIGHT` | 0.30 | Looking around leaks a little time |
| Action burst | 0.12 s real | A nudge, never a snap to 1.0: shot 0.22, throw 0.30, break 0.40, punch 0.55, pickup 0.15. You must see your own bullet leave in slow motion |
| Rise / fall | 12 / 5 per s | Snappy start, soft settle |

Tuning is **compile-time**: scripts read it as `T.x` through `const T := preload(...)`, and GDScript folds that into a constant. Changing `tuning.tres` values at runtime has no effect on running code. Tests that need a different number use a static override on the class (see `Shield.deflect_chance_override`), never a write to the resource.

All tunables live in one resource: `res://data/tuning.tres` (script `tuning.gd`). No magic numbers in entity scripts.

## 3. Player

CharacterBody3D, capsule r 0.35 h 1.8, eye 1.6 m. WASD, mouse look, Space jump, no sprint, no crouch.
Walk 5 m/s, accel 40, jump 4.5, gravity 12. **One hit kills.** `R` restarts floor instantly, death auto-restarts after 0.6 s real.

| Input | Empty hands | Holding item |
|---|---|---|
| LMB | Punch | Shoot if pistol, else throw |
| RMB | Pick up targeted item | Throw |
| E | Pick up targeted item | Swap with targeted item |

- Punch: range 1.6 m, cooldown 0.4 s **world time**. First punch disarms, third kills.
- Pistol: 6 rounds, cooldown 0.35 s **world time**, so you must let time pass to fire again. Empty pistol is a throwable.
- Throw: 16 m/s, gravity 9.8, custom ballistic step with raycast. Hit enemy: stun 1.2 s world, 1 damage, disarm, weapon pops upward so player can catch it.
- Throwables: pistol, bottle, mug, keyboard, stapler. Fragile ones shatter on impact.
- Pickup targeting: raycast 2.5 m plus 12 degree cone assist. Catching a mid-air weapon is allowed.

## 4. Bullets

Not physics bodies. Each frame: `step = dir * 12 * world_delta`, raycast from old to new position.
The player's bullet leaves the pistol muzzle and flies to the point under the crosshair, never from the eye.
Radius 0.05, life 8 s world time, pink emissive tracer with trail mesh.
One bullet kills player or any pink dude (friendly fire on). Bullets are blocked by thrown items and doors,
and deal 1 damage to breakables.

## 5. Enemies: Pink Dudes

Jointed `Humanoid` rig (see section 6), emissive pink, no texture.
CharacterBody3D plus NavigationAgent3D. Move 3.2 m/s times `world_scale`. HP 3 versus punches and throws, any bullet kills.

FSM, one script per state under `enemies/states/`:
`Idle -> Alert -> Approach -> Aim -> Fire -> Reposition`, plus `Stunned`, `Disarmed`, `Dead`.

- Aim: telegraph 0.7 s world time, arm raises, thin pink laser line. Aims at player's **current** position, no lead, spread 1.5 degrees. This is what makes dodging work.
- Fire cadence 1.4 s world time. Needs line of sight, checked by raycast against layer 1 and 6.
- Disarmed: runs to nearest free pistol within 12 m, otherwise rushes to punch. Enemy punch kills player, 0.5 s world windup.
- Unarmed variant spawns without pistol and goes straight to rush.
- Dead: drops its gun and goes limp as a pink Ragdoll on world time, then shatters into shards.

Boss, **The Director**: 1.3x scale, dual pistols, 3 bullet hits to kill, alternates hands at 0.7 s cadence,
flinches 1 s after each hit and calls a wave of 4 dudes through rooftop doors.

## 6. World and breakables

- **Door**: HP 2. Punch 1, thrown item 2, bullet 1. Breaks into 6 panel shards that fly away from the hit and stun enemies they strike. Enemies open doors normally by walking into them.
- The door's look (`world/door.gd`): two hinged wooden leaves in a steel frame with a transom, `_model_frame` and `_model_leaf` via MeshKit. They swing up to `SWING` radians away from whoever is at the sensor (`_side_of_whoever_is_coming`). Each leaf breaks on its own: `leaf_hp`, `leaf_broken`, one collision half per leaf, `leaf_at(point)` picks the leaf (seam or no point on the door means both), `smash()` takes both (ram, explosions). The windows are real glazed openings (`WINDOW_SIZE`, `WINDOW_Y`); dudes still cannot see through a closed door. On `shatter` the frame is reparented to the level and stays. `--do=door [--dude=true]` captures it.
- **Ceiling**: a real `StaticBody3D` on the world layer, built outside `Nav`. A `Ragdoll` also clamps at `ceiling_y` and calls `knock()` on anything in group `hanging` within 1.6 m.
- **Chandelier** `h` (`world/props/chandelier.gd`): hangs at `wall_height`, swings as a pendulum on world time, rings the `jingle` sound when knocked. **No collision, ever**: it must never block a shot. Placed by `CHANDELIERS` in `tools/make_levels.py`.
- **Glass wall**: HP 1, blocks movement, not sight.
- **Elevator** (`world/elevator.gd`): a real cabin with steel frame, two sliding doors, a call button and digital floor screens outside and inside. The **exit lift is not there at all until the floor is clear** (`present`, `_set_present`: hidden, shell and door off their layers, sensor off, so nobody can ride out mid-fight). `Game.floor_cleared` makes it rise into place over `ARRIVE_SECONDS` with a ding. Then the button opens it, and the button reacts to a punch, a bullet or a thrown object. Step in, doors close, synthesized lift music plays for `elevator_ride_seconds`, next floor loads. The player starts every floor inside an arrival cabin, and stepping out flashes `LEVEL N` plus the intro text. Lifts run on **real time**, never world time. `P` and `X` sit against a wall so the cabin reads as built in. The roof exit is a `Helipad` (`"exit": "helipad"` in the sidecar).
- **Wall breaker** `r` (`weapons/ram.gd`, `world/wall_breach.gd`): black cylinder with two handles, held under the arm, LMB bashes. `ram_hits` = 5 bashes, then it cracks in half. A door costs 1, a wall cell costs `ram_wall_hits` = 2 (first cracks, second opens), a dude dies to one bash. Thrown at a dude it kills him and cracks in half. Outer walls and walls beside the void never break and cost nothing. A breach swaps the merged wall body for up to four smaller ones (`split_rect`), edits `data.rows`, and rebakes the navmesh on a thread. One ram each on F2 to F5.
- **Cold, wet, smelly** (states `enemies/states/frozen.gd`, `slipped.gd`, `choking.gd`; API on `PinkDude`: `freeze`, `slip`, `breathe_gas`, `on_laser`, `on_stabbed`, and `can_freeze` / `can_slip` / `can_choke`). **Freeze bomb** `F` (`weapons/freeze_bomb.gd`, `fx/freeze_blast.gd`): thrown or shot, freezes every dude within `freeze_radius` with a clear line for `freeze_seconds`; a frozen dude holds his pose in ice and **shatters to any hit**, shield troopers included (their shield goes limp). **Water** `~` and **ice** `i` (`world/puddle.gd`): a dude moving faster than `slip_speed` goes down, slides, lies flat, and loses his gun. The player never slips. **Water bucket** `j` (`weapons/water_bucket.gd`): one pour. Left click tips it out up to `pour_reach` ahead: every dude inside `spill_radius` slips at once even if standing still, and it leaves a round timed `Puddle` (`radius`, `life`) that dries after `spill_seconds` (90 **real** seconds) and makes any dude running through it slip. Thrown full it splashes where it lands. Empty, left click just throws it. On about ten floors. **Fart grenade** `f` (`weapons/fart_grenade.gd`): a pickup on a stand. Thrown, it goes off on its first impact; a bullet sets it off where it lies. It calls `FartCloud.release`, which is the only way fog appears now: **floors place no loose clouds**, the user wanted the fart to come from a grenade. **The fog** (`world/fart_cloud.gd`) is green **fog**, drawn as 72 soft radial-gradient billboard puffs (16 while small), low to the floor, with proximity fade and a distance fade so puffs at the lens vanish; burst puffs are drawn at about 10 percent each or they stack into a solid sheet. A choking dude drops his gun, puts **both hands to his throat** (`Humanoid.two_bone` arm solve, `clutch`), **doubles over** further the longer he breathes it (`bend`), gags (`choke` sound every 0.95 s) and dies folding forward with a last wheeze (`choke_die`). It drifts on the navmesh; shoot, punch, stab or hit it and it fills a room for `fart_big_seconds`; a dude who breathes it for `fart_kill_time` dies, one who gets out recovers; gas masks (troopers), biters and bosses are immune; the player only gets a green screen. **Knife** `n`: one stab kills, armour turns it. Bosses ignore all three effects (the Brute and Warden are only staggered by a freeze bomb).
- **Water** (`fx/water.gdshader`, `Mats.water()` for a wet film, `Mats.water_deep()` for the pool): per-pixel ripples from six wave trains evaluated on world position (so a flat quad ripples), refraction of the screen texture, Beer's-law colour against real scene depth, edge foam, fresnel toward the sky colour, caustics on the bottom, glints from the lights. The depth reconstruction has a `RENDERER_COMPATIBILITY` branch, keep it. Time is the **global shader uniform `world_time`**, declared under `[shader_globals]` in `project.godot` and set every frame by `TimeManager`, so water slows with the world. **Deep water** `W` (`world/deep_water.gd`): the floor is built as slabs with the pool cut out (`LevelBuilder.cell_rects`), thick enough that their sides are the pool walls; the tiled bottom is deliberately **not** under the navmesh parent, so dudes never path across it. The player sinks, holds jump to swim up, and jump against the wall at the surface hauls him out; the HUD goes blue and wobbles under water. A dude in it drowns.
- **Death styles**: `PinkDude.die(at, push, style)` with `&"ragdoll"` (falls on world time, then shatters), `&"ice"` (frozen: shatters at once, no ragdoll), `&"melt"` (`fx/melt.gd`: no ragdoll, the body sags where it stood, glows, spreads into a puddle that stays). Any subclass that overrides `die` must take and pass on `style`.
- **Spear** `L` (`weapons/spear.gd`): two-handed, `spear_range` 3.2 m thrust that kills, or thrown. **Crossbow** `A` (`weapons/crossbow.gd`): `crossbow_ammo` bolts, slow, pierces `crossbow_pierce`, and `Gun.silent` so firing it raises no alarm; it is the only quiet gun.
- **More guns**: `Smg` `M` (24 rounds, very fast, sprays), `Revolver` `V` (5 rounds, each pierces 2 dudes), `SniperRifle` `Y` (4 rounds, 3x speed, pierces 4, **hold right click to scope**: FOV `scope_fov`, mouse slowed to match, `fx/scope.gdshader` reticle, shot goes exactly down the camera; **Q throws** any held item because right click is taken), `SuperGun` (laser: instant, through every dude and every shield in line, melts them; walls stop it; `super_charges` per level). Bullets carry `pierce_left` and `speed_scale`; a round launched with pierce also passes loose pickups, or a dead dude's falling gun would stop it. `SuperGun.fire` uses duck typing (`has_method`), never class names: `PinkDude.create_gun` makes it, and naming `PinkDude` back creates a dependency loop GDScript reports only as "could not parse global class".
- **More dudes**: `Runner` `q` (hot pink, unarmed, 6.4 m/s, no cover), sniper dude `N` (long telegraphed aim, fast round, keeps his distance), SMG dude `U`, `Knifeman` `x` (burnt orange, 5.4 m/s, `knifeman_reach` 2.1 m, throws the blade after `knifeman_throw_wait` out of reach and drops one when killed), `Spearman` `y` (violet, slow, `spearman_reach` 3.4 m, drops his spear), `Cloner` `C` (mint white, unarmed, keeps `cloner_keep_away` away and makes pale one-hit copies every `cloner_interval`, `cloner_at_once` alive and `cloner_budget` in all; copies never copy, are counted by `Game.count_new_enemy`, and **all pop when he dies**). A dude who will not rush when unarmed returns false from `fights_hand_to_hand()`, which Alert and Approach honour. The biter is gone: never bring back `Z` or a buried enemy, `initial_enemy_count` counts every spawn now.
- **Bosses** are in group `bosses` and expose `boss_name()` and `boss_health()` for the HUD bar. **Brute** (level 10, `enemies/brute.gd`): 1.75x tall, 1.55x bulk via `Humanoid.bulk`, shotgun, 12 hits, calls a wave at each third, overhead slam kills inside `brute_slam_range`; laser 3, blast 4, ram 2, knife 1. His death calls `Game.grant_super_gun`: `has_super_gun` is saved and the player starts every later floor holding a charged one. **Warden** (level 21, `enemies/warden.gd`): giant shield trooper, the glass takes `warden_glass_hits` (3); the shield asks its holder before breaking its glass. **Director** (level 30) unchanged.
- **Testing shortcuts** (`main.gd._start_test_run`): a bare number 1 to 30 on the command line starts on that level, `--helper=true` hires the helper for free (`Game.give_free_helper`, re-hired on every floor via `Game.free_helper`), `--god=true` cannot die. `main.gd._arg` reads both the engine's argument list and the one after `--`. Such a run sets `Game.testing`, which makes `save_progress` a no-op, and grants the super gun from level 11.
- **Progress**: `user://progress.cfg` holds `best_floor` and `has_super_gun`. Title screen offers CONTINUE and NEW GAME.
- **Helper for an ad** (`world/helper_capsule.gd`, `allies/helper.gd`, `autoload/ad_service.gd`): die `helper_deaths_needed` (3) times on one floor and the next respawn finds a glass capsule outside the lift with a red humanoid turning slowly inside. Its button takes a bullet, a punch or a thrown object and calls `AdService.show_rewarded()`. The ad is a house ad for the user's other game, **The Last Ward**: `res://ads/the_last_ward.ogv`, 57 s, converted from the mp4 in the project root (Godot plays Theora only, never mp4). The game pauses behind it. The reward is earned at `ad_reward_after` (20 s); closing sooner earns nothing and the button can be hit again. Reward: the capsule bursts and a red `Helper` with an AK steps out for `helper_seconds` (240 **real** seconds, four minutes, shown top right). He follows the player, leads his shots, aims for the glass on shield troopers, never fires with the player near his line, and bullets stop on him harmlessly. He survives the player's death and restart with his remaining time, and leaves when time runs out or the floor is cleared. A new floor resets the death count. Allies are physics layer 9. Tests and the smoke bot set `AdService.auto_result` so no video plays. A real ad network would be one more backend inside `ad_service.gd` ending in `_finish(bool)`.
- **Helper voice** (`allies/helper_voice.gd`): a billboard speech bubble over his head plus the same line spoken from a **pre-rendered clip**. Lines live in `allies/voice_lines.json`; `tools/make_voice.py` renders them once with Piper (open-source neural TTS) and the CC0 voice `en_US-joe-medium` into `allies/voice/<id>.ogg`. Nothing online at runtime, no API, no key. Callouts are chained from clips (name, clock hour, distance). Never scrape a web TTS endpoint. The system TTS voice is only a fallback for a line with no clip, and tests fail if any line lacks one. Lines: the greeting "Hey, I'm your helper for 3 minutes!", a complaint when a bullet hits him (rate limited, with a flinch), one callout per dude in the player's terms ("Rifleman, 3 o'clock, 10 metres, sector C1!", plus "Aim for the glass!" for troopers), kills, "you're in my line of fire", a red barrel tip, one minute and ten second warnings, and a goodbye. Priorities `CHATTER < CALLOUT < IMPORTANT` stop him talking over himself. Bubble timing is real time. `HelperVoice.tts_enabled = false` in tests and the smoke bot.
- **Shield trooper** `H` (`enemies/shield_dude.gd`) and **Shield** (`weapons/shield.gd`, `shield_plate.gd`): a slow dude behind a black SWAT shield who never hides. Shield plate and his body armour stop every bullet; the only bullet that kills him is one through the glass viewport (`VISOR_Y` 1.62 m). Blunt hits and the ram only stagger him, an explosion kills him. Every bullet that strikes a shield or his armour has `shield_deflect_chance` (one in three) of ricocheting: the handler returns `true`, `Bullet` bounces, loses its shooter and can kill anyone. On death the shield drops flat. **F** (`use_shield`) wears the nearest dropped shield on the left arm or drops it; the gun hand stays free. Worn, the visible plate sits left of the crosshair while its collider is widened to 1.05 m to cover the chest. Bullets skip whatever their shooter returns from `bullet_excludes()`. Shields are physics layer 8.
- **Gas barrel** `g` (`weapons/gas_barrel.gd`, `fx/explosion.gd`): red drum with hoops, bungs, a yellow fire diamond and FLAMMABLE GAS lettering. Solid at rest, can be picked up and thrown. A bullet, a thrown impact, or a neighbouring blast sets it off. `Explosion.detonate` kills every dude inside `barrel_radius` (5.5 m) including shield troopers, costs the Director one hit, kills the player inside `barrel_player_radius` (3.6 m), breaks doors and glass, and cooks off other barrels after a short fuse. **Walls block the blast** (one ray on layer 1). The effect runs on world time: flash, fireball, flame tongues, shockwave ring, grey smoke, embers, light, debris, scorch mark, camera shake.
- **Guns** (`weapons/gun.gd` base, `pistol.gd`, `rifle.gd`, `shotgun.gd`): every gun is a `Gun` with ammo, capacity, world-time cooldown, `automatic`, `pellets`, `spread_deg`, `two_handed`, `muzzle_local`. AK-47 `K`: 30 rounds, hold the trigger, 0.10 s cycle. Shotgun `T`: 5 shells, 8 pellets in a 5.5 degree cone, 0.85 s pump. Dudes `R` (rifle, 3-round bursts) and `S` (shotgun, 5 pellets, must close to 10 m) use `set_enemy_held(true)` for gentler numbers; the gun goes back to player numbers when it leaves their hands.
- **Gun models** are built in `_model(kit: MeshKit)`. `MeshKit` (`fx/mesh_kit.gd`) transforms every primitive on the CPU and merges them per material into one cached `ArrayMesh`, so the 150-part AK is one MeshInstance3D. Never add per-part MeshInstance3D nodes to a gun. -Z is the muzzle, stocks drop with a **positive** X rotation, grips rake with a negative one.
- **Bullets** are a black modelled round (tip, ogive, bearing surface, brass band, boat tail) with a tapered pink emissive trail. Pellets are the same mesh at scale 0.6.
- **Humanoid** (`fx/humanoid.gd`): one 21-joint body for dudes, the player and every ragdoll. Tapered limbs plus a visible ball at each joint. `Humanoid.pose(walk_phase, walk_amount, aim_right, aim_left, stagger)` is forward kinematics (knees only bend backwards, lower foot planted, limb lengths exact), `apply(joints)` lays the parts between world joint positions. Dudes hold guns on a `hand_anchor` placed in the palm each frame. The player's own body hides its head and arms; the first-person arms stay a separate viewmodel.
- **Carry-over and security**: whatever is in the hand when the lift leaves rides up with you (`Pickup.carry_state()` / `apply_carry_state()`, `Game.carried`, `_hand_back_what_was_carried`). If it `is_weapon()` (guns, knife, ram, freeze bomb, fart grenade; not the super gun, bottles, mugs or the bucket) it arrives flagged `contraband` and `Game._post_guard()` stands a `SecurityGuard` (`enemies/security_guard.gd`, navy suit, cap, vest, shades, deep `guard_*` voice lines) up to `guard_distance` down the corridor. **You throw it to him** (Q): a contraband weapon in flight within `guard_catch_range` of his chest is caught. He never takes it out of the hand, standing next to him does nothing. One dropped elsewhere he walks to on the navmesh (mode `FETCHING`, real time, `guard_fetch_speed`) and picks up within `guard_floor_reach`; then he walks back into the lift and leaves. Pass his post by `guard_line` still armed, shoot him, or fire the contraband gun and he opens fire (`guard_cadence`, led shots, only with line of sight) **and chases** on world time at `guard_chase_speed` (5.8, faster than the player's 5.0, so running does not work), closing to `guard_chase_keep`. He stops only when the weapon leaves the hand. Doors open for layer 9 too (`Door` sensor mask `4 | 256`). He is on layer 9 (allies), is not an enemy, and never blocks floor clear. `Game.load_level` sets `State.PLAYING` before building, otherwise a new floor inherits CLEARED and its lift tries to arrive mid-construction.
- **Shelving and pillars**: a north-south run of rack cells `s` is one `Shelving` body and one cached mesh (`Furniture.shelf_mesh(cells, level_name)`): bookshelves, or steel stores shelving on the floors in `Furniture.STORAGE_FLOORS`. Pillars `o` are dressed with a stone base and head over the same 1.1 m box. `--do=view --cell=x,y --look=x,y` stands on a cell and looks at another.
- **Furniture and junk**: desks `c` and item pedestals are dressed by `Furniture.dress` (`world/props/furniture.gd`) over the same fixed collision box: never make them pickups or breakables, the user wants them indestructible. Surface 0 of a furniture mesh is the themed panel colour. Throwables: `bottle` is a tumbler, `keyboard` is a tablet, `mug` is a mug (`weapons/throwable.gd`, MeshKit models, no brand marks). Desk monitors show the promo: `MonitorFeed` (`world/props/monitor_feed.gd`) is one muted, looping, `time_scaled` `VideoStreamPlayer` whose texture every screen shares; the loop `world/props/monitor_loop.ogv` has no audio track and is remade by `tools/make_promo.sh`. `--do=props` lines them all up for a capture, `--monitor=true` sits at a desk. `Settings.sunglasses` (pause menu) turns the glasses off for dudes and the guard.
- **The cleaner** (`enemies/cleaner.gd`, `world/wet_floor_sign.gd`): on call on every floor whose data has a `bucket` or a `mug` (`Game.floor_has_a_cleaner`). Anything spilled calls `Game.report_spill(puddle)`: a poured or thrown bucket, and a smashed mug, which now leaves a coffee `Puddle`. He comes out of the arrival lift's mouth, mops (`Puddle.mop_up`), leaves a `WetFloorSign`, and walks back. `Game.spills_this_floor` resets per floor; on spill `cleaner_strikes` (5) he turns hostile, switches from layer 9 to the enemies layer, hunts and kills with a broom swing. **He cannot be killed and being hit never makes him attack**: every hit handler goes to `_outraged(who, came_from)`, which stops his work for about a second, turns him to face the shooter (a bullet's `shooter`, a thrown item's `thrower`), shakes his fist, says `cleaner_why` ("WHY!", at most every 1.5 s) and emits `outraged`. If he is already hostile a hit staggers him for 1.2 s. `cleaner_chase_speed` stays below `walk_speed` on purpose. Never in group `enemies`, never blocks floor clear, group `cleaners` (explosions check it). Voice lines `cleaner_*`. `--do=cleaner [--angry=true] --at=1.2` captures him (later than about 4 s he has already gone), `--do=sign` the wet floor sign. His clothes use `Humanoid.set_group_material` (shirt on torso and arms, trousers on legs, pink head); his mop bucket is a `top_level` child that follows him. Check any new character from the side and back, not only front-on.
- **Sunglasses**: every pink dude wears black wraparound shades (`Humanoid.set_sunglasses`, `shades_mesh`; `PinkDude.wears_shades()`, false only for the biter). They ride on the skull at true scale in `Humanoid.apply` and stay black when he is frozen. On any death (`_lose_shades`) they come off as a `Debris` in group `lost_shades`, fly, clatter to the floor and lie there 20 s; the ragdoll, ice and melt bodies have none. The player's body and the helper do not wear them.
- **Ragdoll** (`fx/ragdoll.gd`): what any Humanoid becomes when it dies, seeded from the exact pose it died in. The player's runs on real time; a dude's runs on **world time** (it hangs mid-fall while you stand still) and bursts into shards after `dude_ragdoll_shatter` seconds. 21 joints (head, neck, chest, spine, pelvis, shoulders, elbows, wrists, hands, hips, knees, ankles, toes). It is a Verlet point-and-constraint simulation, **not** RigidBody3D, so the no-RigidBody rule still holds. Joint limits are min and max distances across each joint. The ground clamp must stay inside the solver loop or limbs stretch. Runs on real time times `ragdoll_speed`, the camera detaches and pulls back to watch, restart comes after `death_restart_delay` or R.
- **Pillar** `o`: full-height 1.1 m cover. Every floor needs at least 4, enemy spawns stay 4 cells apart and 6 from the player. Tests enforce both.
- Collision layers: 1 world, 2 player, 3 enemies, 4 pickups, 5 bullets (raycast mask only), 6 breakables.

## 7. Levels: data-driven

Floors are ASCII grids, 2 m cells, wall height 3 m, in `res://levels/fN_name.txt` with sidecar `fN_name.json`
for waves, trigger zones, and intro text. `LevelBuilder` turns the grid into merged StaticBody3D wall and floor
boxes, instantiates prefabs, then bakes the NavigationRegion3D at load from static colliders.
Keep `NavigationMesh.geometry_parsed_geometry_type` on static colliders. Mesh parsing returns nothing under `--headless`, which would break the reachability tests.

Legend: `#` wall, `.` floor, `D` door, `G` glass, `P` player start, `X` elevator exit, `a` armed dude,
`u` unarmed dude, `w` wave spawn point, `p` pistol, `b` bottle, `m` mug, `k` keyboard, `c` desk cover,
`s` server rack, `t` trigger zone id follows in json.

**30 levels** in `Game.FLOORS`, all generated by `tools/make_levels.py` (edit the script, never the `.txt`). Each has a sidecar with `title`, `intro`, `theme` (wall, floor, prop, ambient, sky, energy, sun: applied by `LevelBuilder.apply_theme` and `main.gd._apply_theme`), optional `waves`, `boss`, `exit`, `open_sky`. Every floor from 6 up has its own colours; a test fails if two share them.

| Levels | What is there |
|---|---|
| 1 to 5 | Lobby, Offices, Server Room, Labs, Executive. The original white HQ |
| 6 Cafeteria, 7 Parking, 8 Archive, 9 Pool | water spills and knives, pillars and barrels, runners in the stacks, a pool and the first freeze bomb |
| **10 The Vault** | boss: **the Brute**. Reward: the super gun |
| 11 Sewers, 12 Kitchen, 13 Cold Store, 14 Glassworks, 15 Restrooms | biters, knives and gas, an all-ice floor, snipers and the scope, **fart clouds** |
| 16 Armoury, 17 Greenhouse, 18 Beanworks, 19 Trading Floor, 20 Generators | every gun, biters in the soil, **fart clouds** and vats, a huge open floor with waves, barrel chains in the dark |
| **21 Lockdown** | boss: **the Warden** |
| 22 Cryo Lab, 23 Hall of Glass, 24 Strongrooms, 25 Sky Garden | freeze bombs on ice, glass everywhere, doors and the ram, open sky and snipers |
| 26 Morgue, 27 Furnace, 28 Waterworks, 29 Penthouse | twelve biters, twelve barrels, water with dry walkways, everything at once |
| **30 Roof** | final boss: **the Director**, helipad exit, ending |

**Floors are buildings, not halls.** The user rejected open rooms with a lattice of pillars ("straight lines and tall cubes"). Every floor from 6 to 29 is corridors, rooms off them and doors between, like floors 1 to 5. In `tools/make_levels.py`: a layout (`layout_spine` one corridor with rooms both sides and sometimes a back room behind a front one, `layout_double` two corridors and three bands of rooms with a cross passage, `layout_bsp` the whole floor cut into rooms with a door or two on every wall), then dressing from a `SPECS` entry: `furnish` (office, racks, tables, counters, stalls, vats, slabs, columns: always one cell clear of the walls so rooms can be walked round and doors are never blocked), `patch` (wet or icy rooms and corridors), `glass_front`, corridor `_buttresses` for cover, then `scatter` for enemies, items, fart clouds and wave points. `walkable_from_lift` flood-fills from the lift and the generator retries the next seed until every enemy, wave point and the exit is reachable and there are at least 12 pieces of cover. Levels 9 (pool hall and changing rooms), 10 (vault with strongrooms) and 21 (cell block) are hand-built the same way. Never go back to `pillars()` lattices in open rooms.

`tools/make_levels.py` has one string, `ENEMIES`, that decides what the scatter spaces apart and what `check_spacing` checks. Any new dude character must go in it, or the floors quietly pack them on top of each other.

**Gadget distribution** is one table, `GADGETS` in `tools/make_levels.py`: which floors get fart grenades `f`, freeze bombs `F` and water buckets `j`, and how many. It is uneven on purpose, the user asked for that: seven floors have none (2, 4, 7, 14, 20, 24, 27), most have one or two kinds, only 16 and 29 have all three. `Grid.gadgets()` scatters them at least 6 cells from the lift, at least 4 from each other, spanning half the floor's width, and is called for generated and hand-built floors alike. Never place these three with a fixed `g.put`, and never put them in a spec's `items` or `start` (they are stripped). Seeds for hand-built floors are a sum of character codes, because Python's `hash()` changes every run. `tests/test_gadgets.gd` enforces all of it.

Legend additions: `f` fart grenade, `j` water bucket, `q` runner, `Z` buried biter, `N` sniper, `U` SMG dude, `n` knife, `F` freeze bomb, `M` SMG, `V` revolver, `Y` sniper rifle, `~` wet floor, `W` deep water, `i` ice.

Validator rule: every enemy and the exit must be nav-reachable from `P`. Test fails otherwise.

## 8. Look, feel, UI

- World: white and light grey, unshaded-ish StandardMaterial with soft ambient, glow enabled. Enemies and bullets emissive pink `#ff2d95`. Weapons and pickups matte black.
- Slow-mo feedback: screen-space shader with vignette and slight desaturation driven by `1 - world_scale`. Audio pitch follows `world_scale`, floor 0.35.
- HUD: crosshair dot, ammo pips, nothing else. Big centered word flashes on floor clear: `SUPER` then `COLD`.
- Title screen, pause menu with mouse sensitivity, FOV, volume. Settings saved to `user://settings.cfg`.
- SFX synthesized into AudioStreamWAV at boot by `audio/sfx_synth.gd`: shot, shatter, punch, pickup, door break, elevator ding.

## 9. Layout

```
project.godot          data/tuning.gd, tuning.tres
autoload/              time_manager.gd  game.gd  sfx.gd  settings.gd
player/                player.tscn  player.gd  hands.gd  camera_fx.gd
weapons/               pistol.gd  bullet.gd  bullet_pool.gd  throwable.gd  pickup.gd
enemies/               pink_dude.tscn  pink_dude.gd  director.gd  body_builder.gd  states/*.gd
world/                 level_parser.gd  level_builder.gd  door.gd  glass.gd  elevator.gd  props/*.gd
fx/                    shatter.gd  trail.gd  slowmo.gdshader  materials.gd
audio/                 sfx_synth.gd
ui/                    hud.tscn  title.tscn  pause.tscn  word_flash.gd
levels/                f1_lobby.txt/.json ... roof.txt/.json  test_room.txt
tests/                 run_tests.gd  test_*.gd  smoke_bot.gd
main.tscn              docs/DECISIONS.md
```

Scene rule: every `.tscn` holds only a root node plus its script. Children are built in `_ready()` by code.
This keeps hand-written scene files trivial and diffable. Use Godot MCP `create_scene` or write the 5-line text form.

## 10. Milestones

Work in order. One milestone at a time. Tick the box here when its acceptance passes.

- [x] **M0 Bootstrap.** `rtk git init`, `.gitignore` with `.godot/` and `build/` (keep `.rtk/` tracked), `godot4` filter in `.rtk/filters.toml`, `project.godot` with input map, layer names, autoloads, 1280x720 window, mouse capture. Own test runner, no GUT. *Accept:* headless test command exits 0 with 1 dummy test.
- [x] **M1 Time and player.** `TimeManager`, tuning resource, player controller, `test_room.txt`, slow-mo shader, debug overlay showing `world_scale`. *Accept:* unit tests for scale formula, rise, fall, min clamp. Standing still reads 0.06, walking reads 1.0.
- [x] **M2 Combat kit.** Pickup, pistol, pooled bullets, throw, punch, action bursts, HUD ammo. *Accept:* tests for bullet stepping never tunnelling a 0.1 m wall at scale 1.0, ammo count, world-time cooldown, thrown item blocking a bullet.
- [x] **M3 Pink dudes.** Body builder, FSM, nav, aim telegraph, fire, stun, disarm, weapon seek, shatter, player death and restart. *Accept:* FSM transition tests. In test room, 3 dudes fight, die, drop pistols, and no errors in debug output.
- [x] **M4 World.** Level parser, builder, navmesh bake, door, glass, elevator, floor flow in `game.gd`. *Accept:* parser tests, door HP table test, reachability validator passes on test room.
- [x] **M5 Floors F1 to F5.** Author grids and json, waves, triggers, intro text, title, pause, settings. *Accept:* every floor loads headless, validator passes, smoke bot survives 10 s per floor with zero script errors.
- [x] **M6 Boss.** Roof arena, Director, waves, ending screen. *Accept:* Director takes exactly 3 bullets, wave spawns after each flinch, ending triggers.
- [ ] **M7 Juice.** *(all features done; only the perf bar is open: 2 to 8 frames in about 1190 ran 17 to 31 ms, re-measure needs a real window and the user's OK)* Synth SFX, pitch follow, trails, shard polish, word flash, camera kick, hit pause of 0.05 s real on kill. *Accept:* no frame over 16 ms with 12 dudes and 40 bullets on F5, checked via `Performance` monitor in smoke bot run **without** `--headless`, since headless renders nothing.
- [x] **M8 Balance and ship.** Tuning pass, Linux export preset, `build/SuperCold.x86_64`, README with controls. *Accept:* exported binary boots to title.

## 11. Verification loop, every milestone

The RTK block above governs every command here. Godot has no built-in RTK filter, so use the generic wrappers:

```bash
rtk test godot4 --headless --path . -s tests/run_tests.gd    # unit tests, failures only, exit code is pass/fail
rtk test godot4 --headless --path . -s tests/smoke_bot.gd    # loads each floor, scripted input, fails on any error
rtk err godot4 --headless --path . --import                  # reimport after adding files, errors only
rtk proxy godot4 --headless --path . -s tests/run_tests.gd   # unfiltered, only when a filter hides something needed
```

Test runner output contract, so `rtk test` and the project filter work: one line per failure as
`FAIL <file>::<test> <message>`, a final line `TESTS <passed>/<total>`, exit code 1 on any failure.

M0 adds this to `.rtk/filters.toml` to drop engine banner noise on any other `godot4` call:

```toml
[filters.godot4]
description = "Compact Godot headless output"
match_command = "^godot4\\s"
strip_ansi = true
strip_lines_matching = ["^\\s*$", "^Godot Engine v", "^Vulkan", "^OpenGL", "^\\s*--- "]
max_lines = 60
on_empty = "godot4: ok"
```

Headless gotchas:

- A `-s` entry script compiles before autoloads exist. It must not name any class that refers to `Game` or `TimeManager`; `load()` such scripts at runtime. A compile failure there never reaches `quit`, so Godot hangs.
- Scripts run with `-s` must `extends SceneTree`, do their work in `_initialize()`, and end with `quit(code)`. Without `quit` the process hangs.
- Run the `--import` command once after a fresh clone and after adding any new `class_name` script. Otherwise tests fail with "Could not find type" because `.godot/` class cache is stale.
- After adding collision bodies in a test, `await physics_frame` twice before any `direct_space_state` raycast, or the query sees an empty world.
- Autoloads exist under `-s`, but are not ready inside `_init()`. Touch them from `_initialize()` onward.

**Web build**: `rtk proxy tools/make_web.sh` exports the `Web` preset (no-threads template) to `build/web/` and `tools/inline_web.py` folds it into the single file `web/index.html` (about 65 MB, runs from `file://`). `web/` is output only, git-ignored, has a `.gdignore`, and must stay deletable: never put sources there and never reference it from the project. Check it without a window: `node tools/web_check.mjs file://$PWD/web/index.html out.png 25 12` with `CLICK_Y=462` to press NEW GAME; it prints the page's console. No threads on web: guard any threaded call with `OS.has_feature("web")`. A capture mode also runs in the web build: bake the arguments into `GODOT_CONFIG.args` of a copy of the page (`"--","--level=...","--shot=x","--do=doorbreak"`), run the checker with `WAIT_FOR=CAPTURE_READY`, and the picture is taken when `main.gd` prints that. It renders on software WebGL only; the real GPU is not reachable headless, so GPU-specific glitches cannot be seen from here. **Web performance**: browsers have no occlusion culling and draw calls are dear, so `PinkDude.cull_unseen` (true on web) stops drawing and posing a dude no camera ray can reach; anything that reads `joints` or a hand anchor of a dude must call `ensure_pose()` first. `--perfprint=1` prints fps, script time and draw calls once a second, in the web build too. Web-only render overrides live in `project.godot` as `.web` keys (MSAA off, no HiDPI). Do not add `scaling_3d/scale.web`: it striped the walls. In the web build `MeshKit.colour_merge` folds each model's plain materials into one vertex-coloured surface (one draw call); draw calls are what costs in WebGL, not scripts, so keep new models to few non-plain materials. `--perfprint=1` takes `--norender --novideo --nodudes --nosound --nohud` to isolate costs. The boot splash is `ui/splash.png` from `tools/make_splash.py`. `Shatter.plain_meshes` (true on web) draws shards as plain meshes instead of a MultiMesh.

**Promo video**: `rtk proxy tools/make_promo.sh` renders `promo/out/supercold_promo.mp4` offscreen (song from `tools/make_song.py`, scene `promo/dance_party.tscn`, stills with `tools/promo_shot.sh out.png <second>`). `promo/` is not part of the game: excluded from both export presets, never referenced by game code.

**Never open a game window on the user's desktop** for checks, captures, the smoke bot, or perf runs, unless
the user asks. That rules out Godot MCP `run_project` and the `game-development` skill's `shot`. Instead:

```bash
rtk proxy tests/run.sh [test_file_basename]        # unit tests, exit code is Godot's own, gate every commit on it. NEVER pipe it (`| tail` hides the exit code): `tests/run.sh && git commit`
rtk proxy tools/shot.sh out.png <level> <seconds>  # one frame on a hidden Xvfb display, then Read the png
rtk proxy tools/shot.sh out.png test_room 1.5 --do=punch   # also --do=hold
```

`tools/shot.sh` uses the OpenGL compatibility renderer on llvmpipe, so colours differ a little from Forward+.
For anything about glow, bloom, exposure or SSAO use `rtk proxy tools/shot_vk.sh out.png <level> <seconds> [args]`: the same capture with the real Forward+ renderer on software Vulkan (slow, still no window). The elevator white-out was invisible in `shot.sh` and obvious in `shot_vk.sh`. `--do=cabin --step= --yaw= --pitch=` looks around inside the arrival lift. Tests and the smoke bot call `Settings.use_defaults_for_tests()`: never let a test read or write the player's `user://settings.cfg`.
Frame-time numbers need the real GPU and a real window: ask the user before running
`godot4 --disable-vsync --path . -s tests/smoke_bot.gd -- --perf --floor=f5_executive`.
Never claim a milestone done without the test output in hand.

## 12. Auto mode rules

- Do not stop to ask. Pick the simplest option that fits this plan and log it in `docs/DECISIONS.md` with one line of why.
- Commit after each passing milestone: `rtk git add -A && rtk git commit -m "M<n>: <summary>"`. No push, no remote.
- Never edit anything between the `rtk-instructions` markers in this file. Progress ticks and plan changes go below them only.
- Every shell command uses the `rtk` prefix per the RTK block. File reads and searches use `rtk read`, `rtk grep`, `rtk find`, `rtk ls`.
- Never add addons, downloaded assets, RigidBody3D, or `Engine.time_scale`.
- Static typing everywhere. Signals over polling between systems. One class per file, `class_name` set.
- If a Godot 4.7 API differs from what this plan assumes, check docs through Context7, adapt, log it.
- If a milestone's acceptance fails three fix attempts in a row, write findings to `docs/DECISIONS.md`, leave the box unticked, and stop.

- After M8 is ticked, move sections 2 to 9 into `docs/DESIGN.md` and leave only rules, commands, and gotchas here. This file loads into every session.

## 13. Stretch, only after M8

Real-time replay of the cleared floor, endless mode on a random floor, katana, shotgun dudes, gamepad support.
