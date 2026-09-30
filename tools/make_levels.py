#!/usr/bin/env python3
"""Generates the HQ floor grids into levels/. Re-run after editing: python3 tools/make_levels.py
Hand edits to the generated .txt files are overwritten, so change the floor here instead."""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "levels")


ENEMIES = "auBRSHqNUxyCQE"   # E is the basement beast: he counts for spacing too
# Hangs from the ceiling. Not cover, not an obstacle: the scatter treats it like an item.
DUCTS = {"f8_archive": 3, "f11_sewers": 3, "f12_kitchen": 2,
         "f16_armoury": 2, "f19_tradingfloor": 3, "f23_mirrors": 2, "f24_strongrooms": 3, "f26_morgue": 2, "f28_waterworks": 2,
         "f29_penthouse": 3,
         "f32_crewring": 3, "f35_cargobay": 3, "f37_comms": 2, "f39_docking": 3}
CHANDELIERS = {"f1_lobby": 3, "f5_executive": 4, "f10_vault": 2, "f19_tradingfloor": 5, "f23_mirrors": 4, "f25_skygarden": 3, "f29_penthouse": 6, "f6_cafeteria": 2, "f17_greenhouse": 2}

# The gentleman with the blunderbuss turns up on every floor but the first: one to three of him,
# scattered like any other dude. He is never handed to the player at the lift.
GENTLEMEN = {
    "f2_offices": 1, "f3_servers": 1, "f4_labs": 2, "f5_executive": 2,
    "f6_cafeteria": 1, "f7_garage": 2, "f8_archive": 1, "f9_pool": 2, "f10_vault": 1,
    "f11_sewers": 1, "f12_kitchen": 2, "f13_basement": 1, "f14_glassworks": 2, "f15_restrooms": 1,
    "f16_armoury": 3, "f17_greenhouse": 1, "f18_beanworks": 2, "f19_tradingfloor": 2, "f20_generators": 3,
    "f21_lockdown": 2, "f22_cryolab": 1, "f23_mirrors": 2, "f24_strongrooms": 2, "f25_skygarden": 3,
    "f26_morgue": 1, "f27_furnace": 3, "f28_waterworks": 2, "f29_penthouse": 3, "roof": 2,
    "f31_airlock": 1, "f32_crewring": 2, "f33_hydroponics": 1, "f34_solararray": 2, "f35_cargobay": 2,
    "f36_reactor": 2, "f37_comms": 1, "f38_observation": 2, "f39_docking": 3, "f40_bridge": 3,
}

