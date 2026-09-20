#!/usr/bin/env python3
"""Generates the HQ floor grids into levels/. Re-run after editing: python3 tools/make_levels.py
Hand edits to the generated .txt files are overwritten, so change the floor here instead."""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "levels")


ENEMIES = "auBRSHqZNU"


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

    def scatter(self, spec, rects, seed, gap=4.2, from_player=6.5, floor=".", margin=False):
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
}


def theme(name):
    wall, floor, prop, ambient, sky, energy, sun = THEMES[name]
    return {"wall": wall, "floor": floor, "prop": prop, "ambient": ambient, "sky": sky, "energy": energy, "sun": sun}


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
    g.put("a", (9, 6), (31, 3), (4, 13), (5, 23), (33, 23))
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
    save("roof", g, {"intro": "ROOF\nTHE DIRECTOR. THREE BULLETS.", "open_sky": True, "exit": "helipad"})


# ---------------------------------------------------------------- floors 6 to 29

def f6_cafeteria():
    g = Grid(34, 22)
    g.room(1, 1, 24, 20)      # dining hall
    g.room(26, 1, 32, 9)      # kitchen
    g.room(26, 11, 32, 20)    # store
    g.put("D", (25, 5), (25, 15), (29, 10))
    for y in (4, 8, 12, 16):
        for x in (5, 10, 15, 20):
            g.put("c", (x, y), (x + 1, y))
    g.put("P", (1, 10)); g.put("X", (32, 18))
    g.fill("~", 7, 5, 9, 7); g.fill("~", 16, 13, 19, 15); g.fill("~", 12, 9, 13, 11)
    g.put("o", (3, 3), (3, 18), (13, 2), (13, 19), (23, 3), (23, 18), (22, 10))
    g.put("n", (27, 2), (31, 2), (27, 8))
    g.put("p", (3, 10)); g.put("g", (31, 8), (28, 19))
    g.scatter({"a": 5, "q": 2, "u": 2}, [(8, 1, 24, 20), (26, 1, 32, 20)], 61)
    g.scatter({"b": 2, "m": 3, "l": 1}, [(2, 1, 24, 20)], 62, margin=True)
    save("f6_cafeteria", g, {"title": "CAFETERIA", "intro": "CAFETERIA\nWET FLOOR. THEY SLIP. YOU DON'T.", "theme": theme("cream")})


def f7_garage():
    g = Grid(44, 26)
    g.room(1, 1, 42, 24)
    g.pillars(1, 1, 42, 24, step=5, ox=4, oy=3)
    g.put("P", (1, 12)); g.put("X", (42, 13))
    for (x, y) in ((8, 5), (8, 19), (17, 9), (17, 15), (27, 5), (27, 19), (35, 10), (35, 15)):   # parked cars
        g.put("c", (x, y), (x + 1, y), (x + 2, y))
    g.put("g", (12, 12), (22, 4), (22, 20), (31, 12), (38, 4), (38, 21))
    g.put("V", (5, 12)); g.put("M", (20, 12)); g.put("r", (3, 3))
    g.put("w", (42, 2), (42, 23), (21, 1), (21, 24))
    g.scatter({"a": 6, "R": 2, "S": 2, "q": 2}, [(9, 1, 42, 24)], 71)
    save("f7_garage", g, {"title": "PARKING", "intro": "PARKING LEVEL\nLOTS OF PILLARS. LOTS OF BARRELS.", "theme": theme("concrete"),
                          "waves": [{"after_kills": 7, "count": 4, "armed": 3}]})


def f8_archive():
    g = Grid(36, 24)
    g.room(1, 1, 8, 22)       # reading room
    g.room(10, 1, 34, 22)     # stacks
    g.put("D", (9, 4), (9, 19))
    for x in range(12, 34, 3):
        for y in list(range(2, 10)) + list(range(14, 22)):
            g.put("s", (x, y))
    g.put("P", (1, 11)); g.put("X", (34, 12))
    g.put("o", (4, 4), (4, 18), (7, 11), (10, 11), (22, 11), (33, 2), (33, 21))
    g.put("n", (3, 9), (3, 14)); g.put("p", (6, 3)); g.put("k", (6, 20)); g.put("F", (20, 12))
    g.scatter({"a": 5, "q": 4, "u": 1}, [(10, 1, 34, 22)], 81)
    save("f8_archive", g, {"title": "ARCHIVE", "intro": "ARCHIVE\nFAST ONES IN THE STACKS. KEEP A KNIFE.", "theme": theme("paper")})


