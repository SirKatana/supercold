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
| R | Restart the floor | |
| Esc | Pause: sensitivity, field of view, volume | |
| F3 | Debug readout (source runs only) | |

Things worth knowing:

- A pistol has six rounds and its cooldown runs on world time. Stand still after a shot and it will not be ready.
- Throw anything at a dude to stun him and knock his gun into the air. Catch it.
- Three punches kill. The first one disarms.
- Doors break to two punches, two bullets, or one thrown object. The panels stun whoever stood behind.
- Dudes aim where you are, not where you will be. Keep moving sideways.
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