# Which floors get which gadget, and how many. f = fart grenade, F = freeze bomb, j = water bucket.
# Deliberately uneven: seven floors have none, most have one or two, only two have all three.
# On a floor that has them they are spread across the rooms, never handed over at the lift.
GADGETS = {
    "f1_lobby": {"j": 2},
    "f3_servers": {"F": 2},
    "f5_executive": {"f": 3},
    "f6_cafeteria": {"j": 4},
    "f8_archive": {"F": 2, "j": 2},
    "f9_pool": {"j": 3, "F": 2},
    "f10_vault": {"F": 3, "f": 2},
    "f11_sewers": {"j": 3},
    "f12_kitchen": {"j": 3, "f": 2},
    "f13_basement": {"F": 2},
    "f31_airlock": {"j": 2},
    "f33_hydroponics": {"j": 3, "F": 1},
    "f35_cargobay": {"f": 3},
    "f36_reactor": {"F": 3, "f": 2},
    "f38_observation": {"F": 2},
    "f39_docking": {"j": 2, "f": 2},
    "f40_bridge": {"F": 2, "f": 2, "j": 2},
    "f15_restrooms": {"f": 4, "j": 3},
    "f16_armoury": {"f": 2, "F": 2, "j": 2},
    "f17_greenhouse": {"j": 3, "f": 2},
    "f18_beanworks": {"f": 5},
    "f19_tradingfloor": {"F": 3},
    "f21_lockdown": {"F": 3},
    "f22_cryolab": {"F": 5},
    "f23_mirrors": {"f": 3},
    "f25_skygarden": {"j": 3},
    "f26_morgue": {"F": 2, "f": 2},
    "f28_waterworks": {"j": 4},
    "f29_penthouse": {"f": 2, "F": 2, "j": 2},
    "roof": {"f": 2, "F": 2},
    # none: f2_offices, f4_labs, f7_garage, f14_glassworks, f20_generators, f24_strongrooms, f27_furnace
}


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = [["#"] * w for _ in range(h)]

    def room(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.c[y][x] = "."

    def put(self, ch, *cells):
        for x, y in cells:
            if ch == "o" and self.c[y][x] not in ".#o~i":
                continue      # cover is optional: never fight another object for a cell
            # A lattice pillar gives way to anything placed by hand. Anything else is a mistake.
            assert self.c[y][x] in ".#o~i", f"cell {x},{y} already holds {self.c[y][x]!r}"
            self.c[y][x] = ch

    def pillars(self, x0, y0, x1, y1, step=4, ox=2, oy=2):
        """Full-height cover on a lattice. Skips anything not plain floor and anything beside a door,
        pane or entity, so doorways and spawn cells stay clear."""
        for y in range(y0 + oy, y1, step):
            for x in range(x0 + ox, x1, step):
                if self.c[y][x] != ".":
                    continue
                around = [self.c[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx or dy)]
                if not any(ch in "DGXPauBwtRS" for ch in around):
                    self.c[y][x] = "o"

    def fill(self, ch, x0, y0, x1, y1):
        """Turns plain floor in the rectangle into `ch` (water, ice). Leaves everything else alone."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.c[y][x] == ".":
                    self.c[y][x] = ch

    def wall(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.c[y][x] = "#"

    def ring(self, x0, y0, x1, y1, width=2):
        """A corridor running round the edge of the rectangle."""
        self.room(x0, y0, x1, y1)
        self.wall(x0 + width, y0 + width, x1 - width, y1 - width)

    def maze(self, x0, y0, x1, y1, seed):
        """Depth-first maze, one cell corridors, carved out of solid wall. x0,y0 must be odd-aligned to x1,y1."""
        import random
        rng = random.Random(seed)
        cols, rows = (x1 - x0) // 2 + 1, (y1 - y0) // 2 + 1
        seen = {(0, 0)}
        stack = [(0, 0)]
        self.c[y0][x0] = "."
        while stack:
            cx, cy = stack[-1]
            options = [(cx + dx, cy + dy, dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                       if 0 <= cx + dx < cols and 0 <= cy + dy < rows and (cx + dx, cy + dy) not in seen]
            if not options:
                stack.pop()
                continue
            nx, ny, dx, dy = rng.choice(options)
            self.c[y0 + cy * 2 + dy][x0 + cx * 2 + dx] = "."
            self.c[y0 + ny * 2][x0 + nx * 2] = "."
            seen.add((nx, ny))
            stack.append((nx, ny))
        # Knock a few extra holes so it has loops and dudes can flank.
        for _ in range((cols * rows) // 5):
            x, y = rng.randrange(x0 + 1, x1), rng.randrange(y0 + 1, y1)
            if self.c[y][x] == "#" and ((self.c[y][x - 1] == "." and self.c[y][x + 1] == ".") or (self.c[y - 1][x] == "." and self.c[y + 1][x] == ".")):
                self.c[y][x] = "."

    def scatter(self, spec, rects, seed, gap=4.2, from_player=6.5, floor=".", margin=False, spread=0.0):
        """Drops things on random floor cells. `spec` is {char: count}. Enemies keep `gap` cells from each
        other and `from_player` from P. Nothing lands beside a door, a lift, or in front of one."""
        import math, random
        rng = random.Random(seed)
        spots = [(x, y) for (x0, y0, x1, y1) in rects for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
                 if self.c[y][x] in floor]
        rng.shuffle(spots)
        player = self.cells("P")
        lifts = self.cells("PX")
        for ch, count in spec.items():
            placed = 0
            for (x, y) in spots:
                if placed >= count:
                    break
                if self.c[y][x] not in floor:
                    continue
                near = [self.c[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                        if 0 <= y + dy < self.h and 0 <= x + dx < self.w]
                if any(n in "DPX" for n in near):
                    continue
                if any(math.dist((x, y), l) < 2.5 for l in lifts):
                    continue
                if ch in ENEMIES:
                    if player and math.dist((x, y), player[0]) < from_player:
                        continue
                    if any(math.dist((x, y), e) < gap for e in self.cells(ENEMIES)):
                        continue
                elif margin and any(n not in ".~i" for n in near):
                    continue
                if spread > 0.0:
                    # Gadgets: well away from the lift, and well away from each other.
                    if player and math.dist((x, y), player[0]) < from_player:
                        continue
                    if any(math.dist((x, y), other) < spread for other in self.cells("fFj")):
                        continue
                self.c[y][x] = ch
                placed += 1
            assert placed == count, f"could only place {placed} of {count} '{ch}'"

    def cells(self, chars):
        return [(x, y) for y in range(self.h) for x in range(self.w) if self.c[y][x] in chars]

    def check_spacing(self, name, between=4.0, from_player=6.0):
        import math
        enemies = self.cells(ENEMIES)
        player = self.cells("P")[0]
        for i, a in enumerate(enemies):
            assert math.dist(a, player) >= from_player, f"{name}: enemy {a} is {math.dist(a, player):.1f} cells from the player"
            for b in enemies[i + 1:]:
                assert math.dist(a, b) >= between, f"{name}: enemies {a} and {b} are {math.dist(a, b):.1f} cells apart"

    def gadgets(self, name, seed):
        """Places this floor's share of fart grenades, freeze bombs and buckets from GADGETS."""
        wanted = GADGETS.get(name, {})
        if not wanted:
            return
        everywhere = [(1, 1, self.w - 2, self.h - 2)]
        total = sum(wanted.values())
        for spread in (7.0, 5.5, 4.0):          # as spread out as the floor allows
            for retry in range(40):
                trial = [row[:] for row in self.c]
                try:
                    self.scatter(wanted, everywhere, seed + retry * 13, floor=".", margin=True, spread=spread)
                except AssertionError:
                    self.c = trial
                    continue
                xs = [x for x, y in self.cells("fFj")]
                ys = [y for x, y in self.cells("fFj")]
                # Three or more should reach across the floor, not sit in one corner of it.
                if total < 3 or ((max(xs) - min(xs)) >= self.w * 0.5 and (max(ys) - min(ys)) >= self.h * 0.3):
                    return
                self.c = trial
        raise AssertionError(f"{name}: no room for its gadgets")

    def gentlemen(self, name, seed):
        """Places this floor's gentlemen from GENTLEMEN, spaced like any other dude."""
        wanted = GENTLEMEN.get(name, 0)
        if not wanted:
            return
        everywhere = [(1, 1, self.w - 2, self.h - 2)]
        for spread in (6.5, 5.5, 5.0):
            for retry in range(60):
                trial = [row[:] for row in self.c]
                try:
                    self.scatter({"Q": wanted}, everywhere, seed + retry * 17, floor=".", margin=True, spread=spread)
                except AssertionError:
                    self.c = trial
                    continue
                return
        raise AssertionError(f"{name}: no room for its gentlemen")

    def text(self):
        return "\n".join("".join(r) for r in self.c) + "\n"


THEMES = {
    # wall, floor, prop, ambient colour, sky, ambient energy, sun energy
    "cream":    ("f3ead8", "b9a88c", "cdbd9f", "fff6e6", "f6efe2", 0.55, 0.45),
    "concrete": ("b9bcc0", "55595f", "8b9096", "e9eef5", "c8ccd2", 0.48, 0.40),
    "paper":    ("ece4d0", "8f8468", "a89c7c", "fff8e8", "efe8d6", 0.52, 0.40),
    "aqua":     ("e6f6f7", "7fb8c2", "a9d5da", "e8fbff", "dff4f6", 0.58, 0.45),
    "steel":    ("aab4c2", "4a5261", "7c8797", "dfe8f5", "b4bdca", 0.46, 0.42),
    "sewer":    ("6f7a63", "3a4234", "59624e", "c9d8b0", "4a5340", 0.34, 0.22),
    "stainless": ("dfe3e6", "8a9197", "b4bbc1", "f2f7fb", "e2e6e9", 0.56, 0.48),
    "frost":    ("e4f1fb", "a9c9e2", "c3dbee", "e6f4ff", "dcecf8", 0.60, 0.42),
    # The basement: almost nothing to see by. The tanks are most of the light down there.
    "basement": ("2b3230", "141a18", "222926", "9fd8b4", "0a0f0d", 0.16, 0.07),
    "glass":    ("f4fbfd", "bcd9e2", "d5e8ee", "f0fbff", "eaf6fa", 0.62, 0.45),
    "mint":     ("dff1e4", "7fae8f", "a8cdb4", "ecfff2", "dcefe2", 0.55, 0.42),
    "olive":    ("a7ab8d", "4f533c", "777b5c", "e6ead2", "9da184", 0.46, 0.40),
    "leaf":     ("e3efd6", "5f8a45", "8fb070", "f2ffe0", "d6ecc4", 0.58, 0.50),
    "bean":     ("d9c7a4", "6b5234", "9a7f57", "fff0d4", "cdb98f", 0.50, 0.42),
    "navy":     ("3b4966", "1c2436", "e8ecf2", "b9c8ea", "2a3450", 0.40, 0.30),
    "amber":    ("4a4743", "26241f", "6a655c", "ffd9a0", "38342e", 0.32, 0.26),
    "prison":   ("9aa4b3", "3e4652", "6c7685", "dbe4f2", "8d97a6", 0.44, 0.38),
    "cryo":     ("eef7ff", "bcd6ee", "d6e7f6", "eaf5ff", "e6f1fb", 0.64, 0.40),
    "silver":   ("dcdfe4", "9498a0", "b8bcc3", "f4f6fa", "d8dbe0", 0.56, 0.46),
    "bank":     ("c9d2bd", "3f5a44", "b39a55", "f0f6e2", "bac5ac", 0.50, 0.42),
    "sky":      ("f0f4f6", "7fa66a", "b9c7a8", "f4fbff", "bfe0f7", 0.66, 0.60),
    "morgue":   ("8fa6a8", "2f3f42", "5f7679", "cfe9ea", "6f8688", 0.36, 0.24),
    "furnace":  ("57514c", "2b2724", "7a7068", "ffc98a", "3c3632", 0.34, 0.30),
    "harbour":  ("cbd8e2", "4e6b82", "8aa2b5", "e4f1fb", "bccddb", 0.52, 0.42),
    "gold":     ("fbf6ea", "c9b27a", "e4d3a3", "fffaec", "f8f1de", 0.62, 0.52),
    # The station. Everything above 30 is up there, so the light is hard and the sky is black.
    "airlock":  ("dde6ee", "6e7b88", "9fb0be", "e8f2ff", "10131a", 0.42, 0.62),
    "crewring": ("e9e2ea", "6b6070", "aa9fb4", "f6efff", "14101c", 0.44, 0.58),
    "hydro":    ("d6f2e8", "3f7d68", "7fc0a8", "e2fff5", "0d1a18", 0.50, 0.55),
    "solar":    ("cfd6de", "3a4250", "8d97a8", "dfe9ff", "05070d", 0.34, 0.75),
    "cargo":    ("c2c6b8", "4d5245", "8d9382", "eaefdf", "0f120e", 0.40, 0.52),
    "reactor":  ("6b5a74", "2a2230", "9b7fae", "ffd0f2", "160f1c", 0.30, 0.30),
    "comms":    ("b9c9d6", "38505f", "7d9cb0", "dcefff", "070d14", 0.38, 0.48),
    "observ":   ("eef4ff", "9aa7bd", "c6d2e6", "f4f8ff", "02040a", 0.46, 0.66),
    "docking":  ("aeb7bd", "2f363b", "74808a", "d6e2ea", "0a0c10", 0.36, 0.50),
    "bridge":   ("dfe7f2", "44506a", "97a6c2", "e9f1ff", "080b14", 0.44, 0.56),
}


def theme(name):
    wall, floor, prop, ambient, sky, energy, sun = THEMES[name]
    return {"wall": wall, "floor": floor, "prop": prop, "ambient": ambient, "sky": sky, "energy": energy, "sun": sun}



def ducts(g, seed, runs=2):
    """Carves the crawl ducts: a maze of tunnels inside the walls, with a few grates opening
    into rooms. Wall cells are the maze's corridors, so the ducts run round and between rooms
    the way real ventilation does, and there is always wall behind a grate rather than a hole
    straight through into the next room.

    `runs` is how many mouths to open. The maze itself is as big as the wall space allows, up
    to `cap` cells."""
    import random
    rng = random.Random(seed)
    cap = 22 + runs * 10

    def diggable(x, y):
        # Interior wall only, never the outer shell, never beside a door, a lift or glass.
        if not (1 < x < g.w - 2 and 1 < y < g.h - 2):
            return False
        if g.c[y][x] != "#":
            return False
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if g.c[y + dy][x + dx] in "DGPXBw":
                    return False
        return True

    def rooms_beside(x, y):
        return [(x + dx, y + dy) for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if g.c[y + dy][x + dx] in ".~i"]

    starts = [(x, y) for y in range(2, g.h - 2) for x in range(2, g.w - 2)
              if diggable(x, y) and rooms_beside(x, y)]
    if not starts:
        return 0
    rng.shuffle(starts)
    # Grow the maze from one seed cell, preferring to carry straight on, so the result is
    # long tunnels with junctions rather than a blob.
    maze = {starts[0]}
    frontier = [starts[0]]
    while frontier and len(maze) < cap:
        # Growing tree: mostly carry on from the newest cell, which makes long tunnels, and
        # now and then jump back to an older one, which makes branches.
        index = rng.randrange(len(frontier)) if rng.random() < 0.3 else len(frontier) - 1
        x, y = frontier[index]
        steps = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        rng.shuffle(steps)
        dug = False
        for (dx, dy) in steps:
            nx, ny = x + dx, y + dy
            if (nx, ny) in maze or not diggable(nx, ny):
                continue
            # Keep it a maze and not a room: a new cell normally touches one cell already dug.
            # Now and then allow a second, which closes a loop and gives the ducts a way round
            # a room instead of a dead end.
            touching = sum(1 for (ox, oy) in ((1, 0), (-1, 0), (0, 1), (0, -1))
                           if (nx + ox, ny + oy) in maze)
            if touching > 2 or (touching == 2 and rng.random() > 0.22):
                continue
            maze.add((nx, ny))
            frontier.append((nx, ny))
            dug = True
            break
        if not dug:
            frontier.pop(index)      # nowhere left to go from there
    if len(maze) < 6:
        return 0
    # Mouths: cells of the maze that touch a room, spread out, and never two facing each other
    # through the same wall.
    candidates = [c for c in maze if rooms_beside(*c)]
    rng.shuffle(candidates)
    mouths = []
    for (x, y) in candidates:
        if len(mouths) >= max(2, runs + 1):
            break
        if any(abs(x - mx) + abs(y - my) < 4 for (mx, my) in mouths):
            continue
        mouths.append((x, y))
    if len(mouths) < 2:
        return 0
    for (x, y) in maze:
        g.c[y][x] = "v"
    # Only the mouths are open to a room. Every other duct cell keeps its wall, which is what
    # puts solid wall behind a grate instead of a hole through into the next room.
    for (x, y) in mouths:
        g.c[y][x] = "e"
    return len(mouths)


def save(name, grid, meta):
    grid.check_spacing(name)
    with open(os.path.join(OUT, name + ".txt"), "w") as f:
        f.write(grid.text())
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    print(f"{name}: {grid.w}x{grid.h}")


def f1_lobby():
    g = Grid(20, 14)
    g.room(1, 1, 18, 7)
    g.room(1, 9, 18, 12)
    g.put("#", *[(x, y) for x in (9, 10) for y in (1, 2, 3, 4)])
    g.put(".", (4, 8), (5, 8), (14, 8), (15, 8))          # turnstile gaps
    g.put("P", (1, 2))
    g.put("p", (4, 4))
    g.put("c", (5, 6), (6, 6), (13, 6), (14, 6), (9, 10), (10, 10))
    g.put("a", (16, 2), (2, 11), (17, 11), (9, 12))
    g.put("b", (6, 10))
    g.put("m", (13, 10))
    g.put("X", (12, 12))
    g.put("g", (11, 9))
    g.put("o", (3, 6), (7, 3), (12, 3), (16, 6), (4, 10), (15, 10), (7, 12))
    g.gadgets("f1_lobby", 799)
    g.gentlemen("f1_lobby", 840)
    g.put("h", (4, 3), (14, 3), (8, 9))
    save("f1_lobby", g, {"intro": "LOBBY\nSTAND STILL. TIME CRAWLS."})


def f2_offices():
    g = Grid(30, 22)
    g.room(1, 1, 8, 5)       # start
    g.room(1, 7, 8, 14)      # west corridor
    g.room(10, 1, 28, 14)    # cubicle hall
    g.room(1, 16, 13, 20)    # south west
    g.room(15, 16, 28, 20)   # south east
    g.put("D", (4, 6), (9, 3), (9, 11), (5, 15), (20, 15), (14, 18))
    for y in (3, 6, 9, 12):
        for x in (12, 17, 22):
            g.put("c", (x, y), (x + 1, y))
    g.put("P", (1, 2))
    g.put("X", (28, 18))
    g.put("a", (15, 4), (21, 7), (26, 10), (14, 13), (4, 11), (22, 18))
    g.put("u", (7, 18))
    g.put("b", (7, 2))
    g.put("k", (2, 4))
    g.put("m", (11, 8))
    g.put("l", (19, 10))
    g.put("p", (27, 2))
    g.put("r", (6, 4))
    g.put("g", (16, 5), (24, 11), (10, 18))
    g.pillars(10, 1, 28, 14, step=5, ox=4, oy=1)
    g.pillars(1, 7, 8, 14, step=3, ox=2, oy=2)
    g.pillars(1, 16, 13, 20, step=4, ox=3, oy=2)
    g.pillars(15, 16, 28, 20, step=4, ox=3, oy=2)
    g.gadgets("f2_offices", 99)
    g.gentlemen("f2_offices", 140)
    save("f2_offices", g, {"intro": "OFFICES\nTHROW THINGS. TAKE THEIR GUNS."})


def f3_servers():
    g = Grid(28, 20)
    g.room(1, 1, 6, 5)       # start
    g.room(1, 7, 6, 12)      # control room
    g.room(8, 1, 26, 12)     # server hall
    g.room(1, 14, 26, 18)    # south corridor
    g.put("D", (7, 3), (3, 6), (3, 13), (12, 13), (22, 13))
    g.put("G", (7, 8), (7, 9), (7, 10), (7, 11))
    for x in (10, 14, 18, 22):
        for y in (2, 3, 4, 5, 8, 9, 10, 11):
            g.put("s", (x, y))
    g.put("P", (1, 2))
    g.put("X", (26, 16))
    g.put("a", (12, 3), (16, 10), (20, 4), (24, 9), (8, 16), (18, 16))
    g.put("S", (4, 9))
    g.put("g", (12, 6), (20, 9), (12, 15))
    g.put("T", (9, 10))
    g.put("u", (14, 16))
    g.put("b", (5, 2))
    g.put("k", (5, 11))
    g.put("l", (9, 7))
    g.put("m", (20, 15))
    g.put("r", (2, 4))
    g.pillars(1, 14, 26, 18, step=4, ox=3, oy=2)
    g.pillars(1, 7, 6, 12, step=3, ox=2, oy=2)
    g.put("o", (8, 6), (12, 7), (16, 6), (20, 7), (24, 6), (26, 12))
    g.gadgets("f3_servers", 143)
    g.gentlemen("f3_servers", 184)
    save("f3_servers", g, {"intro": "SERVER ROOM\nDOORS BREAK. SO DO THEY."})


def f4_labs():
    g = Grid(36, 24)
    g.room(1, 11, 34, 12)    # long corridor
    for x0 in (1, 12, 24):
        g.room(x0, 1, x0 + 10 if x0 > 1 else 10, 9)
        g.room(x0, 14, x0 + 10 if x0 > 1 else 10, 22)
    g.put("D", (5, 10), (17, 10), (29, 10), (5, 13), (17, 13), (29, 13))
    g.put("G", (7, 10), (8, 10), (19, 10), (20, 10), (31, 13), (32, 13))
    g.put("P", (1, 12))
    g.put("X", (34, 18))
    g.put("a", (14, 11), (5, 4), (17, 5), (29, 4), (5, 18), (17, 18), (29, 17))
    g.put("R", (24, 12))
    g.put("H", (32, 11))
    g.put("g", (18, 12), (28, 11), (8, 5), (20, 19))
    g.put("K", (8, 3))
    g.put("u", (9, 21))
    g.put("w", (34, 11), (34, 12), (13, 1), (22, 22), (1, 1), (1, 22))
    g.put("o", (8, 11), (11, 12), (19, 11), (21, 12), (27, 11), (30, 12))
    g.put("p", (4, 11), (30, 20))
    g.put("r", (6, 12))
    g.put("b", (16, 3))
    g.put("k", (28, 3))
    g.put("m", (6, 17))
    g.put("l", (18, 20))
    g.put("c", (3, 3), (4, 3), (15, 7), (16, 7), (27, 7), (28, 7), (3, 16), (4, 16), (15, 16), (27, 20))
    for x0 in (1, 12, 24):
        g.pillars(x0, 1, x0 + 10, 9, step=4, ox=2, oy=2)
        g.pillars(x0, 14, x0 + 10, 22, step=4, ox=2, oy=2)
    g.gadgets("f4_labs", 684)
    g.gentlemen("f4_labs", 725)
    save("f4_labs", g, {
        "intro": "LABS\nLONG HALLS. WATCH THE BULLETS.",
        "waves": [{"after_kills": 6, "count": 4, "armed": 3}],
    })


def f5_executive():
    g = Grid(40, 28)
    g.room(1, 1, 12, 8)      # reception
    g.room(1, 10, 12, 17)    # west office 1
    g.room(1, 19, 12, 26)    # west office 2
    g.room(14, 1, 38, 14)    # boardroom
    g.room(14, 16, 38, 18)   # corridor
    g.room(14, 20, 25, 26)   # exec office south west
    g.room(27, 20, 38, 26)   # exec office south east
    g.put("D", (13, 4), (6, 9), (6, 18), (13, 17), (20, 15), (32, 15), (22, 19), (29, 19))
    g.put("G", (17, 19), (18, 19), (19, 19), (32, 19), (33, 19), (34, 19))
    for x in range(18, 35, 2):
        g.put("c", (x, 7), (x, 8))
    g.put("P", (1, 2))
    g.put("X", (38, 23))
    g.put("a", (9, 6), (31, 3), (4, 13))
    g.put("x", (33, 23))
    g.put("S", (30, 12))
    g.put("R", (24, 4), (36, 10))
    g.put("H", (26, 17), (24, 11))
    g.put("g", (22, 5), (30, 9), (20, 17), (34, 17), (8, 14))
    g.put("K", (10, 7))
    g.put("T", (16, 17))
    g.put("u", (9, 15), (18, 23))
    g.put("w", (14, 17), (38, 17), (2, 26), (38, 1), (14, 26), (12, 10))
    g.put("p", (3, 6), (37, 21))
    g.put("r", (6, 3))
    g.put("b", (10, 2), (3, 21))
    g.put("k", (16, 10), (24, 16))
    g.put("m", (35, 5))
    g.put("l", (8, 12))
    g.pillars(14, 1, 38, 14, step=5, ox=2, oy=2)
    g.pillars(1, 1, 12, 8, step=4, ox=3, oy=3)
    g.pillars(1, 10, 12, 17, step=4, ox=2, oy=2)
    g.pillars(1, 19, 12, 26, step=4, ox=2, oy=2)
    g.pillars(14, 20, 25, 26, step=4, ox=2, oy=2)
    g.pillars(27, 20, 38, 26, step=4, ox=2, oy=2)
    g.put("o", (18, 17), (24, 18), (30, 16), (35, 17))
    g.gadgets("f5_executive", 345)
    g.gentlemen("f5_executive", 386)
    g.put("h", (4, 3), (14, 3), (24, 3), (34, 3))
    save("f5_executive", g, {
        "intro": "EXECUTIVE FLOOR\nEVERYTHING YOU LEARNED.",
        "waves": [{"after_kills": 5, "count": 4, "armed": 3}, {"after_kills": 10, "count": 5, "armed": 4}],
    })


def roof():
    g = Grid(30, 30)
    g.room(4, 4, 25, 25)     # arena
    g.room(13, 1, 16, 2)     # north stairwell
    g.room(13, 27, 16, 28)   # south stairwell
    g.room(1, 13, 2, 16)     # west stairwell
    g.room(27, 13, 28, 16)   # east stairwell
    g.put("D", (14, 3), (15, 26), (3, 14), (26, 15))
    g.put("w", (14, 1), (15, 28), (1, 15), (28, 14))
    g.put("s", (9, 9), (20, 9), (9, 20), (20, 20), (14, 12), (15, 18))
    g.put("c", (11, 15), (12, 15), (18, 15), (19, 15))
    g.put("P", (4, 23))
    g.put("B", (15, 7))
    g.put("X", (15, 15))
    g.put("H", (10, 6))
    g.put("R", (20, 6))
    g.put("g", (7, 9), (22, 11), (12, 21), (19, 22))
    g.put("p", (7, 15))
    g.put("K", (23, 15))
    g.put("T", (15, 20))
    g.put("b", (15, 22))
    g.put("k", (5, 5))
    g.put("m", (24, 24))
    g.put("l", (24, 5))
    g.pillars(4, 4, 25, 25, step=5, ox=3, oy=3)
    g.gadgets("roof", 455)
    g.gentlemen("roof", 496)
    save("roof", g, {"intro": "ROOF\nTHE DIRECTOR. THREE BULLETS.", "open_sky": True, "exit": "helipad"})


# ---------------------------------------------------------------- floors 6 to 29
#
# These are buildings, like the first five floors: corridors, rooms off them, doors between.
# A floor is a layout (where the walls and doors go) plus dressing (furniture inside rooms,
# hazards, who and what is in there). Every candidate floor is flood-filled from the lift to
# make sure each enemy and the exit can be walked to; if not, the next seed is tried.

import random

SOLID = set("# GWcso" + "pbmklrKTgnFMVYfj")      # walls, glass, deep water, furniture, pedestals, barrels


def _door_between(g, rng, cells):
    """Puts one door on a wall line, choosing among `cells` whose two sides are both floor."""
    options = []
    for (x, y, dx, dy) in cells:
        if g.c[y][x] == "#" and g.c[y - dy][x - dx] == "." and g.c[y + dy][x + dx] == ".":
            options.append((x, y))
    if options:
        x, y = rng.choice(options)
        g.c[y][x] = "D"
        return True
    return False


def _band(g, rng, y0, y1, door_row, toward, min_w, max_w, rooms, split_deep=True):
    """One row of rooms along a corridor. `door_row` is the wall between them and the corridor,
    `toward` is +1 if the corridor is below the band and -1 if above."""
    x = 1
    previous = None
    while x <= g.w - 2:
        w = rng.randint(min_w, max_w)
        if (g.w - 2) - (x + w) < min_w:
            w = (g.w - 2) - x + 1
        x1 = x + w - 1
        depth = y1 - y0 + 1
        front = (x, y0, x1, y1)
        if split_deep and depth >= 9 and w >= 6 and rng.random() < 0.65:
            # A back room behind the front one, reached through it.
            mid = y0 + depth // 2 if toward > 0 else y1 - depth // 2
            back = (x, y0, x1, mid - 1) if toward > 0 else (x, mid + 1, x1, y1)
            front = (x, mid + 1, x1, y1) if toward > 0 else (x, y0, x1, mid - 1)
            g.room(*back)
            g.room(*front)
            _door_between(g, rng, [(cx, mid, 0, 1) for cx in range(x + 1, x1)])
            rooms.append({"rect": back, "kind": "back"})
        else:
            g.room(*front)
        rooms.append({"rect": front, "kind": "front"})
        _door_between(g, rng, [(cx, door_row, 0, 1) for cx in range(x + 1, x1)])
        if previous is not None and rng.random() < 0.5:
            _door_between(g, rng, [(x - 1, cy, 1, 0) for cy in range(y0 + 1, y1)])
        previous = front
        x = x1 + 2


def _buttresses(g, rng, x0, x1, rows, every=6):
    """Short wall stubs on alternating sides of a corridor. Cover that looks like architecture."""
    side = 0
    for x in range(x0 + 5, x1 - 3, every):
        y = rows[side % len(rows)]
        near = [g.c[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)]
        if g.c[y][x] == "." and "D" not in near:
            g.c[y][x] = "#"
        side += 1


def layout_spine(g, rng, corridor=3, min_w=6, max_w=10):
    """One corridor west to east, rooms north and south of it."""
    cy0 = (g.h - corridor) // 2
    cy1 = cy0 + corridor - 1
    g.room(1, cy0, g.w - 2, cy1)
    rooms = []
    _band(g, rng, 1, cy0 - 2, cy0 - 1, +1, min_w, max_w, rooms)
    _band(g, rng, cy1 + 2, g.h - 2, cy1 + 1, -1, min_w, max_w, rooms)
    _buttresses(g, rng, 1, g.w - 2, [cy0, cy1])
    g.put("P", (1, cy0 + corridor // 2))
    return rooms, [(1, cy0, g.w - 2, cy1)]


def layout_double(g, rng, corridor=3, min_w=6, max_w=10):
    """Two corridors with a band of rooms between them and one outside each. A cross passage joins them."""
    third = g.h // 3
    a0 = third - 1
    a1 = a0 + corridor - 1
    b0 = g.h - third - 1
    b1 = b0 + corridor - 1
    g.room(1, a0, g.w - 2, a1)
    g.room(1, b0, g.w - 2, b1)
    rooms = []
    _band(g, rng, 1, a0 - 2, a0 - 1, +1, min_w, max_w, rooms, split_deep=False)
    _band(g, rng, a1 + 2, b0 - 2, a1 + 1, -1, min_w, max_w, rooms, split_deep=False)
    _band(g, rng, b1 + 2, g.h - 2, b1 + 1, -1, min_w, max_w, rooms, split_deep=False)
    # The middle rooms open onto the second corridor too, and one passage cuts straight through.
    for room in rooms:
        x0, y0, x1, y1 = room["rect"]
        if y0 > a1 and y1 < b0:
            _door_between(g, rng, [(cx, b0 - 1, 0, 1) for cx in range(x0 + 1, x1)])
    cross = rng.randint(g.w // 3, 2 * g.w // 3)
    for y in range(a1 + 1, b0):
        for x in (cross, cross + 1):
            g.c[y][x] = "."
    _buttresses(g, rng, 1, g.w - 2, [a0, a1])
    _buttresses(g, rng, 1, g.w - 2, [b0, b1])
    g.put("P", (1, a0 + corridor // 2))
    return rooms, [(1, a0, g.w - 2, a1), (1, b0, g.w - 2, b1)]


def layout_bsp(g, rng, min_side=6, max_side=11):
    """No corridor: the whole floor is cut into rooms, each wall with a door or two."""
    rooms = []

    def cut(x0, y0, x1, y1):
        w, h = x1 - x0 + 1, y1 - y0 + 1
        # A side can only be cut if both halves, plus the wall between them, still fit.
        wide = w > max_side and w >= 2 * min_side + 1
        tall = h > max_side and h >= 2 * min_side + 1
        if not wide and not tall:
            g.room(x0, y0, x1, y1)
            rooms.append({"rect": (x0, y0, x1, y1), "kind": "front"})
            return
        if wide and (not tall or w >= h):
            sx = rng.randint(x0 + min_side, x1 - min_side)
            cut(x0, y0, sx - 1, y1)
            cut(sx + 1, y0, x1, y1)
            line = [(sx, cy, 1, 0) for cy in range(y0 + 1, y1)]
        else:
            sy = rng.randint(y0 + min_side, y1 - min_side)
            cut(x0, y0, x1, sy - 1)
            cut(x0, sy + 1, x1, y1)
            line = [(cx, sy, 0, 1) for cx in range(x0 + 1, x1)]
        _door_between(g, rng, line)
        if len(line) > 12:
            _door_between(g, rng, line)      # a long wall gets a second door, so there are loops

    cut(1, 1, g.w - 2, g.h - 2)
    first = min(rooms, key=lambda r: (r["rect"][0], r["rect"][1]))
    x0, y0, x1, y1 = first["rect"]
    g.put("P", (1, (y0 + y1) // 2))
    return rooms, []


LAYOUTS = {"spine": layout_spine, "double": layout_double, "bsp": layout_bsp}


def furnish(g, rng, rect, kind):
    """Furniture inside a room. It never touches the ring of floor along the walls, so a room can
    always be walked round and no door is ever blocked."""
    x0, y0, x1, y1 = rect
    ix0, iy0, ix1, iy1 = x0 + 1, y0 + 1, x1 - 1, y1 - 1
    if ix1 - ix0 < 2 or iy1 - iy0 < 2:
        return

    def put(ch, x, y):
        if ix0 <= x <= ix1 and iy0 <= y <= iy1 and g.c[y][x] == ".":
            g.c[y][x] = ch

    if kind == "office":                                   # desks in pairs, in rows
        for y in range(iy0 + (iy1 - iy0) % 3 // 2, iy1 + 1, 3):
            for x in range(ix0, ix1, 4):
                put("c", x, y); put("c", x + 1, y)
    elif kind == "racks":                                  # shelving in aisles with a cross gap
        gap = (iy0 + iy1) // 2
        for x in range(ix0, ix1 + 1, 3):
            for y in range(iy0, iy1 + 1):
                if y != gap:
                    put("s", x, y)
    elif kind == "tables":                                 # single tables, staggered
        for n, y in enumerate(range(iy0, iy1 + 1, 2)):
            for x in range(ix0 + (n % 2) * 2, ix1 + 1, 4):
                put("c", x, y)
    elif kind == "counters":                               # long worktops with a break in them
        for y in range(iy0, iy1 + 1, 3):
            for x in range(ix0, ix1 + 1):
                if (x - ix0) % 5 != 4:
                    put("c", x, y)
    elif kind == "stalls":                                 # dividers along one wall
        for x in range(ix0, ix1 + 1, 2):
            put("c", x, iy0); put("c", x, iy0 + 1)
    elif kind == "vats":                                   # 2 by 2 blocks of full-height tank
        for y in range(iy0, iy1, 4):
            for x in range(ix0, ix1, 4):
                for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                    put("o", x + dx, y + dy)
    elif kind == "slabs":                                  # rows of tables end to end, morgue style
        for y in range(iy0, iy1 + 1, 2):
            for x in range(ix0, ix1 + 1, 3):
                put("c", x, y)
    elif kind == "columns":                                # a pair of columns in a big room
        if ix1 - ix0 >= 4 and iy1 - iy0 >= 3:
            put("o", ix0 + 1, (iy0 + iy1) // 2); put("o", ix1 - 1, (iy0 + iy1) // 2)


def patch(g, rng, rect, ch, whole=False):
    """Wet or icy floor in a room: the whole room, or a puddle-sized rectangle of it."""
    x0, y0, x1, y1 = rect
    if whole:
        g.fill(ch, x0, y0, x1, y1)
        return
    w, h = rng.randint(2, max(2, (x1 - x0) // 2)), rng.randint(2, max(2, (y1 - y0) // 2))
    px, py = rng.randint(x0, max(x0, x1 - w)), rng.randint(y0, max(y0, y1 - h))
    g.fill(ch, px, py, px + w, py + h)


def glass_front(g, rect):
    """Swaps the wall between a room and the corridor for glass, keeping the door and the corners."""
    x0, y0, x1, y1 = rect
    for wy in (y0 - 1, y1 + 1):
        if not (0 < wy < g.h - 1):
            continue
        beyond = wy - 1 if wy < y0 else wy + 1
        run = [x for x in range(x0 + 1, x1) if g.c[wy][x] == "#" and g.c[beyond][x] == "."]
        if len(run) >= 3 and any(g.c[wy][x] == "D" for x in range(x0, x1 + 1)):
            for x in run:
                g.c[wy][x] = "G"
            return True
    return False


def walkable_from_lift(g):
    """Every enemy, wave point and the exit must be reachable on foot from the lift. Doors count as
    open; glass, water deep enough to swim in, furniture, pedestals and barrels do not."""
    start = g.cells("P")[0]
    seen = {start}
    stack = [start]
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < g.w and 0 <= ny < g.h and (nx, ny) not in seen and g.c[ny][nx] not in SOLID:
                seen.add((nx, ny))
                stack.append((nx, ny))
    # The exit lift itself is solid on three sides; what matters is the cell at its doors.
    targets = g.cells(ENEMIES + "w")
    for ex, ey in g.cells("X"):
        if not any((ex + dx, ey + dy) in seen for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            return False
    return all(t in seen for t in targets)


def place_exit(g, rng, rooms):
    """Against the east wall, inside the room furthest from the lift."""
    east = [r for r in rooms if r["rect"][2] == g.w - 2]
    room = rng.choice(east) if east else max(rooms, key=lambda r: r["rect"][2])
    x0, y0, x1, y1 = room["rect"]
    ys = [y for y in range(y0 + 1, y1) if g.c[y][x1] == "." and g.c[y][x1 - 1] == "."]
    assert ys, "no room for the exit lift"
    g.c[rng.choice(ys)][x1] = "X"


def build_floor(spec):
    for attempt in range(60):
        rng = random.Random(spec["seed"] * 1000 + attempt)
        g = Grid(*spec["size"])
        try:
            rooms, corridors = LAYOUTS[spec["style"]](g, rng, **spec.get("layout", {}))
            place_exit(g, rng, rooms)
            rects = [r["rect"] for r in rooms]
            start = g.cells("P")[0]
            # Things to grab by the lift, clear of where the helper capsule goes.
            for i, ch in enumerate([c for c in spec.get("start", []) if c not in "fFj"]):
                for dx in range(5, 12):
                    x, y = start[0] + dx, start[1] + (-1 if i % 2 == 0 else 1)
                    near = [g.c[y + dy][x + ddx] for dy in (-1, 0, 1) for ddx in (-1, 0, 1)]
                    if g.c[y][x] == "." and "D" not in near and all(n in ".#" for n in near):
                        g.c[y][x] = ch
                        break
            for n in range(spec.get("glass", 0)):
                glass_front(g, rng.choice(rects))
            kinds = spec.get("furnish", ["office"])
            for rect in rects:
                if rng.random() < spec.get("furnished", 0.8):
                    furnish(g, rng, rect, rng.choice(kinds))
            for n in range(spec.get("wet", 0)):
                patch(g, rng, rng.choice(rects + corridors), "~")
            for n in range(spec.get("ice_rooms", 0)):
                patch(g, rng, rng.choice(rects), "i", whole=True)
            if spec.get("ice_corridor"):
                for c in corridors:
                    g.fill("i", *c)
            if spec.get("wet_corridor"):
                for c in corridors:
                    g.fill("~", c[0], c[1] + 1, c[2], c[3] - 1)
            everywhere = rects + corridors
            g.scatter(spec["enemies"], everywhere, spec["seed"] + attempt, floor=".~i")
            if spec.get("waves"):
                g.scatter({"w": spec.get("wave_points", 4)}, rects, spec["seed"] + attempt + 7, floor=".")
            items = {k: v for k, v in spec.get("items", {}).items() if k not in "fFj"}
            g.scatter(items, rects, spec["seed"] + attempt + 5, floor=".", margin=True)
            if DUCTS.get(spec["name"]):
                ducts(g, spec["seed"] + attempt + 31, DUCTS[spec["name"]])
            if CHANDELIERS.get(spec["name"]):
                g.scatter({"h": CHANDELIERS[spec["name"]]}, rects, spec["seed"] + attempt + 23, floor=".")
            g.gadgets(spec["name"], spec["seed"] + attempt + 11)
            g.gentlemen(spec["name"], spec["seed"] + attempt + 53)
            assert walkable_from_lift(g), "somebody cannot be reached"
            cover = len(g.cells("cso"))
            assert cover >= 12, f"only {cover} pieces of cover"
        except AssertionError:
            continue
        meta = {"title": spec["title"], "intro": spec["intro"], "theme": theme(spec["theme"])}
        if spec.get("waves"):
            meta["waves"] = spec["waves"]
        if spec.get("open_sky"):
            meta["open_sky"] = True
        if spec.get("in_space"):
            meta["in_space"] = True
        save(spec["name"], g, meta)
        return
    raise SystemExit(f"{spec['name']}: no seed in 60 produced a valid floor")


SPECS = [
    dict(name="f6_cafeteria", size=(40, 25), style="spine", seed=6, theme="cream", title="CAFETERIA",
         intro="CAFETERIA\\nWET FLOOR. THEY SLIP. YOU DON'T.", furnish=["tables", "tables", "counters"], wet=5, start=["p"],
         enemies={"a": 4, "q": 2, "u": 2, "x": 1}, items={"j": 3, "n": 3, "b": 2, "m": 3, "l": 1, "g": 2}),
    dict(name="f7_garage", size=(44, 27), style="double", seed=7, theme="concrete", title="PARKING",
         intro="PARKING LEVEL\\nSTORE ROOMS, PLANT ROOMS, AND BARRELS IN ALL OF THEM.", furnish=["columns", "racks", "tables"], start=["V"],
         enemies={"a": 5, "R": 2, "S": 2, "q": 2, "y": 1}, items={"g": 6, "M": 1, "r": 1, "k": 2},
         waves=[{"after_kills": 7, "count": 4, "armed": 3}]),
    dict(name="f8_archive", size=(40, 25), style="spine", seed=8, theme="paper", title="ARCHIVE",
         intro="ARCHIVE\\nFAST ONES IN THE STACKS. KEEP A KNIFE.", furnish=["racks", "racks", "office"], start=["n", "p"],
         layout={"min_w": 7, "max_w": 11}, enemies={"a": 2, "q": 3, "u": 1, "x": 2, "y": 1}, items={"j": 2, "n": 2, "F": 1, "k": 2, "g": 1}),
    dict(name="f11_sewers", size=(42, 25), style="double", seed=11, theme="sewer", title="SEWERS",
         intro="SEWERS\\nTHEY COME AT YOU WITH BLADES DOWN HERE.", furnish=["columns", "racks"], furnished=0.5, wet=6, wet_corridor=True, start=["p", "n"],
         enemies={"x": 4, "a": 3, "S": 1, "y": 2}, items={"j": 2, "T": 1, "F": 1, "g": 3, "b": 2, "L": 1}),
    dict(name="f12_kitchen", size=(42, 25), style="spine", seed=12, theme="stainless", title="KITCHEN",
         intro="KITCHEN\\nKNIVES EVERYWHERE. SO IS THE GAS.", furnish=["counters", "counters", "tables"], wet=3, ice_rooms=1, start=["M"],
         enemies={"a": 5, "U": 2, "q": 2, "x": 1}, items={"j": 3, "n": 5, "g": 6, "F": 1, "m": 2}),
    dict(name="f14_glassworks", size=(42, 25), style="spine", seed=14, theme="glass", title="GLASSWORKS",
         intro="GLASSWORKS\\nRIGHT CLICK TO LOOK DOWN THE SCOPE.", furnish=["office", "tables", "columns"], glass=7, start=["Y", "p"],
         layout={"min_w": 7, "max_w": 12}, enemies={"N": 3, "a": 4, "S": 1, "x": 1}, items={"V": 1, "b": 2, "g": 2, "F": 1}),
    dict(name="f15_restrooms", size=(40, 25), style="double", seed=15, theme="mint", title="RESTROOMS",
         intro="RESTROOMS\\nSTINK GRENADES. THROW ONE INTO A ROOM AND SHUT THE DOOR.", furnish=["stalls", "stalls", "tables"], wet=4, fart=5, start=["f", "p"],
         layout={"min_w": 5, "max_w": 8}, enemies={"a": 6, "u": 3, "q": 2, "x": 1}, items={"j": 2, "T": 1, "m": 3, "b": 2}),
    dict(name="f16_armoury", size=(42, 25), style="bsp", seed=16, theme="olive", title="ARMOURY",
         intro="ARMOURY\\nTAKE WHAT YOU LIKE. THEY DID.", furnish=["racks", "office", "columns"], start=["K", "T"],
         enemies={"H": 2, "R": 2, "S": 2, "U": 2, "a": 1, "x": 2, "y": 1}, items={"M": 1, "V": 1, "Y": 1, "F": 2, "r": 1, "n": 1, "g": 4, "A": 1, "L": 1}),
    dict(name="f17_greenhouse", size=(42, 27), style="double", seed=17, theme="leaf", title="GREENHOUSE",
         intro="GREENHOUSE\\nTHEY GROW THEM HERE. ONE OF THEM GROWS MORE OF HIMSELF.", furnish=["counters", "tables"], glass=8, wet=4, fart=2, start=["p", "n"],
         enemies={"C": 2, "a": 4, "x": 2, "y": 2}, items={"j": 3, "K": 1, "F": 1, "b": 2, "g": 2, "A": 1}),
    dict(name="f18_beanworks", size=(44, 27), style="spine", seed=18, theme="bean", title="BEANWORKS",
         intro="BEAN CANNERY\\nIT IS EXACTLY AS BAD AS IT SMELLS.", furnish=["vats", "vats", "counters"], fart=7, start=["f", "p"],
         layout={"min_w": 8, "max_w": 12}, enemies={"a": 5, "S": 2, "q": 3, "H": 1, "y": 1}, items={"g": 5, "M": 1, "n": 1}),
    dict(name="f19_tradingfloor", size=(50, 31), style="double", seed=19, theme="navy", title="TRADING FLOOR",
         intro="TRADING FLOOR\\nEVERYONE IS AT THEIR DESK.", furnish=["office", "office", "tables"], furnished=1.0, start=["K", "M"],
         layout={"min_w": 9, "max_w": 14}, enemies={"a": 5, "R": 3, "U": 3, "q": 3, "x": 2, "y": 1}, items={"j": 3, "F": 1, "g": 4, "k": 3},
         waves=[{"after_kills": 8, "count": 5, "armed": 4}, {"after_kills": 16, "count": 6, "armed": 4}], wave_points=6),
    dict(name="f20_generators", size=(42, 27), style="bsp", seed=20, theme="amber", title="GENERATORS",
         intro="GENERATOR HALL\\nONE SPARK.", furnish=["vats", "racks", "columns"], start=["V", "Y"],
         enemies={"a": 5, "R": 2, "H": 2, "N": 1, "x": 1}, items={"g": 10, "r": 1, "F": 1}),
    dict(name="f22_cryolab", size=(42, 25), style="spine", seed=22, theme="cryo", title="CRYO LAB",
         intro="CRYO LAB\\nFREEZE BOMBS. USE ALL OF THEM.", furnish=["tables", "counters"], glass=6, ice_rooms=3, ice_corridor=True, start=["F", "p"],
         enemies={"a": 4, "U": 2, "q": 3, "C": 1, "y": 2}, items={"F": 3, "M": 1, "n": 1, "g": 1, "A": 1}),
    dict(name="f23_mirrors", size=(44, 27), style="bsp", seed=23, theme="silver", title="HALL OF GLASS",
         intro="HALL OF GLASS\\nEVERYONE CAN SEE EVERYONE.", furnish=["columns", "tables"], glass=12, start=["V", "Y"],
         layout={"min_side": 6, "max_side": 10}, enemies={"N": 2, "S": 3, "a": 4, "H": 1, "x": 1}, items={"T": 1, "F": 1, "b": 2, "g": 2}),
    dict(name="f24_strongrooms", size=(44, 27), style="double", seed=24, theme="bank", title="STRONGROOMS",
         intro="STRONGROOMS\\nA DOOR IS A SUGGESTION. SO IS A WALL.", furnish=["racks", "office"], start=["r", "p"],
         layout={"min_w": 5, "max_w": 8}, enemies={"a": 2, "S": 3, "H": 2, "R": 2, "y": 2, "C": 1}, items={"r": 1, "T": 1, "K": 1, "V": 1, "g": 3, "A": 1}),
    dict(name="f25_skygarden", size=(46, 29), style="bsp", seed=25, theme="sky", title="SKY GARDEN", open_sky=True,
         intro="SKY GARDEN\\nWALLED GARDENS. LONG SIGHTLINES. THEIRS TOO.", furnish=["counters", "columns", "tables"], wet=6, glass=4, start=["Y", "K"],
         layout={"min_side": 8, "max_side": 14}, enemies={"N": 3, "R": 3, "a": 3, "q": 2, "y": 2, "x": 1}, items={"F": 1, "g": 3, "L": 1}),
    dict(name="f26_morgue", size=(46, 29), style="double", seed=26, theme="morgue", title="MORGUE",
         intro="MORGUE\\nONE OF THEM IS SEVERAL OF THEM.", furnish=["slabs", "slabs", "racks"], ice_rooms=1, start=["T", "n"],
         enemies={"C": 2, "x": 4, "a": 3, "H": 1}, items={"j": 2, "n": 2, "F": 2, "p": 1, "L": 1}),
    dict(name="f27_furnace", size=(44, 27), style="bsp", seed=27, theme="furnace", title="FURNACE",
         intro="FURNACE ROOMS\\nTWELVE BARRELS. COUNT THEM.", furnish=["vats", "columns", "racks"], start=["K", "F"],
         enemies={"S": 3, "R": 3, "U": 3, "a": 3, "H": 2, "y": 1}, items={"g": 12, "V": 1, "r": 1}),
    dict(name="f28_waterworks", size=(46, 27), style="double", seed=28, theme="harbour", title="WATERWORKS",
         intro="WATERWORKS\\nEVERY CORRIDOR IS FLOODED. LET THEM RUN.", furnish=["vats", "columns", "counters"], wet=8, wet_corridor=True, start=["M", "n"],
         enemies={"q": 4, "a": 5, "R": 2, "y": 3, "C": 1}, items={"j": 3, "F": 2, "T": 1, "g": 3, "L": 1}),
    dict(name="f29_penthouse", size=(52, 31), style="double", seed=29, theme="gold", title="PENTHOUSE",
         intro="PENTHOUSE\\nEVERYTHING THEY HAVE LEFT.", furnish=["office", "tables", "columns", "counters"], wet=3, ice_rooms=1, glass=5, fart=2,
         start=["K", "T"], layout={"min_w": 8, "max_w": 12},
         enemies={"a": 4, "R": 2, "S": 2, "U": 2, "N": 2, "H": 2, "q": 2, "C": 1, "x": 2, "y": 2}, items={"j": 2, "Y": 1, "F": 2, "r": 1, "n": 1, "V": 1, "g": 5, "A": 1, "L": 1},
         waves=[{"after_kills": 9, "count": 5, "armed": 4}, {"after_kills": 18, "count": 6, "armed": 5}], wave_points=5),
    dict(name="f31_airlock", in_space=True, size=(40, 25), style="spine", seed=31, theme="airlock", title="AIRLOCK",
         intro="STATION AIRLOCK\\nTHEY WERE EXPECTING THE HELICOPTER.", furnish=["racks", "office"], start=["p"],
         layout={"min_w": 6, "max_w": 10}, enemies={"a": 5, "u": 2, "q": 2, "x": 1}, items={"p": 2, "k": 2, "g": 2}),
    dict(name="f32_crewring", in_space=True, size=(44, 27), style="double", seed=32, theme="crewring", title="CREW RING",
         intro="CREW RING\\nBUNKS, MESS, AND EVERYONE IN THEM.", furnish=["tables", "office", "counters"], start=["K"],
         enemies={"a": 5, "R": 2, "q": 3, "y": 1, "x": 1}, items={"j": 2, "m": 3, "b": 2, "g": 2, "n": 2}),
    dict(name="f33_hydroponics", in_space=True, size=(42, 27), style="spine", seed=33, theme="hydro", title="HYDROPONICS",
         intro="HYDROPONICS\\nTHE ONLY GREEN FOR A HUNDRED MILES.", furnish=["counters", "tables"], glass=6, wet=5, start=["p", "n"],
         layout={"min_w": 7, "max_w": 12}, enemies={"C": 1, "a": 4, "q": 2, "x": 2, "y": 1}, items={"j": 3, "M": 1, "F": 1, "g": 2, "A": 1}),
    dict(name="f34_solararray", in_space=True, size=(46, 29), style="bsp", seed=34, theme="solar", title="SOLAR ARRAY", open_sky=True,
         intro="SOLAR ARRAY\\nNO COVER OUT HERE BUT WHAT THEY BUILT.", furnish=["columns", "racks"], start=["Y", "p"],
         layout={"min_side": 7, "max_side": 12}, enemies={"N": 3, "a": 4, "R": 2, "H": 1, "q": 2}, items={"V": 1, "F": 1, "g": 3, "L": 1}),
    dict(name="f35_cargobay", in_space=True, size=(46, 29), style="double", seed=35, theme="cargo", title="CARGO BAY",
         intro="CARGO BAY\\nEVERY CRATE IS SOMEBODY ELSE'S PROBLEM.", furnish=["racks", "racks", "columns"], start=["T", "r"],
         enemies={"a": 5, "S": 3, "U": 2, "H": 2, "x": 2}, items={"r": 1, "K": 1, "g": 5, "k": 2, "n": 1}),
    dict(name="f36_reactor", in_space=True, size=(44, 27), style="bsp", seed=36, theme="reactor", title="REACTOR",
         intro="REACTOR\\nMIND THE BARRELS. MIND ALL OF THEM.", furnish=["vats", "columns", "racks"], start=["M", "F"],
         enemies={"a": 4, "R": 3, "S": 2, "N": 1, "y": 2, "C": 1}, items={"g": 9, "F": 2, "V": 1, "r": 1}),
    dict(name="f37_comms", in_space=True, size=(42, 25), style="spine", seed=37, theme="comms", title="COMMS",
         intro="COMMS DECK\\nCUT THE SIGNAL BEFORE THEY CALL HOME.", furnish=["office", "racks", "tables"], furnished=1.0, start=["A", "p"],
         layout={"min_w": 6, "max_w": 10}, enemies={"a": 4, "U": 3, "q": 3, "x": 1, "y": 1}, items={"M": 1, "n": 2, "k": 3, "g": 2, "j": 2}),
    dict(name="f38_observation", in_space=True, size=(46, 29), style="bsp", seed=38, theme="observ", title="OBSERVATION DECK", open_sky=True,
         intro="OBSERVATION DECK\\nGLASS ALL ROUND. SO ARE THEY.", furnish=["tables", "columns"], glass=12, start=["Y", "V"],
         layout={"min_side": 7, "max_side": 12}, enemies={"N": 3, "S": 2, "a": 4, "H": 2, "q": 2}, items={"F": 2, "T": 1, "b": 2, "g": 2}),
    dict(name="f39_docking", in_space=True, open_sky=True, size=(48, 29), style="double", seed=39, theme="docking", title="DOCKING RING",
         intro="DOCKING RING\\nTHE LAST WAY OFF IS BEHIND THEM.", furnish=["racks", "columns", "office"], start=["K", "T"],
         layout={"min_w": 7, "max_w": 12}, enemies={"a": 5, "R": 3, "S": 2, "U": 2, "H": 2, "x": 2, "y": 1}, items={"r": 1, "Y": 1, "F": 1, "g": 4, "A": 1},
         waves=[{"after_kills": 8, "count": 5, "armed": 4}], wave_points=5),
    dict(name="f40_bridge", in_space=True, open_sky=True, size=(50, 31), style="bsp", seed=40, theme="bridge", title="THE BRIDGE",
         intro="THE BRIDGE\\nEVERYONE LEFT IS IN THIS ROOM.", furnish=["office", "tables", "columns"], glass=6, start=["K", "V"],
         layout={"min_side": 8, "max_side": 13},
         enemies={"a": 5, "R": 3, "S": 2, "U": 2, "N": 2, "H": 2, "q": 2, "C": 1, "x": 2, "y": 2}, items={"Y": 1, "F": 2, "M": 1, "r": 1, "g": 5, "L": 1, "A": 1},
         waves=[{"after_kills": 10, "count": 6, "armed": 5}, {"after_kills": 20, "count": 6, "armed": 5}], wave_points=6),
]


def f9_pool():
    """Changing rooms along a corridor, and the pool hall beyond them."""
    g = Grid(42, 30)
    g.room(1, 5, 40, 7)                                          # corridor
    for x0 in (1, 9, 17, 25, 33):                                # changing rooms and showers
        g.room(x0, 1, x0 + 6, 3)
        g.put("D", (x0 + 3, 4))
        g.put("c", (x0 + 1, 1), (x0 + 5, 1))
    for x in (8, 16, 24, 32):
        g.put("D", (x, 2))
    g.room(1, 9, 40, 28)                                         # pool hall
    g.put("D", (6, 8), (20, 8), (35, 8))
    g.fill("W", 7, 13, 34, 24)                                   # the pool: deep water, a real basin
    g.fill("~", 5, 11, 36, 12); g.fill("~", 5, 25, 36, 26); g.fill("~", 5, 13, 6, 24); g.fill("~", 35, 13, 36, 24)
    g.put("c", (2, 14), (2, 15), (2, 20), (2, 21), (39, 14), (39, 15), (39, 20), (39, 21), (12, 27), (13, 27), (28, 27), (29, 27))
    g.put("#", (10, 5), (22, 7), (31, 5))
    g.put("P", (1, 6)); g.put("X", (40, 27))
    g.put("p", (6, 5)); g.put("T", (3, 27)); g.put("b", (19, 1)); g.put("n", (27, 1))
    g.scatter({"a": 6, "S": 2, "q": 3}, [(1, 1, 40, 3), (8, 5, 40, 7), (1, 9, 40, 28)], 91, floor=".~")
    assert walkable_from_lift(g), "pool: somebody cannot be reached"
    g.gadgets("f9_pool", 713)
    g.gentlemen("f9_pool", 754)
    save("f9_pool", g, {"title": "POOL", "intro": "POOL\\nFREEZE THEM, OR LET THEM RUN ON THE WET DECK.", "theme": theme("aqua")})


def f10_vault():
    """An antechamber, the vault floor itself, and strongrooms off it where reinforcements wait."""
    g = Grid(40, 34)
    g.room(1, 26, 12, 32)                                        # antechamber, where the lift is
    g.room(8, 6, 31, 24)                                         # the vault floor
    g.put("D", (10, 25))
    for (x0, y0, x1, y1, door) in ((1, 6, 6, 12, (7, 9)), (1, 14, 6, 20, (7, 17)), (33, 6, 38, 12, (32, 9)),
                                   (33, 14, 38, 20, (32, 17)), (14, 1, 25, 4, (19, 5)), (16, 26, 38, 32, (20, 25))):
        g.room(x0, y0, x1, y1)
        g.put("D", door)
    g.put("w", (3, 9), (3, 17), (36, 9), (36, 17), (19, 2))
    for (x, y) in ((13, 10), (13, 11), (26, 10), (26, 11), (13, 19), (13, 20), (26, 19), (26, 20), (19, 14), (20, 14), (19, 16), (20, 16)):
        g.put("#", (x, y))                                       # wall stubs to fight round
    g.put("c", (17, 22), (18, 22), (21, 22), (22, 22), (10, 15), (29, 15))
    g.put("P", (1, 29)); g.put("X", (38, 29)); g.put("B", (19, 9))
    g.put("H", (14, 14), (25, 14)); g.put("R", (10, 8), (29, 8)); g.put("a", (19, 19), (29, 22))
    g.put("g", (11, 22), (28, 12), (16, 7), (23, 21))
    g.put("K", (6, 27)); g.put("T", (8, 31)); g.put("V", (10, 27)); g.put("r", (6, 31))
    g.put("c", (22, 28), (23, 28), (30, 30), (31, 30), (3, 27), (3, 28), (35, 7), (35, 15), (16, 2), (23, 2))
    assert walkable_from_lift(g), "vault: somebody cannot be reached"
    g.gadgets("f10_vault", 867)
    g.gentlemen("f10_vault", 908)
    save("f10_vault", g, {"title": "THE VAULT", "intro": "THE VAULT\\nTHE BRUTE. TWELVE HITS. DO NOT LET HIM REACH YOU.",
                          "boss": "brute", "theme": theme("steel")})



def f13_basement():
    """Level 13 is not a floor of the building. The lift goes down instead of up, the screen
    gives up on the way, and the doors open on a laboratory nobody is supposed to see: rows of
    growing tanks, one of them broken open with its fluid still spreading, and what came out of
    it waiting in the middle with its guards."""
    g = Grid(38, 28)
    g.room(1, 22, 9, 26)                                          # the lift lobby, where you arrive
    g.room(1, 12, 9, 20)                                          # the tank room off it
    g.room(11, 12, 20, 26)                                        # the corridor between
    g.room(4, 1, 34, 10)                                          # the growing hall: where he is
    g.room(22, 12, 36, 26)                                        # the plant room, and the way out
    g.put("D", (10, 24), (10, 16), (21, 18), (15, 11), (28, 11))
    # Tanks down both sides of the hall, and the cracked one facing the door you come in by.
    for x in range(7, 32, 3):
        g.put("z", (x, 2))
    for x in range(8, 30, 4):
        g.put("z", (x, 9))
    g.put("Z", (15, 9))                                           # the broken one
    for (x, y) in ((14, 8), (15, 8), (16, 8), (14, 7), (16, 7), (15, 10)):
        g.put("~", (x, y))                                        # its fluid, still on the floor
    g.put("z", (3, 14), (3, 18), (8, 14))
    g.put("Z", (8, 18))
    g.put("~", (8, 17), (7, 18), (8, 19))
    # Cover to fight him round, and the machines that keep the tanks running.
    g.put("o", (11, 5), (20, 5), (29, 5), (11, 3), (29, 3))
    g.put("c", (24, 14), (25, 14), (33, 20), (34, 20), (13, 20), (13, 21))
    g.put("s", (31, 14), (31, 15), (31, 16))
    g.put("P", (1, 24))
    g.put("X", (35, 24))
    g.put("B", (19, 6))                                           # the beast, in the middle of the hall
    # The gun they left by the lift, and what is lying about further in.
    g.put("K", (3, 24)); g.put("p", (5, 25)); g.put("g", (6, 13), (26, 24), (33, 13))
    g.put("E", (9, 4), (26, 4), (13, 14), (30, 22))                # guards with carrot guns
    g.put("a", (17, 24), (33, 17)); g.put("x", (24, 20)); g.put("H", (26, 8))
    g.put("n", (2, 13)); g.put("T", (35, 13))
    for spot in ((9, 2), (19, 2), (29, 2), (6, 9), (16, 9), (26, 9), (3, 16), (15, 14),
                 (15, 22), (25, 16), (31, 22), (5, 24), (33, 18)):
        if g.c[spot[1]][spot[0]] == ".":
            g.put("d", spot)      # strip lights, most of them on their way out
    ducts(g, 913, 3)      # the ducts down here are how it gets about
    assert walkable_from_lift(g), "basement: somebody cannot be reached"
    g.gadgets("f13_basement", 913)
    g.gentlemen("f13_basement", 954)
    save("f13_basement", g, {"title": "LEVEL ????",
                             "intro": "SUB-BASEMENT\\nTHIS FLOOR IS NOT ON THE BUTTONS.",
                             "boss": "beast", "theme": theme("basement")})


def f21_lockdown():
    """A cell block: the yard in the middle, cells down both sides, guard rooms at the ends."""
    g = Grid(44, 32)
    g.room(9, 8, 34, 23)                                         # the yard
    for i, x0 in enumerate(range(9, 33, 5)):                      # cells north and south
        g.room(x0, 2, x0 + 3, 6); g.put("D", (x0 + 1, 7))
        g.room(x0, 25, x0 + 3, 29); g.put("D", (x0 + 2, 24))
    g.room(1, 8, 7, 14); g.put("D", (8, 11))                     # west guard room
    g.room(1, 17, 7, 29); g.put("D", (8, 20))                    # the way in
    g.room(36, 8, 42, 14); g.put("D", (35, 11))
    g.room(36, 17, 42, 23); g.put("D", (35, 20))
    g.put("w", (10, 3), (25, 3), (15, 28), (30, 28), (39, 10))
    for (x, y) in ((15, 12), (15, 13), (28, 12), (28, 13), (15, 18), (15, 19), (28, 18), (28, 19), (21, 15), (22, 15)):
        g.put("#", (x, y))
    g.put("c", (12, 16), (31, 15), (20, 21), (23, 10), (3, 10), (4, 10), (38, 19), (39, 19), (3, 24), (4, 24), (3, 27), (4, 27))
    g.put("P", (1, 22)); g.put("X", (42, 20)); g.put("B", (22, 10))
    g.put("H", (14, 10), (29, 10), (22, 19)); g.put("N", (4, 12), (39, 12))
    g.put("Y", (6, 19)); g.put("K", (6, 25)); g.put("V", (2, 19)); g.put("g", (12, 21), (31, 21), (20, 12))
    assert walkable_from_lift(g), "lockdown: somebody cannot be reached"
    g.gadgets("f21_lockdown", 278)
    g.gentlemen("f21_lockdown", 319)
    save("f21_lockdown", g, {"title": "LOCKDOWN", "intro": "LOCKDOWN\\nTHE WARDEN. THREE ROUNDS THROUGH THE GLASS.",
                             "boss": "warden", "theme": theme("prison")})


def new_floors():
    for spec in SPECS:
        build_floor(spec)
    f9_pool()
    f10_vault()
    f13_basement()
    f21_lockdown()


if __name__ == "__main__":
    f1_lobby()
    f2_offices()
    f3_servers()
    f4_labs()
    f5_executive()
    roof()
    new_floors()