def f9_pool():
    g = Grid(38, 24)
    g.room(1, 1, 36, 22)
    g.fill("W", 11, 7, 26, 16)          # the pool: deep water, a real basin
    g.fill("~", 9, 5, 28, 6); g.fill("~", 9, 17, 28, 18)     # splashed deck
    g.put("P", (1, 11)); g.put("X", (36, 12))
    g.put("o", (5, 3), (5, 20), (18, 3), (18, 20), (32, 3), (32, 20), (8, 11), (30, 12))
    g.put("c", (3, 7), (3, 8), (3, 15), (3, 16), (34, 7), (34, 16))
    g.put("F", (4, 11)); g.put("p", (6, 5)); g.put("T", (31, 20)); g.put("b", (6, 18))
    g.scatter({"a": 6, "S": 2, "q": 3}, [(10, 1, 36, 22)], 91, floor=".~")
    save("f9_pool", g, {"title": "POOL", "intro": "POOL\nFREEZE THEM. THEN BREAK THEM.", "theme": theme("aqua")})


def f10_vault():
    g = Grid(34, 34)
    g.room(4, 4, 29, 29)
    g.room(15, 1, 18, 2); g.room(15, 31, 18, 32); g.room(1, 15, 2, 18); g.room(31, 15, 32, 18)
    g.put("D", (16, 3), (17, 30), (3, 16), (30, 17))
    g.put("w", (16, 1), (17, 32), (1, 17), (32, 16))
    g.pillars(4, 4, 29, 29, step=5, ox=3, oy=3)
    g.put("P", (4, 27)); g.put("X", (29, 6)); g.put("B", (17, 9))
    g.put("H", (12, 12), (22, 12)); g.put("R", (9, 7), (25, 8)); g.put("a", (17, 15), (27, 14))
    g.put("g", (8, 16), (25, 17), (16, 21), (12, 6))
    g.put("K", (7, 25)); g.put("T", (10, 28)); g.put("V", (5, 22)); g.put("F", (12, 25), (22, 25)); g.put("r", (8, 28))
    save("f10_vault", g, {"title": "THE VAULT", "intro": "THE VAULT\nTHE BRUTE. TWELVE HITS. DO NOT LET HIM REACH YOU.",
                          "boss": "brute", "theme": theme("steel")})


def f11_sewers():
    g = Grid(40, 26)
    g.ring(1, 1, 38, 24, width=3)
    g.room(4, 11, 35, 14)               # cross tunnel
    g.room(18, 4, 21, 21)
    g.fill("~", 2, 2, 37, 2); g.fill("~", 2, 23, 37, 23); g.fill("~", 5, 12, 34, 13); g.fill("~", 19, 5, 20, 20)
    g.put("P", (1, 3)); g.put("X", (38, 22))
    g.put("o", (8, 1), (30, 1), (8, 24), (30, 24), (10, 11), (28, 14), (18, 8), (21, 17))
    g.put("p", (3, 5)); g.put("n", (2, 8)); g.put("T", (19, 12)); g.put("F", (36, 5))
    g.put("g", (12, 3), (27, 22), (36, 12))
    g.scatter({"Z": 6, "a": 4, "S": 1}, [(1, 1, 38, 24)], 111, floor=".~")
    save("f11_sewers", g, {"title": "SEWERS", "intro": "SEWERS\nSOMETHING IS UNDER THE FLOOR.", "theme": theme("sewer")})


def f12_kitchen():
    g = Grid(38, 22)
    g.room(1, 1, 27, 20)       # line kitchen
    g.room(29, 1, 36, 9)       # cold room
    g.room(29, 11, 36, 20)     # pantry
    g.put("D", (28, 5), (28, 15), (32, 10))
    for y in (4, 9, 14, 18):
        for x in range(5, 25, 2):
            g.put("c", (x, y))
    g.fill("i", 30, 2, 35, 8)
    g.fill("~", 12, 6, 15, 7); g.fill("~", 18, 11, 21, 12)
    g.put("P", (1, 10)); g.put("X", (36, 17))
    g.put("o", (3, 2), (3, 19), (14, 2), (14, 19), (26, 2), (26, 19), (26, 11))
    g.put("n", (2, 5), (2, 15), (6, 2), (10, 19), (20, 2))
    g.put("g", (8, 11), (16, 16), (23, 6), (23, 16), (34, 12), (31, 19))
    g.put("F", (35, 3)); g.put("M", (4, 10))
    g.scatter({"a": 6, "U": 2, "q": 2}, [(9, 1, 27, 20), (29, 1, 36, 20)], 121, floor=".~i")
    save("f12_kitchen", g, {"title": "KITCHEN", "intro": "KITCHEN\nKNIVES EVERYWHERE. SO IS THE GAS.", "theme": theme("stainless")})


