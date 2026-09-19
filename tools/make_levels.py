#!/usr/bin/env python3
"""Generates the HQ floor grids into levels/. Re-run after editing: python3 tools/make_levels.py
Hand edits to the generated .txt files are overwritten, so change the floor here instead."""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "levels")


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
            assert self.c[y][x] in ".#", f"cell {x},{y} already holds {self.c[y][x]!r}"
            self.c[y][x] = ch

    def pillars(self, x0, y0, x1, y1, step=4, ox=2, oy=2):
        """Full-height cover on a lattice. Skips anything not plain floor and anything beside a door,
        pane or entity, so doorways and spawn cells stay clear."""
        for y in range(y0 + oy, y1, step):
            for x in range(x0 + ox, x1, step):
                if self.c[y][x] != ".":
                    continue
                around = [self.c[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx or dy)]
                if not any(ch in "DGXPauBwt" for ch in around):
                    self.c[y][x] = "o"

    def cells(self, chars):
        return [(x, y) for y in range(self.h) for x in range(self.w) if self.c[y][x] in chars]

    def check_spacing(self, name, between=4.0, from_player=6.0):
        import math
        enemies = self.cells("auB")
        player = self.cells("P")[0]
        for i, a in enumerate(enemies):
            assert math.dist(a, player) >= from_player, f"{name}: enemy {a} is {math.dist(a, player):.1f} cells from the player"
            for b in enemies[i + 1:]:
                assert math.dist(a, b) >= between, f"{name}: enemies {a} and {b} are {math.dist(a, b):.1f} cells apart"

    def text(self):
        return "\n".join("".join(r) for r in self.c) + "\n"


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
    g.put("a", (12, 3), (16, 10), (20, 4), (24, 9), (4, 9), (8, 16), (18, 16))
    g.put("u", (14, 16))
    g.put("b", (5, 2))
    g.put("k", (5, 11))
    g.put("l", (9, 7))
    g.put("m", (20, 15))
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
    g.put("a", (14, 11), (24, 12), (32, 11), (5, 4), (17, 5), (29, 4), (5, 18), (17, 18), (29, 17))
    g.put("u", (9, 21))
    g.put("w", (34, 11), (34, 12), (13, 1), (22, 22), (1, 1), (1, 22))
    g.put("o", (8, 11), (11, 12), (19, 11), (21, 12), (27, 11), (30, 12))
    g.put("p", (4, 11), (30, 20))
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
    g.put("a", (9, 6), (17, 3), (24, 4), (31, 3), (36, 10), (28, 11), (4, 13), (5, 23), (26, 17), (33, 23))
    g.put("u", (9, 15), (18, 23))
    g.put("w", (14, 17), (38, 17), (2, 26), (38, 1), (14, 26), (12, 10))
    g.put("p", (3, 6), (37, 21))
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
    g.put("a", (10, 6), (20, 6))
    g.put("p", (7, 15), (23, 15))
    g.put("b", (15, 22))
    g.put("k", (5, 5))
    g.put("m", (24, 24))
    g.put("l", (24, 5))
    g.pillars(4, 4, 25, 25, step=5, ox=3, oy=3)
    save("roof", g, {"intro": "ROOF\nTHE DIRECTOR. THREE BULLETS.", "open_sky": True})


if __name__ == "__main__":
    f1_lobby()
    f2_offices()
    f3_servers()
    f4_labs()
    f5_executive()
    roof()
