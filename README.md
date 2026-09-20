# SuperCold

A first-person time-shooter. Time crawls while you stand still, slow enough to step
around bullets, grab what is lying about, and break doors down. Move and the world
moves with you. One hit kills you. One bullet kills them.

Climb a corporate HQ full of evil pink dudes with pistols: Lobby, Offices, Server Room,
Labs, Executive Floor, then the Director on the roof.

## Play

```bash
./build/SuperCold.x86_64        # exported Linux build
godot4 --path .                 # or run from source with Godot 4.7
```

| Input | Empty hands | Holding something |
|---|---|---|
| WASD, Space | Move, jump | |
| Mouse | Look (looking leaks a little time) | |
| Left click | Punch | Shoot a pistol, throw anything else |
| Right click | Grab what you are looking at | Throw it |
| E | Grab | Swap for what you are looking at |
| F | Wear a dropped SWAT shield, or drop the one you wear | |
| R | Restart the floor | |
| Esc | Pause: sensitivity, field of view, volume | |
| F3 | Debug readout (source runs only) | |

Things worth knowing:

- A pistol has six rounds and its cooldown runs on world time. Stand still after a shot and it will not be ready.
- Throw anything at a dude to stun him and knock his gun into the air. Catch it.
- Three punches kill. The first one disarms.
- Doors break to two punches, two bullets, or one thrown object. The panels stun whoever stood behind.
- Dudes aim where you are, not where you will be. Keep moving sideways.
- Shield troopers only die to a bullet through the glass slit in their shield, or to an explosion. Take the shield with F afterwards.
- One bullet in three ricochets off a shield. It can come back at you.
- Red barrels explode when shot or thrown. Walls block the blast, so use them. Do not stand next to one.
- The wall breaker opens doors in one bash and interior walls in two. It has five hits.
- The AK-47 is automatic: hold the trigger. The shotgun throws eight pellets.
- Die three times on a floor and a capsule with a red figure waits outside the lift. Hit its button, watch the ad, and a red helper with an AK fights beside you for three minutes or until the floor is clear.
- The Director takes three bullets and calls a wave each time he is hit.

## Develop

```bash
tests/run.sh                    # headless unit tests, exit code is pass or fail
tests/run.sh test_dude          # one file
godot4 --headless --fixed-fps 60 --path . -s tests/smoke_bot.gd    # plays every floor for 10 s
tools/shot.sh out.png f3_servers 2.0      # renders one frame on a hidden display
python3 tools/make_levels.py    # regenerate floor grids after editing the script
godot4 --headless --path . --export-release "Linux" build/SuperCold.x86_64
```

All gameplay numbers live in `data/tuning.gd`. Floors are ASCII grids in `levels/`, legend in
`world/level_parser.gd`. Design rules and the milestone log are in `CLAUDE.md` and `docs/DECISIONS.md`.
No external assets: meshes are primitives and every sound is synthesized in `audio/sfx_synth.gd`.