def f13_coldstore():
    g = Grid(36, 26)
    g.room(1, 1, 34, 24)
    g.fill("i", 6, 3, 30, 22)
    for x in (9, 15, 21, 27):
        for y in (5, 6, 7, 12, 13, 18, 19, 20):
            g.put("s", (x, y))
    g.put("P", (1, 12)); g.put("X", (34, 13))
    g.put("o", (4, 3), (4, 22), (12, 10), (18, 15), (24, 10), (32, 3), (32, 22))
    g.put("F", (3, 9), (3, 15), (18, 2)); g.put("p", (2, 5)); g.put("K", (33, 20)); g.put("n", (2, 20))
    g.scatter({"a": 6, "R": 2, "q": 3}, [(8, 1, 34, 24)], 131, floor=".i")
    save("f13_coldstore", g, {"title": "COLD STORE", "intro": "COLD STORE\nTHE WHOLE FLOOR IS ICE.", "theme": theme("frost")})


def f14_glassworks():
    g = Grid(38, 24)
    g.room(1, 1, 36, 22)
    for x in (8, 15, 22, 29):                                   # glass partitions with gaps
        for y in list(range(2, 9)) + list(range(11, 15)) + list(range(17, 22)):
            g.put("G", (x, y))
    for y in (8, 16):
        for x in list(range(10, 14)) + list(range(24, 28)):
            g.put("G", (x, y))
    g.put("P", (1, 12)); g.put("X", (36, 11))
    g.put("o", (4, 4), (4, 19), (11, 12), (18, 4), (18, 19), (26, 12), (33, 4), (33, 19))
    g.put("Y", (3, 12)); g.put("p", (3, 7)); g.put("V", (19, 12)); g.put("b", (5, 16), (12, 3))
    g.scatter({"N": 3, "a": 5, "S": 1}, [(10, 1, 36, 22)], 141)
    save("f14_glassworks", g, {"title": "GLASSWORKS", "intro": "GLASSWORKS\nRIGHT CLICK TO LOOK DOWN THE SCOPE.", "theme": theme("glass")})


def f15_restrooms():
    g = Grid(36, 24)
    g.room(1, 9, 34, 14)                 # corridor
    for i, x0 in enumerate((1, 10, 19, 28)):
        g.room(x0, 1, x0 + 6, 7); g.room(x0, 16, x0 + 6, 22)
        g.put("D", (x0 + 3, 8), (x0 + 3, 15))
        for sx in (x0 + 1, x0 + 3, x0 + 5):                     # stall dividers
            g.put("c", (sx, 2), (sx, 21))
    g.put("P", (1, 12)); g.put("X", (34, 11))
    g.put("f", (6, 11), (14, 4), (23, 19), (30, 11), (18, 12))
    g.fill("~", 12, 10, 14, 13); g.fill("~", 24, 10, 25, 13)
    g.put("o", (9, 9), (9, 14), (17, 9), (17, 14), (26, 9), (26, 14))
    g.put("p", (3, 10)); g.put("n", (3, 13)); g.put("T", (21, 3)); g.put("m", (4, 4), (31, 20))
    g.scatter({"a": 7, "u": 3, "q": 2}, [(8, 1, 34, 22)], 151, floor=".~")
    save("f15_restrooms", g, {"title": "RESTROOMS", "intro": "RESTROOMS\nSHOOT THE GREEN CLOUD. HOLD YOUR NOSE.", "theme": theme("mint")})


