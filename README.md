# SuperCold

A first-person time-shooter. Time crawls while you stand still, slow enough to step
around bullets, grab what is lying about, and break doors down. Move and the world
moves with you. One hit kills you. One bullet kills them.

Thirty levels up a corporate HQ full of evil pink dudes. The Brute waits on level 10 and
his super gun is the prize. The Warden holds level 21. The Director is on the roof.

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
| Q | | Throw it (always) |
| Right click, sniper rifle | | Hold to look down the scope |
| R | Restart the floor | |
| Esc | Pause: sensitivity, field of view, volume, sunglasses on or off | |
| F3 | Debug readout (source runs only) | |

Things worth knowing:

- A pistol has six rounds and its cooldown runs on world time. Stand still after a shot and it will not be ready.
- Throw anything at a dude to stun him and knock his gun into the air. Catch it.
- Three punches kill. The first one disarms.
- Double doors break a leaf at a time: two punches, two bullets or one thrown object takes out the leaf you hit, and you can squeeze through that half. The ram or a blast takes both. The splinters stun whoever stood behind.
- Dudes aim where you are, not where you will be. Keep moving sideways.
- Shield troopers only die to a bullet through the glass slit in their shield, or to an explosion. Take the shield with F afterwards.
- One bullet in three ricochets off a shield. It can come back at you.
- Red barrels explode when shot or thrown. Walls block the blast, so use them. Do not stand next to one.
- The wall breaker opens doors in one bash and interior walls in two. It has five hits.
- The AK-47 is automatic: hold the trigger. The shotgun throws eight pellets.
- Die three times on a floor and a capsule with a red figure waits outside the lift. Hit its button, watch the ad, and a red helper with an AK fights beside you for four minutes or until the floor is clear.
- The exit elevator is not on the floor while anyone is alive. Clear the floor and it arrives with a ding.
- Whatever you hold rides up with you. Bring a weapon and a security guard is waiting outside the lift with his hand out. Throw it to him with Q and he catches it and leaves. Walk past him armed, shoot him, or fire it, and he shoots and runs you down: he is faster than you. Throwing the weapon away is the only thing that stops him. Mugs, bottles, buckets and the super gun are not his business.
- Freeze bombs turn dudes to ice. Anything shatters a frozen dude, even a thrown mug.
- Dudes running over water or ice fall over and lose their guns. You never slip.
- A water bucket is one pour. Tip it over a dude and he goes straight down. The spill stays slippery for a minute and a half.
- Throw a stink grenade into a room and green fog fills it. Dudes grab their throats, double over and drop. Troopers wear gas masks. Levels 15 and 18 are full of them.
- Spill something (pour a bucket, smash a coffee mug) and the cleaner comes out of the lift to mop it up. He keeps count. The fifth spill on a floor is one too many and he comes for you with the broom. He is slower than you. Nothing kills him: shoot him, or let a pink dude shoot him, and he turns on whoever did it and shouts WHY!, then gets on with his work. Once he is after you, a hit only stops him for a moment.
- A knife kills in one stab. Runners are faster than you, so keep one.
- The knifeman is orange and fast, and his blade reaches further than your fist. Keep away from him too long and he throws it at you.
- The spearman is violet and slow, and he kills from further than you can reach. Shoot him, or get inside the point.
- The cloner is mint white and will not come near you. He keeps making pale copies of himself, up to three at a time. Kill him and every copy pops at once.
- A spear is worth picking up: it kills at arm's length and further, and it kills when thrown. A crossbow is quiet, so nobody comes running.
- The super gun is a laser. It goes through everyone in line, shields too, and they melt.
- The Director takes three bullets and calls a wave each time he is hit.

## Play in a browser

```bash
tools/make_web.sh        # writes web/index.html
```

`web/index.html` is the whole game in one 65 MB file: engine, game data, sounds and the ad video are all inside it. Open it in Chrome, Edge or Firefox straight from disk, or upload that one file anywhere. Click the page once so the browser hands over the mouse and the sound. `web/` is output only and is not in git: delete it whenever you like, nothing else uses it, and the script makes it again. Progress in the browser is kept by the browser, and may not be kept at all for a file opened from disk.

## Testing shortcuts

```bash
./build/SuperCold.x86_64 9                  # start on level 9 (any number from 1 to 30)
./build/SuperCold.x86_64 9 --helper=true    # with the helper hired for free: no deaths, no ad
./build/SuperCold.x86_64 14 --god=true      # cannot die
```

A run started this way saves nothing, so it never moves your real Continue point. From level 11
up you are given the super gun, as you would have it by then. With `--helper=true` he is hired
again on every floor you reach.

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