def f16_armoury():
    g = Grid(38, 24)
    g.room(1, 8, 8, 15)                  # the cage, where you start
    g.room(10, 1, 36, 22)
    g.put("D", (9, 10), (9, 13))
    g.pillars(10, 1, 36, 22, step=4, ox=3, oy=3)
    for y in (6, 17):
        for x in (14, 20, 26, 32):
            g.put("s", (x, y))
    g.put("P", (1, 12)); g.put("X", (36, 11))
    g.put("K", (3, 9)); g.put("T", (5, 9)); g.put("M", (7, 9)); g.put("V", (3, 14)); g.put("Y", (5, 14)); g.put("F", (7, 14)); g.put("r", (2, 11))
    g.put("g", (16, 12), (24, 4), (24, 19), (33, 12))
    g.scatter({"H": 2, "R": 3, "S": 2, "U": 2, "a": 3}, [(11, 1, 36, 22)], 161)
    save("f16_armoury", g, {"title": "ARMOURY", "intro": "ARMOURY\nTAKE WHAT YOU LIKE. THEY DID.", "theme": theme("olive")})


def f17_greenhouse():
    g = Grid(38, 26)
    g.room(1, 1, 36, 24)
    for x0 in (5, 14, 23):                                       # planter beds: low cover with soil between
        for y0 in (4, 11, 18):
            g.put("c", (x0, y0), (x0 + 1, y0), (x0 + 2, y0), (x0 + 3, y0))
    for x in (10, 19, 28):
        for y in list(range(2, 6)) + list(range(9, 17)) + list(range(20, 24)):
            g.put("G", (x, y))
    g.fill("~", 6, 7, 8, 8); g.fill("~", 24, 14, 26, 15); g.fill("~", 15, 21, 17, 22)
    g.put("P", (1, 13)); g.put("X", (36, 12))
    g.put("o", (3, 3), (3, 22), (12, 13), (21, 7), (21, 19), (31, 3), (31, 22), (34, 8))
    g.put("p", (3, 10)); g.put("n", (3, 16)); g.put("K", (33, 22)); g.put("F", (20, 13))
    g.scatter({"Z": 8, "a": 4}, [(1, 1, 36, 24)], 171, floor=".~")
    save("f17_greenhouse", g, {"title": "GREENHOUSE", "intro": "GREENHOUSE\nTHEY GROW THEM HERE.", "theme": theme("leaf")})


def f18_beanworks():
    g = Grid(40, 24)
    g.room(1, 1, 38, 22)
    for (x, y) in ((8, 6), (8, 16), (16, 11), (24, 6), (24, 16), (32, 11)):     # vats: four pillars each
        g.put("o", (x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1))
    g.put("f", (5, 11), (12, 4), (12, 19), (20, 5), (20, 18), (28, 12), (35, 5))
    g.put("g", (11, 11), (20, 12), (29, 5), (29, 18), (36, 17))
    g.put("c", (4, 3), (5, 3), (34, 20), (35, 20), (14, 21), (15, 21))
    g.put("P", (1, 11)); g.put("X", (38, 12))
    g.put("p", (3, 8)); g.put("T", (3, 15)); g.put("M", (19, 2)); g.put("n", (19, 21))
    g.scatter({"a": 6, "S": 2, "q": 3, "H": 1}, [(9, 1, 38, 22)], 181)
    save("f18_beanworks", g, {"title": "BEANWORKS", "intro": "BEAN CANNERY\nIT IS EXACTLY AS BAD AS IT SMELLS.", "theme": theme("bean")})


def f19_tradingfloor():
    g = Grid(46, 30)
    g.room(1, 1, 44, 28)
    for y in range(4, 27, 4):
        for x in range(6, 40, 6):
            g.put("c", (x, y), (x + 1, y), (x + 2, y))
    g.pillars(1, 1, 44, 28, step=6, ox=3, oy=2)
    g.put("P", (1, 14)); g.put("X", (44, 15))
    g.put("w", (44, 2), (44, 27), (22, 1), (23, 28), (1, 2), (1, 27))
    g.put("K", (3, 12)); g.put("M", (3, 17)); g.put("F", (22, 14)); g.put("g", (14, 14), (30, 14), (22, 6), (22, 23))
    g.scatter({"a": 8, "R": 3, "U": 3, "q": 4}, [(9, 1, 44, 28)], 191)
    save("f19_tradingfloor", g, {"title": "TRADING FLOOR", "intro": "TRADING FLOOR\nEVERYONE IS AT THEIR DESK.", "theme": theme("navy"),
                                 "waves": [{"after_kills": 8, "count": 5, "armed": 4}, {"after_kills": 16, "count": 6, "armed": 4}]})


def f20_generators():
    g = Grid(40, 26)
    g.room(1, 1, 38, 24)
    for x in (7, 14, 21, 28):                                    # generator blocks
        g.wall(x, 5, x + 2, 9); g.wall(x, 16, x + 2, 20)
    g.put("o", (4, 12), (11, 12), (18, 12), (25, 12), (32, 12), (36, 3), (36, 22))
    g.put("g", (5, 4), (12, 7), (19, 7), (26, 7), (33, 7), (12, 18), (19, 18), (26, 18), (33, 18), (36, 12))
    g.put("P", (1, 13)); g.put("X", (38, 12))
    g.put("V", (3, 10)); g.put("Y", (3, 16)); g.put("r", (2, 3)); g.put("F", (20, 2))
    g.scatter({"a": 6, "R": 2, "H": 2, "N": 1}, [(10, 1, 38, 24)], 201)
    save("f20_generators", g, {"title": "GENERATORS", "intro": "GENERATOR HALL\nONE SPARK.", "theme": theme("amber")})


def f21_lockdown():
    g = Grid(40, 30)
    g.room(3, 3, 36, 26)
    for (x0, y0, x1, y1) in ((9, 8, 12, 9), (27, 8, 30, 9), (9, 20, 12, 21), (27, 20, 30, 21), (18, 13, 21, 16)):   # cell blocks
        g.wall(x0, y0, x1, y1)
    g.room(18, 1, 21, 1); g.room(18, 28, 21, 28); g.room(1, 13, 1, 16); g.room(38, 13, 38, 16)
    g.put("D", (19, 2), (20, 27), (2, 14), (37, 15))
    g.put("w", (20, 1), (19, 28), (1, 15), (38, 14))
    g.put("o", (6, 6), (6, 23), (33, 6), (33, 23), (15, 6), (24, 23), (15, 23), (24, 6))
    g.put("P", (3, 24)); g.put("X", (36, 5)); g.put("B", (20, 8))
    g.put("H", (12, 13), (27, 13), (20, 19)); g.put("N", (8, 4), (31, 4))
    g.put("Y", (6, 21)); g.put("K", (9, 25)); g.put("F", (12, 23), (5, 18)); g.put("g", (14, 11), (25, 18), (30, 24)); g.put("V", (4, 21))
    save("f21_lockdown", g, {"title": "LOCKDOWN", "intro": "LOCKDOWN\nTHE WARDEN. THREE ROUNDS THROUGH THE GLASS.",
                             "boss": "warden", "theme": theme("prison")})


def f22_cryolab():
    g = Grid(38, 24)
    g.room(1, 9, 36, 14)
    for x0 in (1, 10, 19, 28):
        g.room(x0, 1, x0 + 7, 7); g.room(x0, 16, x0 + 7, 22)
        for x in range(x0 + 1, x0 + 7):
            if x not in (x0 + 3, x0 + 4):
                g.put("G", (x, 8), (x, 15))
        g.put(".", (x0 + 3, 8), (x0 + 4, 8), (x0 + 3, 15), (x0 + 4, 15))
    g.fill("i", 2, 10, 35, 13)
    g.put("P", (1, 12)); g.put("X", (36, 11))
    g.put("o", (9, 9), (9, 14), (18, 9), (18, 14), (27, 9), (27, 14), (4, 4), (32, 19))
    g.put("F", (3, 10), (14, 3), (23, 20), (32, 4)); g.put("p", (3, 13)); g.put("M", (22, 3)); g.put("n", (13, 20))
    g.scatter({"a": 6, "U": 2, "q": 3, "Z": 3}, [(8, 1, 36, 22)], 221, floor=".i")
    save("f22_cryolab", g, {"title": "CRYO LAB", "intro": "CRYO LAB\nFREEZE BOMBS. USE ALL OF THEM.", "theme": theme("cryo")})


def f23_mirrors():
    g = Grid(40, 26)
    g.room(1, 1, 38, 24)
    for (x, y) in [(x, y) for x in range(6, 35, 4) for y in range(4, 23, 6)]:     # a hall of glass, mirrored left to right
        g.put("G", (x, y), (x, y + 1))
    for x in (12, 27):
        for y in range(2, 24):
            if g.c[y][x] == "." and y not in (7, 8, 12, 13, 17, 18):
                g.put("G", (x, y))
    g.put("P", (1, 13)); g.put("X", (38, 12))
    g.put("o", (4, 3), (4, 22), (35, 3), (35, 22), (19, 8), (20, 17), (9, 13), (30, 12))
    g.put("V", (3, 10)); g.put("Y", (3, 16)); g.put("T", (20, 13)); g.put("F", (19, 2)); g.put("b", (2, 4), (2, 21))
    g.scatter({"N": 2, "S": 3, "a": 6, "H": 1}, [(9, 1, 38, 24)], 231)
    save("f23_mirrors", g, {"title": "HALL OF GLASS", "intro": "HALL OF GLASS\nEVERYONE CAN SEE EVERYONE.", "theme": theme("silver")})


def f24_strongrooms():
    g = Grid(40, 26)
    g.room(1, 11, 38, 14)                                        # the long corridor
    for i, x0 in enumerate((1, 9, 17, 25, 33)):
        x1 = x0 + 5
        g.room(x0, 1, x1, 9); g.room(x0, 16, x1, 24)
        g.put("D", (x0 + 2, 10), (x0 + 3, 15))
        g.put("o", (x0 + 4, 3), (x0 + 1, 22))
    g.put("P", (1, 12)); g.put("X", (38, 13))
    g.put("r", (3, 13), (20, 12)); g.put("p", (5, 11)); g.put("T", (12, 4)); g.put("K", (28, 21)); g.put("V", (20, 5)); g.put("g", (11, 20), (27, 5), (36, 20))
    g.put("c", (3, 6), (4, 6), (19, 19), (20, 19), (35, 6), (36, 6))
    g.scatter({"a": 6, "S": 3, "H": 2, "R": 2}, [(9, 1, 38, 24)], 241)
    save("f24_strongrooms", g, {"title": "STRONGROOMS", "intro": "STRONGROOMS\nA DOOR IS A SUGGESTION. SO IS A WALL.", "theme": theme("bank")})


def f25_skygarden():
    g = Grid(42, 28)
    g.room(1, 1, 40, 26)
    g.fill("~", 8, 6, 13, 10); g.fill("~", 27, 17, 33, 21); g.fill("~", 18, 12, 23, 15)
    for (x, y) in ((6, 16), (6, 17), (16, 4), (17, 4), (25, 8), (25, 9), (34, 5), (35, 5), (14, 21), (15, 21), (36, 12), (36, 13)):
        g.put("c", (x, y))
    g.pillars(1, 1, 40, 26, step=7, ox=4, oy=4)
    g.put("P", (1, 14)); g.put("X", (40, 13))
    g.put("Y", (3, 11)); g.put("K", (3, 17)); g.put("F", (20, 3)); g.put("g", (12, 14), (30, 9), (22, 23))
    g.scatter({"N": 3, "R": 3, "a": 5, "q": 3}, [(9, 1, 40, 26)], 251, floor=".~")
    save("f25_skygarden", g, {"title": "SKY GARDEN", "intro": "SKY GARDEN\nLONG SIGHTLINES. THEIRS TOO.", "open_sky": True, "theme": theme("sky")})


def f26_morgue():
    g = Grid(38, 24)
    g.room(1, 1, 36, 22)
    for x in range(5, 34, 4):                                    # slabs
        for y in (4, 5, 11, 12, 18, 19):
            g.put("c", (x, y))
    g.put("P", (1, 12)); g.put("X", (36, 11))
    g.put("o", (3, 3), (3, 20), (11, 8), (19, 15), (27, 8), (34, 3), (34, 20), (19, 2))
    g.put("n", (2, 8), (2, 16)); g.put("T", (3, 12)); g.put("F", (18, 8), (26, 15)); g.put("p", (10, 2))
    g.scatter({"Z": 12, "a": 3, "H": 1}, [(1, 1, 36, 22)], 261)
    save("f26_morgue", g, {"title": "MORGUE", "intro": "MORGUE\nNOT ALL OF THEM STAYED DEAD.", "theme": theme("morgue")})


def f27_furnace():
    g = Grid(40, 26)
    g.room(1, 1, 38, 24)
    for (x0, y0) in ((8, 5), (8, 17), (18, 11), (28, 5), (28, 17)):          # furnaces
        g.wall(x0, y0, x0 + 3, y0 + 3)
    g.put("g", (6, 7), (13, 6), (6, 19), (13, 18), (16, 13), (23, 12), (26, 7), (33, 6), (26, 19), (33, 18), (20, 3), (20, 22))
    g.put("o", (4, 12), (14, 12), (25, 13), (35, 12), (20, 8), (20, 17))
    g.put("P", (1, 13)); g.put("X", (38, 12))
    g.put("K", (3, 10)); g.put("F", (3, 16)); g.put("V", (2, 3)); g.put("r", (2, 22))
    g.scatter({"S": 3, "R": 3, "U": 3, "a": 4, "H": 2}, [(10, 1, 38, 24)], 271)
    save("f27_furnace", g, {"title": "FURNACE", "intro": "FURNACE ROOM\nTWELVE BARRELS. COUNT THEM.", "theme": theme("furnace")})


def f28_waterworks():
    g = Grid(42, 26)
    g.room(1, 1, 40, 24)
    g.fill("~", 2, 2, 39, 23)
    for y in (4, 12, 13, 21):                                    # dry walkways
        for x in range(2, 40):
            if g.c[y][x] == "~":
                g.c[y][x] = "."
    for x in (8, 20, 21, 33):
        for y in range(2, 24):
            if g.c[y][x] == "~":
                g.c[y][x] = "."
    g.put("o", (5, 8), (5, 17), (14, 8), (14, 17), (27, 8), (27, 17), (36, 8), (36, 17))
    g.put("P", (1, 12)); g.put("X", (40, 13))
    g.put("M", (3, 12)); g.put("n", (3, 13)); g.put("F", (20, 12), (21, 13)); g.put("T", (8, 4)); g.put("g", (14, 12), (27, 13), (33, 21))
    g.scatter({"q": 6, "a": 6, "R": 2, "Z": 3}, [(9, 1, 40, 24)], 281, floor=".~")
    save("f28_waterworks", g, {"title": "WATERWORKS", "intro": "WATERWORKS\nSTAY ON THE WALKWAYS. LET THEM RUN.", "theme": theme("harbour")})


def f29_penthouse():
    g = Grid(46, 30)
    g.room(1, 1, 14, 12); g.room(1, 14, 14, 28)
    g.room(16, 1, 44, 28)
    g.put("D", (15, 6), (15, 21), (7, 13))
    g.pillars(16, 1, 44, 28, step=6, ox=3, oy=3)
    g.pillars(1, 1, 14, 12, step=5, ox=4, oy=4); g.pillars(1, 14, 14, 28, step=5, ox=4, oy=4)
    for x in range(22, 40, 4):
        g.put("c", (x, 14), (x + 1, 14), (x, 15), (x + 1, 15))
    g.fill("~", 28, 4, 33, 7); g.fill("i", 28, 22, 33, 25)
    for y in range(9, 21):
        if g.c[y][40] == ".":
            g.put("G", (40, y))
    g.put("f", (24, 8), (36, 20))
    g.put("g", (20, 5), (20, 24), (37, 5), (37, 24), (26, 17))
    g.put("w", (44, 2), (44, 27), (30, 1), (30, 28), (16, 14))
    g.put("P", (1, 6)); g.put("X", (44, 14))
    g.put("K", (3, 3)); g.put("T", (5, 3)); g.put("Y", (3, 10)); g.put("F", (5, 10), (8, 20)); g.put("r", (3, 20)); g.put("n", (5, 24)); g.put("V", (11, 3))
    g.scatter({"a": 6, "R": 3, "S": 2, "U": 2, "N": 2, "H": 3, "q": 3, "Z": 3}, [(9, 1, 44, 28)], 291, floor=".~i")
    save("f29_penthouse", g, {"title": "PENTHOUSE", "intro": "PENTHOUSE\nEVERYTHING THEY HAVE LEFT.", "theme": theme("gold"),
                              "waves": [{"after_kills": 9, "count": 5, "armed": 4}, {"after_kills": 18, "count": 6, "armed": 5}]})


NEW_FLOORS = [f6_cafeteria, f7_garage, f8_archive, f9_pool, f10_vault, f11_sewers, f12_kitchen, f13_coldstore,
              f14_glassworks, f15_restrooms, f16_armoury, f17_greenhouse, f18_beanworks, f19_tradingfloor,
              f20_generators, f21_lockdown, f22_cryolab, f23_mirrors, f24_strongrooms, f25_skygarden, f26_morgue,
              f27_furnace, f28_waterworks, f29_penthouse]


if __name__ == "__main__":
    f1_lobby()
    f2_offices()
    f3_servers()
    f4_labs()
    f5_executive()
    roof()
    for make in NEW_FLOORS:
        make()
